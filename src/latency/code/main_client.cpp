#include <cstdio>

#include "Client.h"

static const int PORT = 7000;

int main(int argc, char** argv) {
	const char* remote_ip = argc > 1 ? argv[1] : "127.0.0.1";

	Client client(remote_ip, PORT);

	client.send_new_order(Side::Buy, 100, 10);

	Msg msg;
	while (client.receive(msg)) {
		switch (msg.type) {
			case MsgType::Ack:
				std::printf("ack: order %u\n", msg.ack.id);
				break;
			case MsgType::Fill:
				std::printf("fill: order %u price %u qty %u\n",
					msg.fill.id, msg.fill.price, msg.fill.qty);
				break;
			case MsgType::LevelUpdate:
				std::printf("level: side %s price %u qty %u %s\n",
					msg.level_update.side == Side::Buy ? "buy" : "sell",
					msg.level_update.price, msg.level_update.qty,
					msg.level_update.added ? "added" : "removed");
				break;
			case MsgType::Trade:
				std::printf("trade: side %s price %u qty %u\n",
					msg.trade.side == Side::Buy ? "buy" : "sell",
					msg.trade.price, msg.trade.qty);
				break;
			default:
				break;
		}
	}
}
