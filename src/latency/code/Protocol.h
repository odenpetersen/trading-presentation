#pragma once

#include <cstdint>

#include "OrderBook.h"

// Fixed-size, tagged messages sent raw (memcpy) over a single TCP connection
// that carries both the order-entry and market-data feeds.
enum class MsgType : uint8_t {
    NewOrder,     // client -> engine
    Cancel,       // client -> engine
    Ack,          // engine -> client
    Fill,         // engine -> client
    LevelUpdate,  // engine -> client (market data)
    Trade,        // engine -> client (market data)
};

struct NewOrderMsg {
    Side side;
    Price price;
    Qty qty;
};

struct CancelMsg {
    OrderID id;
};

struct AckMsg {
    OrderID id;
};

struct FillMsg {
    OrderID id;
    Price price;
    Qty qty;
};

struct LevelUpdateMsg {
    Side side;
    Price price;
    Qty qty;   // amount added to or removed from the level
    bool added;
};

struct TradeMsg {
    Side side;  // aggressor side
    Price price;
    Qty qty;
};

struct Msg {
    MsgType type;
    union {
        NewOrderMsg new_order;
        CancelMsg cancel;
        AckMsg ack;
        FillMsg fill;
        LevelUpdateMsg level_update;
        TradeMsg trade;
    };
};

inline Msg make_new_order(Side side, Price price, Qty qty) {
    Msg m{};
    m.type = MsgType::NewOrder;
    m.new_order = {side, price, qty};
    return m;
}

inline Msg make_cancel(OrderID id) {
    Msg m{};
    m.type = MsgType::Cancel;
    m.cancel = {id};
    return m;
}

inline Msg make_ack(OrderID id) {
    Msg m{};
    m.type = MsgType::Ack;
    m.ack = {id};
    return m;
}

inline Msg make_fill(OrderID id, Price price, Qty qty) {
    Msg m{};
    m.type = MsgType::Fill;
    m.fill = {id, price, qty};
    return m;
}

inline Msg make_level_update(Side side, Price price, Qty qty, bool added) {
    Msg m{};
    m.type = MsgType::LevelUpdate;
    m.level_update = {side, price, qty, added};
    return m;
}

inline Msg make_trade(Side side, Price price, Qty qty) {
    Msg m{};
    m.type = MsgType::Trade;
    m.trade = {side, price, qty};
    return m;
}
