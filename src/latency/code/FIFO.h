#pragma once

#include <concepts>
#include <cstdint>
#include <span>

using OrderID = uint32_t;

constexpr OrderID NONE = UINT32_MAX;

struct Order {
    OrderID prev = NONE;
    OrderID next = NONE;
};

class FIFO {
    OrderID head_ = NONE;
    OrderID tail_ = NONE;

public:
    bool empty() const;
    OrderID front() const;

    template <std::derived_from<Order> T>
    void push(OrderID id, std::span<T> orders) {
        auto& order = orders[id];

        order.prev = tail_;
        order.next = NONE;

        if (tail_ != NONE)
            orders[tail_].next = id;
        else
            head_ = id;

        tail_ = id;
    }

    template <std::derived_from<Order> T>
    void erase(OrderID id, std::span<T> orders) {
        auto& order = orders[id];

        if (order.prev != NONE)
            orders[order.prev].next = order.next;
        else
            head_ = order.next;

        if (order.next != NONE)
            orders[order.next].prev = order.prev;
        else
            tail_ = order.prev;

        order.prev = NONE;
        order.next = NONE;
    }
};
