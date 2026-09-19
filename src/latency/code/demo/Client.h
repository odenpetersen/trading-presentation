#pragma once

#include "Connection.h"
#include "Protocol.h"

// Stands in for a gateway+strategy pair during local testing: one
// connection to the ME's order-entry port, one to its market-data port.
class Client {
	Connection order_conn_;
	Connection market_data_conn_;

public:
	Client(const char* remote_ip, int order_entry_port, int market_data_port);

	void send_new_order(ClientOrderID coid, ParticipantID participant, Side side, Price price, Qty qty);
	void send_cancel(ClientOrderID coid, ParticipantID participant, OrderID id);

	bool receive_exec(Msg& msg);         // Ack/Fill/Reject
	bool receive_market_data(Msg& msg);  // LevelUpdate/Trade/RefPrice

	int exec_fd() const { return order_conn_.native_handle(); }
	int market_data_fd() const { return market_data_conn_.native_handle(); }
};
