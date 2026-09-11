#include "Client.h"

Client::Client(const char* remote_ip, int port)
	: conn(port, remote_ip) {
}

void Client::send_new_order(Side side, Price price, Qty qty) {
	auto msg = make_new_order(side, price, qty);
	conn.send(&msg, sizeof(msg));
}

void Client::send_cancel(OrderID id) {
	auto msg = make_cancel(id);
	conn.send(&msg, sizeof(msg));
}

bool Client::receive(Msg& msg) {
	return conn.receive_exact(&msg, sizeof(msg));
}
