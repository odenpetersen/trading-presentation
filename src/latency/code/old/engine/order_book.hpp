#pragma once
// Price/time-priority limit order book, storing levels in a flat array
// indexed by price tick rather than a map. That's the whole cache-warming
// demo: NUM_TICKS * sizeof(Level) is sized to comfortably exceed this
// machine's L2 (checked with `lscpu` -- see README), so a participant that
// keeps touching a handful of ticks near the touch stays cache-warm, while
// one that roams across many ticks (the dumb trader, wide quoters) evicts
// everyone else. We just time the real array access (in CPU cycles); no
// simulated latency, no LRU bookkeeping -- the hardware does the work.
//
// Which ticks currently hold resting orders is tracked separately, in two
// small sorted sets (bid_ticks_/ask_ticks_). That's bookkeeping only, not
// part of the demo: without it, matching an order priced far from the
// touch would have to step through every empty tick in between one at a
// time to find the next real level -- both slow, and, worse for the demo,
// a sequential access pattern that hardware prefetch makes artificially
// fast, defeating the whole point.
#include <x86intrin.h>

#include <algorithm>
#include <cmath>
#include <deque>
#include <functional>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "protocol.hpp"

constexpr double TICK_SIZE = 0.01;
constexpr int NUM_TICKS = 40000;  // covers price range [0.00, 400.00)

struct RestingOrder {
    uint64_t id;
    uint32_t sender;
    uint32_t qty;
};

// Padded to span several cache lines: touching one Level means genuinely
// pulling all of them in, which both amplifies the cold-vs-warm gap above
// scheduler noise, and -- by making each Level bigger -- means fewer
// distinct ticks need to be touched before the working set exceeds cache
// capacity (see README for tuning this against your machine's L2).
constexpr int LEVEL_LINES = 16;
struct alignas(64) Level {
    std::deque<RestingOrder> orders;
    unsigned char data[64 * LEVEL_LINES] = {};
};

using SendPrivate = std::function<void(uint32_t sender, const std::string& line)>;
using Broadcast = std::function<void(const std::string& line)>;

class OrderBook {
public:
    explicit OrderBook(bool smp) : smp_(smp), levels_(NUM_TICKS) {}

    // order_id is unused (0) for CANCEL.
    void apply(const Msg& m, uint64_t order_id, const SendPrivate& priv, const Broadcast& pub) {
        if (m.type == Msg::CANCEL) return do_cancel(m, priv, pub);
        do_order(m, order_id, /*rest_if_gfd=*/m.type == Msg::GFD, priv, pub);
    }

private:
    bool smp_;
    std::vector<Level> levels_;
    std::set<int> bid_ticks_, ask_ticks_;  // occupied ticks per side, for O(log n) "next real level"
    std::unordered_map<uint64_t, std::pair<bool, int>> loc_;  // order id -> (is_bid, tick)
    uint64_t seq_ = 0;

    static int to_tick(double price) {
        int t = (int)std::lround(price / TICK_SIZE);
        return std::clamp(t, 0, NUM_TICKS - 1);
    }
    static double to_price(int tick) { return tick * TICK_SIZE; }
    uint64_t next_seq() { return ++seq_; }

    // The bit that matters for the cache demo: touch every line of the
    // level and time it, in CPU cycles via RDTSC rather than
    // std::chrono::steady_clock. A clock_gettime call can itself cost
    // hundreds of nanoseconds (more, off the vDSO fast path -- e.g. inside
    // a VM/container), which would swamp the very same-order-of-magnitude
    // effect we're trying to measure. RDTSC is a single instruction with
    // no syscall, so its own overhead stays far below a cache miss.
    uint64_t touch(int tick) {
        unsigned char* d = levels_[tick].data;
        uint64_t t0 = __rdtsc();
        for (int i = 0; i < 64 * LEVEL_LINES; i += 64) d[i]++;
        uint64_t t1 = __rdtsc();
        return t1 - t0;
    }

    bool crosses(bool aggressor_buys, int tick, double limit) const {
        return aggressor_buys ? to_price(tick) <= limit : to_price(tick) >= limit;
    }

    void do_order(const Msg& m, uint64_t order_id, bool rest, const SendPrivate& priv, const Broadcast& pub) {
        uint32_t remaining = m.qty;
        std::set<int>& opp = m.buy ? ask_ticks_ : bid_ticks_;
        while (remaining > 0 && !opp.empty()) {
            int tick = m.buy ? *opp.begin() : *opp.rbegin();
            if (!crosses(m.buy, tick, m.price)) break;

            uint64_t access_cyc = touch(tick);
            Level& lvl = levels_[tick];
            for (auto it = lvl.orders.begin(); it != lvl.orders.end() && remaining > 0;) {
                bool wash = it->sender == m.sender;
                if (wash && smp_) {
                    ++it;  // self-match prevention: skip our own resting order, keep it resting
                    continue;
                }
                uint32_t traded = std::min(remaining, it->qty);
                double price = to_price(tick);
                pub(fmt_trade(next_seq(), order_id, m.sender, it->id, it->sender, price, traded, wash, access_cyc));
                priv(m.sender, fmt_fill(order_id, price, traded, /*aggressor=*/true, wash, access_cyc));
                priv(it->sender, fmt_fill(it->id, price, traded, /*aggressor=*/false, wash, access_cyc));
                it->qty -= traded;
                remaining -= traded;
                if (it->qty == 0) {
                    loc_.erase(it->id);
                    it = lvl.orders.erase(it);
                } else {
                    ++it;
                }
            }
            if (lvl.orders.empty())
                opp.erase(tick);
            else
                break;  // rest is SMP-blocked (all ours): stop rather than reach past our own quote
        }
        if (remaining > 0 && rest) {
            int tick = to_tick(m.price);
            uint64_t access_cyc = touch(tick);
            levels_[tick].orders.push_back({order_id, m.sender, remaining});
            loc_[order_id] = {m.buy, tick};
            (m.buy ? bid_ticks_ : ask_ticks_).insert(tick);
            priv(m.sender, fmt_ack(order_id, "RESTING"));
            pub(fmt_add(next_seq(), order_id, m.sender, m.buy, to_price(tick), remaining, access_cyc));
        } else if (remaining > 0 && !rest) {
            priv(m.sender, fmt_ack(order_id, "KILLED"));
        }
    }

    void do_cancel(const Msg& m, const SendPrivate& priv, const Broadcast& pub) {
        auto it = loc_.find(m.ref_id);
        if (it == loc_.end()) return priv(m.sender, fmt_ack(m.ref_id, "REJECTED"));
        auto [is_bid, tick] = it->second;
        auto& dq = levels_[tick].orders;
        for (auto oit = dq.begin(); oit != dq.end(); ++oit) {
            if (oit->id != m.ref_id) continue;
            if (oit->sender != m.sender) return priv(m.sender, fmt_ack(m.ref_id, "REJECTED"));
            dq.erase(oit);
            loc_.erase(it);
            if (dq.empty()) (is_bid ? bid_ticks_ : ask_ticks_).erase(tick);
            priv(m.sender, fmt_ack(m.ref_id, "CANCELLED"));
            pub(fmt_cancel(next_seq(), m.ref_id));
            return;
        }
        priv(m.sender, fmt_ack(m.ref_id, "REJECTED"));
    }
};
