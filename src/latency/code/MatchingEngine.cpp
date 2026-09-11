#include "MatchingEngine.h"

#include "Protocol.h"

MatchingEngine::MatchingEngine(int port, size_t capacity)
	: conn(port), book(capacity) {
}

void MatchingEngine::run() {
	Msg msg;

	while (conn.receive_exact(&msg, sizeof(msg))) {
		switch (msg.type) {
			case MsgType::NewOrder: {
				auto [side, price, qty] = msg.new_order;

				auto id = book.add(side, price, qty);

				auto ack = make_ack(id);
				conn.send(&ack, sizeof(ack));

				auto level = make_level_update(side, price, qty, true);
				conn.send(&level, sizeof(level));
				break;
			}
			case MsgType::Cancel: {
				auto result = book.cancel(msg.cancel.id);

				auto level = make_level_update(result.side, result.price, result.qty, false);
				conn.send(&level, sizeof(level));
				break;
			}
			default:
				break;
		}
	}
}
