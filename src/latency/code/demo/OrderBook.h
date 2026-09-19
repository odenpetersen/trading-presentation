#pragma once

#include "FIFO.h"

#include <array>
#include <cstdint>
#include <optional>
#include <vector>

using Price = uint32_t;
using Qty   = uint32_t;

enum class Side : uint8_t {
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
        ParticipantID participant;
        ClientOrderID client_order_id;
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
        bool ok = false;
        Side side{};
        Price price = 0;
        Qty qty = 0;
    };

    struct FillEvent {
        OrderID maker_id;
        ParticipantID maker_participant;
        ClientOrderID maker_client_order_id;
        Price price;
        Qty qty;
    };

    struct MatchResult {
        OrderID id = NONE;   // resting order id for any unfilled remainder, else NONE
        Qty filled_qty = 0;
        std::vector<FillEvent> fills;
    };

    explicit OrderBook(size_t capacity);

    // self_match_prevention: if the incoming order would cross a resting
    // order from the same participant, matching stops there (any qty
    // already filled against other participants stands) and whatever
    // remains is rested rather than allowed to wash-trade.
    MatchResult add(Side, Price, Qty, ParticipantID, ClientOrderID, bool self_match_prevention);
    CancelResult cancel(OrderID, ParticipantID);

    std::optional<Price> best_bid() const;
    std::optional<Price> best_ask() const;
};
