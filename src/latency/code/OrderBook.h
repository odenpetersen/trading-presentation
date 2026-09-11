#pragma once

#include "FIFO.h"

#include <array>
#include <cstdint>
#include <optional>
#include <vector>

using Price = uint32_t;
using Qty   = uint32_t;

enum class Side {
    Buy,
    Sell
};

class OrderBook {
    static constexpr unsigned N = 64;
    static constexpr int SHIFTS[] = {30, 24, 18, 12, 6};

    struct OrderData : Order {
        Price price;
        Qty qty;
        Side side;
    };

    struct Node {
        std::array<uint64_t, 2> used{};
        std::array<uint32_t, N> child;

        Node();
    };

    struct Leaf {
        std::array<uint64_t, 2> used{};
        std::array<FIFO, N> buy;
        std::array<FIFO, N> sell;
    };

    std::vector<OrderData> orders_;
    std::vector<OrderID> free_;

    std::vector<Node> nodes_{1};
    std::vector<Leaf> leaves_;

    static unsigned side_index(Side);
    static unsigned slot(Price, int);

    FIFO& fifo(Price, Side);

    void activate(Price, Side);
    void deactivate(Price, Side);

    std::optional<Price> best(Side, bool max) const;

public:
    struct CancelResult {
        Side side;
        Price price;
        Qty qty;
    };

    explicit OrderBook(size_t capacity);

    OrderID add(Side, Price, Qty);
    CancelResult cancel(OrderID);

    std::optional<Price> best_bid() const;
    std::optional<Price> best_ask() const;
};
