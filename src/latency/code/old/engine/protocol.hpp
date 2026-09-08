#pragma once
// Wire protocol: one newline-terminated, space-separated line per message.
// Deliberately plain text (no framing/serialisation library) so it stays
// trivial to read on a slide and to reimplement in Python without deps.
#include <cstdint>
#include <optional>
#include <sstream>
#include <string>

struct Msg {
    enum Type { GFD, FAK, CANCEL } type;
    bool buy = false;
    uint32_t sender = 0;
    double price = 0;
    uint32_t qty = 0;
    uint64_t ref_id = 0;  // CANCEL: id of the order to cancel
};

// Client -> engine:
//   GFD <BUY|SELL> <sender> <price> <qty>
//   FAK <BUY|SELL> <sender> <price> <qty>
//   CANCEL <sender> <order_id>
inline std::optional<Msg> parse_line(const std::string& line) {
    std::istringstream ss(line);
    std::string type;
    ss >> type;
    Msg m;
    if (type == "GFD" || type == "FAK") {
        std::string side;
        ss >> side >> m.sender >> m.price >> m.qty;
        if (!ss) return std::nullopt;
        m.type = type == "GFD" ? Msg::GFD : Msg::FAK;
        m.buy = side == "BUY";
        return m;
    }
    if (type == "CANCEL") {
        ss >> m.sender >> m.ref_id;
        if (!ss) return std::nullopt;
        m.type = Msg::CANCEL;
        return m;
    }
    return std::nullopt;
}

// Engine -> the sending connection only:
inline std::string fmt_ack(uint64_t id, const char* status) {
    return "ACK " + std::to_string(id) + " " + status;
}
inline std::string fmt_fill(uint64_t id, double price, uint32_t qty, bool aggressor, bool wash, uint64_t access_cyc) {
    std::ostringstream os;
    os << "FILL " << id << " " << price << " " << qty << " " << (aggressor ? 1 : 0) << " " << (wash ? 1 : 0) << " "
       << access_cyc;
    return os.str();
}

// Engine -> every connection (the public feed):
inline std::string fmt_add(uint64_t seq, uint64_t id, uint32_t sender, bool buy, double price, uint32_t qty,
                            uint64_t access_cyc) {
    std::ostringstream os;
    os << "SEQ " << seq << " ADD " << id << " " << sender << " " << (buy ? "BUY" : "SELL") << " " << price << " "
       << qty << " " << access_cyc;
    return os.str();
}
inline std::string fmt_cancel(uint64_t seq, uint64_t id) {
    return "SEQ " + std::to_string(seq) + " CANCEL " + std::to_string(id);
}
inline std::string fmt_trade(uint64_t seq, uint64_t aggr_id, uint32_t aggr_sender, uint64_t rest_id,
                              uint32_t rest_sender, double price, uint32_t qty, bool wash, uint64_t access_cyc) {
    std::ostringstream os;
    os << "SEQ " << seq << " TRADE " << aggr_id << " " << aggr_sender << " " << rest_id << " " << rest_sender << " "
       << price << " " << qty << " " << (wash ? 1 : 0) << " " << access_cyc;
    return os.str();
}
