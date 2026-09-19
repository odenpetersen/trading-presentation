#pragma once
// "Does this sender exist" -- ground truth is one file per known sender on
// disk (engine/users/<id>, materialized from roster.txt at startup); a very
// small in-memory LRU sits in front of it. A cached sender is a fast hit
// with no syscall; an evicted or never-seen one pays a real stat().
//
// Each validation worker owns its own UserStore -- no locking needed, and
// it's a direct payoff of the sender->worker hashing engine.hpp already
// does for ordering: one sender's traffic always lands on the same worker,
// so that worker's tiny cache stays warm for it specifically. Run with
// fewer workers than active senders (so a worker sees more than
// `capacity` distinct senders) to see it actually evict.
#include <x86intrin.h>

#include <algorithm>
#include <deque>
#include <filesystem>
#include <string>

class UserStore {
public:
    UserStore(std::filesystem::path dir, size_t capacity) : dir_(std::move(dir)), capacity_(capacity) {}

    struct Result {
        bool exists;
        bool cache_hit;
        uint64_t cycles;  // cost of this check, in CPU cycles (RDTSC -- see order_book.hpp for why)
    };

    Result check(uint32_t sender) {
        uint64_t t0 = __rdtsc();
        auto it = std::find(cache_.begin(), cache_.end(), sender);
        if (it != cache_.end()) {
            cache_.erase(it);
            cache_.push_front(sender);  // most-recently-used
            return {true, true, __rdtsc() - t0};
        }
        bool found = std::filesystem::exists(dir_ / std::to_string(sender));  // ground truth: a real disk lookup
        if (found) {
            cache_.push_front(sender);
            if (cache_.size() > capacity_) cache_.pop_back();  // evict least-recently-used
        }
        return {found, false, __rdtsc() - t0};
    }

private:
    std::filesystem::path dir_;
    size_t capacity_;
    std::deque<uint32_t> cache_;
};
