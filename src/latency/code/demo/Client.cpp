#include "Client.h"

Client::Client(const char* remote_ip, int order_entry_port, int market_data_port)
	: order_conn_(order_entry_port, remote_ip)
	, market_data_conn_(market_data_port, remote_ip) {
}

void Client::send_new_order(ClientOrderID coid, ParticipantID participant, Side side, Price price, Qty qty) {
	auto msg = make_new_order(coid, participant, side, price, qty);
	order_conn_.send(&msg, sizeof(msg));
}

void Client::send_cancel(ClientOrderID coid, ParticipantID participant, OrderID id) {
	auto msg = make_cancel(coid, participant, id);
	order_conn_.send(&msg, sizeof(msg));
}

bool Client::receive_exec(Msg& msg) {
	return order_conn_.receive_exact(&msg, sizeof(msg));
}

bool Client::receive_market_data(Msg& msg) {
	return market_data_conn_.receive_exact(&msg, sizeof(msg));
}
