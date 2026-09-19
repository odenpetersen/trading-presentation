#pragma once

#include <memory>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "Listener.h"
#include "OrderBook.h"
#include "Protocol.h"

struct MatchingEngineConfig {
	int order_entry_port;
	int market_data_port;
	int feed_in_port;
	int control_port;
	size_t book_capacity;
};

class MatchingEngine {
	enum class Role { OrderEntry, MarketData, FeedIn, Control };

	struct Peer {
		Connection conn;
		std::vector<char> rx_buf;
		Role role;
	};

	Listener order_entry_listener_;
	Listener market_data_listener_;
	Listener feed_in_listener_;
	Listener control_listener_;

	OrderBook book_;

	bool self_match_prevention_ = true;
	std::unordered_map<ParticipantID, bool> authorised_;
	std::unordered_map<ParticipantID, int> participant_fd_;
	std::unordered_set<ClientOrderID> seen_client_order_ids_;

	std::unordered_map<int, std::unique_ptr<Peer>> peers_;
	int epoll_fd_ = -1;

public:
	explicit MatchingEngine(const MatchingEngineConfig& config);
	void run();

private:
	void add_to_epoll(int fd);
	void accept_all(Listener& listener, Role role);
	void handle_peer_readable(int fd, Peer& peer);
	void handle_order_entry_msg(int fd, const Msg& msg);
	void handle_feed_in_msg(const Msg& msg);
	void handle_control_msg(const Msg& msg);

	void send_to_fd(int fd, const Msg& msg);
	void broadcast_market_data(const Msg& msg);
	void close_peer(int fd);
};
