#include "OrderBook.h"

#include <bit>
#include <cassert>

OrderBook::Node::Node() {
    child.fill(NONE);
}

OrderBook::OrderBook(size_t capacity)
    : orders_(capacity)
{
    free_.reserve(capacity);

    for (OrderID i = 0; i < capacity; ++i)
        free_.push_back(capacity - 1 - i);
}

unsigned OrderBook::side_index(Side side) {
    return static_cast<unsigned>(side);
}

unsigned OrderBook::slot(Price price, int shift) {
    return (price >> shift) & 63;
}

FIFO& OrderBook::fifo(Price price, Side side) {
    uint32_t node = 0;

    for (int shift : SHIFTS) {
        auto s = slot(price, shift);

        if (nodes_[node].child[s] == NONE) {
            nodes_[node].child[s] = nodes_.size();
            nodes_.emplace_back();
        }

        node = nodes_[node].child[s];
    }

    if (nodes_[node].child[0] == NONE) {
        nodes_[node].child[0] = leaves_.size();
        leaves_.emplace_back();
    }

    auto& leaf = leaves_[nodes_[node].child[0]];
    auto s = price & 63;

    return side == Side::Buy ? leaf.buy[s] : leaf.sell[s];
}

void OrderBook::activate(Price price, Side side) {
    auto si = side_index(side);
    uint32_t node = 0;

    for (int shift : SHIFTS) {
        auto s = slot(price, shift);
        nodes_[node].used[si] |= 1ULL << s;
        node = nodes_[node].child[s];
    }

    auto& leaf = leaves_[nodes_[node].child[0]];
    leaf.used[si] |= 1ULL << (price & 63);
}

void OrderBook::deactivate(Price price, Side side) {
    auto si = side_index(side);

    uint32_t path[5];
    unsigned slots[5];

    uint32_t node = 0;

    for (int i = 0; i < 5; ++i) {
        path[i] = node;
        slots[i] = slot(price, SHIFTS[i]);
        node = nodes_[node].child[slots[i]];
    }

    auto& leaf = leaves_[nodes_[node].child[0]];
    leaf.used[si] &= ~(1ULL << (price & 63));

    for (int i = 4; i >= 0; --i) {
        auto child = nodes_[path[i]].child[slots[i]];

        if (nodes_[child].used[si])
            break;

        nodes_[path[i]].used[si] &= ~(1ULL << slots[i]);
    }
}

OrderBook::MatchResult OrderBook::add(Side side, Price price, Qty qty, ParticipantID participant, ClientOrderID client_order_id, bool self_match_prevention) {
    MatchResult result;
    Side opp = side == Side::Buy ? Side::Sell : Side::Buy;
    Qty remaining = qty;

    while (remaining > 0) {
        auto best = side == Side::Buy ? best_ask() : best_bid();
        if (!best)
            break;

        bool marketable = side == Side::Buy ? (price >= *best) : (price <= *best);
        if (!marketable)
            break;

        auto& q = fifo(*best, opp);
        assert(!q.empty());

        OrderID maker_id = q.front();
        auto& maker = orders_[maker_id];

        if (self_match_prevention && maker.participant == participant)
            break;

        Qty traded = std::min(remaining, maker.qty);
        result.fills.push_back({maker_id, maker.participant, maker.client_order_id, *best, traded});

        maker.qty -= traded;
        remaining -= traded;

        if (maker.qty == 0) {
            q.erase(maker_id, std::span<OrderData>(orders_));

            if (q.empty())
                deactivate(*best, opp);

            free_.push_back(maker_id);
        }
    }

    result.filled_qty = qty - remaining;

    if (remaining > 0) {
        assert(!free_.empty());

        auto id = free_.back();
        free_.pop_back();

        orders_[id] = {
            .price = price,
            .qty = remaining,
            .side = side,
            .participant = participant,
            .client_order_id = client_order_id,
        };

        auto& q = fifo(price, side);
        auto was_empty = q.empty();

        q.push(id, std::span<OrderData>(orders_));

        if (was_empty)
            activate(price, side);

        result.id = id;
    }

    return result;
}

OrderBook::CancelResult OrderBook::cancel(OrderID id, ParticipantID participant) {
    auto& order = orders_[id];

    if (order.participant != participant)
        return CancelResult{.ok = false};

    CancelResult result{.ok = true, .side = order.side, .price = order.price, .qty = order.qty};

    auto& q = fifo(order.price, order.side);
    q.erase(id, std::span<OrderData>(orders_));

    if (q.empty())
        deactivate(order.price, order.side);

    free_.push_back(id);

    return result;
}

std::optional<Price> OrderBook::best_bid() const {
    return best(Side::Buy, true);
}

std::optional<Price> OrderBook::best_ask() const {
    return best(Side::Sell, false);
}

std::optional<Price> OrderBook::best(Side side, bool max) const {
    auto si = side_index(side);

    if (!nodes_[0].used[si])
        return std::nullopt;

    uint32_t node = 0;
    Price price = 0;

    for (int shift : SHIFTS) {
        auto bits = nodes_[node].used[si];

        auto s = max
            ? 63 - std::countl_zero(bits)
            : std::countr_zero(bits);

        price |= Price(s) << shift;
        node = nodes_[node].child[s];
    }

    auto& leaf = leaves_[nodes_[node].child[0]];
    auto bits = leaf.used[si];

    auto s = max
        ? 63 - std::countl_zero(bits)
        : std::countr_zero(bits);

    return price | s;
}
