#pragma once

#include <chrono>
#include <memory>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "Listener.h"
#include "Protocol.h"

struct GatewayConfig {
	int strategy_port;
	int control_port;
	const char* me_host;
	int me_order_entry_port;
	// Demo default: very short, so cache-warm vs re-poll is visible live
	// within a second or two rather than a real 10s wait. Tune at runtime
	// via ConfigParam::AuthCacheTtlMs.
	uint64_t auth_cache_ttl_ms = 1000;
};

class Gateway {
	enum class Role { Strategy, Control };

	struct Peer {
		Connection conn;
		std::vector<char> rx_buf;
		Role role;
	};

	struct AuthEntry {
		bool authorised;
		uint64_t checked_at_ns;
	};

	struct PendingOrder {
		int strategy_fd;
		Msg msg;
	};

	Listener strategy_listener_;
	Listener control_listener_;
	Connection me_conn_;
	std::vector<char> me_rx_buf_;

	uint64_t auth_cache_ttl_ns_;
	std::unordered_map<ParticipantID, AuthEntry> auth_cache_;
	std::unordered_map<ParticipantID, std::vector<PendingOrder>> pending_by_participant_;
	std::unordered_set<ParticipantID> auth_check_in_flight_;

	// Not purged: a resting maker order can generate fills long after it
	// was submitted, and we need to know which strategy connection to
	// relay them to. Acceptable growth for a demo-length session.
	std::unordered_map<ClientOrderID, int> coid_to_strategy_fd_;

	std::unordered_map<int, std::unique_ptr<Peer>> peers_;
	int epoll_fd_ = -1;

public:
	explicit Gateway(const GatewayConfig& config);
	void run();

private:
	void add_to_epoll(int fd);
	void accept_all(Listener& listener, Role role);
	void handle_peer_readable(int fd, Peer& peer);
	void handle_me_readable();

	void handle_strategy_msg(int fd, const Msg& msg);
	void handle_control_msg(const Msg& msg);
	void handle_me_msg(const Msg& msg);

	ParticipantID participant_of(const Msg& msg) const;
	void forward_to_me(int strategy_fd, const Msg& msg);
	void drain_pending(ParticipantID participant);

	void send_to_fd(int fd, const Msg& msg);
	void close_peer(int fd);
};
