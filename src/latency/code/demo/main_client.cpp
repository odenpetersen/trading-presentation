// Test harness standing in for a strategy. Order entry defaults to the ME's
// own port (direct, for ME-only testing) but can be pointed at a gateway's
// strategy port instead - market data always goes straight to the ME either
// way, matching the real topology.
// usage: client.out [remote_ip] [participant_id] [buy|sell] [price] [qty] [client_order_id] [order_entry_port]
#include <cstdio>
#include <cstdlib>
#include <poll.h>

#include "Client.h"

static const int ORDER_ENTRY_PORT = 17000;
static const int MARKET_DATA_PORT = 17001;

static void print_msg(const char* tag, const Msg& msg) {
	switch (msg.type) {
		case MsgType::Ack: {
			auto& a = msg.ack;
			long long gw_delay = a.gateway_time ? (long long)(a.gateway_time - a.me_time) : 0;
			std::printf("%s ack: order=%u coid=%llu me_to_gw=%lldus\n", tag,
				a.id, (unsigned long long)a.client_order_id, gw_delay / 1000);
			break;
		}
		case MsgType::Fill: {
			auto& f = msg.fill;
			long long gw_delay = f.gateway_time ? (long long)(f.gateway_time - f.me_time) : 0;
			std::printf("%s fill: order=%u coid=%llu price=%u qty=%u me_to_gw=%lldus\n", tag,
				f.id, (unsigned long long)f.client_order_id, f.price, f.qty, gw_delay / 1000);
			break;
		}
		case MsgType::Reject:
			std::printf("%s reject: coid=%llu reason=%d\n", tag,
				(unsigned long long)msg.reject.client_order_id, (int)msg.reject.reason);
			break;
		case MsgType::LevelUpdate:
			std::printf("%s level: side=%s price=%u qty=%u %s\n", tag,
				msg.level_update.side == Side::Buy ? "buy" : "sell",
				msg.level_update.price, msg.level_update.qty,
				msg.level_update.added ? "added" : "removed");
			break;
		case MsgType::Trade:
			std::printf("%s trade: side=%s price=%u qty=%u\n", tag,
				msg.trade.side == Side::Buy ? "buy" : "sell", msg.trade.price, msg.trade.qty);
			break;
		default:
			std::printf("%s other msg type=%d\n", tag, (int)msg.type);
			break;
	}
}

int main(int argc, char** argv) {
	std::setvbuf(stdout, nullptr, _IOLBF, 0);

	const char* remote_ip = argc > 1 ? argv[1] : "127.0.0.1";
	ParticipantID participant = argc > 2 ? std::strtoul(argv[2], nullptr, 10) : 1;
	Side side = (argc > 3 && argv[3][0] == 's') ? Side::Sell : Side::Buy;
	Price price = argc > 4 ? std::strtoul(argv[4], nullptr, 10) : 100;
	Qty qty = argc > 5 ? std::strtoul(argv[5], nullptr, 10) : 10;
	ClientOrderID coid = argc > 6 ? std::strtoull(argv[6], nullptr, 10) : 1;
	int order_entry_port = argc > 7 ? std::atoi(argv[7]) : ORDER_ENTRY_PORT;

	Client client(remote_ip, order_entry_port, MARKET_DATA_PORT);

	client.send_new_order(coid, participant, side, price, qty);

	pollfd fds[2] = {
		{client.exec_fd(), POLLIN, 0},
		{client.market_data_fd(), POLLIN, 0},
	};

	while (poll(fds, 2, -1) > 0) {
		if (fds[0].revents & POLLIN) {
			Msg msg;
			if (!client.receive_exec(msg))
				break;
			print_msg("exec", msg);
		}
		if (fds[1].revents & POLLIN) {
			Msg msg;
			if (!client.receive_market_data(msg))
				break;
			print_msg("md", msg);
		}
	}
}
