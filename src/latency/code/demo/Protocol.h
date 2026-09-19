#pragma once

#include <chrono>
#include <cstdint>

#include "OrderBook.h"

// Fixed-size, tagged, packed messages sent raw (memcpy) over TCP. Packed
// explicitly (not just "happens to match") because non-C++ components
// (the Python dashboard/Binance adapter) pack/unpack these same bytes.
#pragma pack(push, 1)

enum class MsgType : uint8_t {
    NewOrder,           // strategy -> gateway -> ME
    Cancel,             // strategy -> gateway -> ME
    Ack,                // ME -> gateway -> strategy
    Fill,               // ME -> gateway -> strategy
    Reject,             // ME -> gateway -> strategy, or gateway -> strategy directly
    LevelUpdate,        // ME -> (strategies + dashboard) directly
    Trade,              // ME -> (strategies + dashboard) directly
    RefPrice,           // ME -> (strategies + dashboard) directly (from Binance adapter)
    AuthCheckRequest,   // gateway -> ME
    AuthCheckResponse,  // ME -> gateway
    SetConfig,          // dashboard -> ME | gateway | strategy
    TradeReport,        // ME -> (strategies + dashboard) directly - per-fill participant attribution
    RaceResult,         // strategy -> ME feed-in -> (strategies + dashboard) - multi-shoot gateway race outcome
};

enum class RejectReason : uint8_t {
    NotAuthorised,
    Duplicate,
    WrongOwner,
    Unknown,
};

// Not all params apply to every recipient; the receiving process ignores
// params it doesn't own.
enum class ConfigParam : uint8_t {
    // ME + strategy. value: 0=washing (ME allows self-match), 1=on (ME
    // rejects/stops before crossing own resting order), 2=cancel-first (ME
    // allows same as washing, but strategies proactively cancel their own
    // resting order before crossing it, so no wash trade actually happens)
    SelfMatchPrevention,
    // strategy. value: 0=naive 50/50, 1=dynamic, 2=multi-shoot. target_participant
    // selects which of the strategy's own participants (taker/maker) this applies to
    GatewaySelectionMode,
    // ME. value: 0/1, applies to target_participant below
    ParticipantAuthorised,
    // gateway. value: cache TTL in milliseconds. Demo default is short
    // (~1s) so a live audience sees the cache-warm/re-poll effect quickly;
    // dial it up/down at runtime rather than redeploying.
    AuthCacheTtlMs,
    // strategy. value: maker quote cancel/replace interval in milliseconds.
    // Demo default is short (sub-second) so re-quoting is visibly live.
    QuoteRefreshMs,
};

struct NewOrderMsg {
    ClientOrderID client_order_id;
    ParticipantID participant_id;
    Side side;
    Price price;
    Qty qty;
};

struct CancelMsg {
    ClientOrderID client_order_id;
    ParticipantID participant_id;
    OrderID id;
};

struct AckMsg {
    OrderID id;
    ClientOrderID client_order_id;
    uint64_t me_time;
    uint64_t gateway_time;
    uint64_t publish_time;
};

struct FillMsg {
    OrderID id;
    ClientOrderID client_order_id;
    Price price;
    Qty qty;
    uint64_t me_time;
    uint64_t gateway_time;
    uint64_t publish_time;
};

struct RejectMsg {
    ClientOrderID client_order_id;
    RejectReason reason;
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

// Binance's tick size is much finer than this demo book's Price grid, so
// RefPrice carries its own fixed-point field (scaled by REF_PRICE_SCALE)
// rather than reusing Price - the two are not directly comparable.
constexpr int64_t REF_PRICE_SCALE = 100'000'000; // 1e8, matches Binance's 8dp

struct RefPriceMsg {
    char symbol[8]; // e.g. "BTCUSDT", NUL-padded
    int64_t price;  // fixed-point, price * REF_PRICE_SCALE
    uint64_t exch_time;
};

struct TradeReportMsg {
    ClientOrderID taker_client_order_id; // group key: same value for every match from one incoming order
    ParticipantID taker_participant;
    ParticipantID maker_participant;
    Side side; // aggressor side
    Price price;
    Qty qty;
    uint64_t me_time;      // stamped once, before matching started (same across the whole group)
    uint64_t publish_time; // stamped fresh per message, after the whole match completed
};

// only emitted for multi-shoot orders: the same order raced through both
// gateways, this reports which one's copy actually reached the ME first
struct RaceResultMsg {
    ParticipantID participant_id;
    uint8_t winner_gw; // 0=gateway A, 1=gateway B
};

struct AuthCheckRequestMsg {
    ParticipantID participant_id;
};

struct AuthCheckResponseMsg {
    ParticipantID participant_id;
    bool authorised;
    uint64_t checked_at;
};

struct SetConfigMsg {
    ConfigParam param;
    ParticipantID target_participant; // only used by ParticipantAuthorised
    int64_t value;
};

struct Msg {
    MsgType type;
    union {
        NewOrderMsg new_order;
        CancelMsg cancel;
        AckMsg ack;
        FillMsg fill;
        RejectMsg reject;
        LevelUpdateMsg level_update;
        TradeMsg trade;
        RefPriceMsg ref_price;
        AuthCheckRequestMsg auth_check_request;
        AuthCheckResponseMsg auth_check_response;
        SetConfigMsg set_config;
        TradeReportMsg trade_report;
        RaceResultMsg race_result;
    };
};

#pragma pack(pop)

inline uint64_t now_ns() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

inline Msg make_new_order(ClientOrderID coid, ParticipantID participant, Side side, Price price, Qty qty) {
    Msg m{};
    m.type = MsgType::NewOrder;
    m.new_order = {coid, participant, side, price, qty};
    return m;
}

inline Msg make_cancel(ClientOrderID coid, ParticipantID participant, OrderID id) {
    Msg m{};
    m.type = MsgType::Cancel;
    m.cancel = {coid, participant, id};
    return m;
}

inline Msg make_ack(OrderID id, ClientOrderID coid, uint64_t me_time, uint64_t gateway_time, uint64_t publish_time) {
    Msg m{};
    m.type = MsgType::Ack;
    m.ack = {id, coid, me_time, gateway_time, publish_time};
    return m;
}

inline Msg make_fill(OrderID id, ClientOrderID coid, Price price, Qty qty,
                      uint64_t me_time, uint64_t gateway_time, uint64_t publish_time) {
    Msg m{};
    m.type = MsgType::Fill;
    m.fill = {id, coid, price, qty, me_time, gateway_time, publish_time};
    return m;
}

inline Msg make_reject(ClientOrderID coid, RejectReason reason) {
    Msg m{};
    m.type = MsgType::Reject;
    m.reject = {coid, reason};
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

inline Msg make_ref_price(const char (&symbol)[8], int64_t price, uint64_t exch_time) {
    Msg m{};
    m.type = MsgType::RefPrice;
    for (int i = 0; i < 8; ++i)
        m.ref_price.symbol[i] = symbol[i];
    m.ref_price.price = price;
    m.ref_price.exch_time = exch_time;
    return m;
}

inline Msg make_trade_report(ClientOrderID taker_coid, ParticipantID taker, ParticipantID maker, Side side, Price price, Qty qty, uint64_t me_time, uint64_t publish_time) {
    Msg m{};
    m.type = MsgType::TradeReport;
    m.trade_report = {taker_coid, taker, maker, side, price, qty, me_time, publish_time};
    return m;
}

inline Msg make_race_result(ParticipantID participant, uint8_t winner_gw) {
    Msg m{};
    m.type = MsgType::RaceResult;
    m.race_result = {participant, winner_gw};
    return m;
}

inline Msg make_auth_check_request(ParticipantID participant) {
    Msg m{};
    m.type = MsgType::AuthCheckRequest;
    m.auth_check_request = {participant};
    return m;
}

inline Msg make_auth_check_response(ParticipantID participant, bool authorised, uint64_t checked_at) {
    Msg m{};
    m.type = MsgType::AuthCheckResponse;
    m.auth_check_response = {participant, authorised, checked_at};
    return m;
}

inline Msg make_set_config(ConfigParam param, ParticipantID target, int64_t value) {
    Msg m{};
    m.type = MsgType::SetConfig;
    m.set_config = {param, target, value};
    return m;
}
