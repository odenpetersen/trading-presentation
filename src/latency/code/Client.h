#pragma once

#include "Connection.h"
#include "Protocol.h"

class Client {
	Connection conn;

public:
	Client(const char* remote_ip, int port);

	void send_new_order(Side side, Price price, Qty qty);
	void send_cancel(OrderID id);

	bool receive(Msg& msg);
};
