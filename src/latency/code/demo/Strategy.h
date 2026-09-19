#pragma once

#include <cstdint>
#include <memory>
#include <optional>
#include <unordered_map>
#include <vector>

#include "Listener.h"
#include "Protocol.h"

struct StrategyConfig {
	int control_port;
	const char* me_host;
	int me_market_data_port;
	int me_feed_in_port;
	const char* gateway_a_host;
	int gateway_a_port;
	const char* gateway_b_host;
	int gateway_b_port;
	ParticipantID taker_participant;
	ParticipantID maker_participant;
	// Demo defaults: short, so re-quoting/crossing is visibly live within a
	// couple of seconds. Tune at runtime via ConfigParam::QuoteRefreshMs.
	uint64_t quote_refresh_ms = 500;
	uint64_t taker_check_ms = 700;
};

class Strategy {
	enum class GatewayMode : int64_t { Naive = 0, Dynamic = 1, MultiShoot = 2 };
	enum class OrderRole { MakerBid, MakerAsk, Taker };

	struct Peer {
		Connection conn;
		std::vector<char> rx_buf;
	};

	struct GatewayStats {
		double ewma_us = 0;
	};

	Listener control_listener_;
	Connection md_conn_;
	Connection feed_conn_;  // outbound to ME's feed-in, for reporting RaceResult
	Connection gw_a_conn_;
	Connection gw_b_conn_;
	std::vector<char> md_rx_buf_;
	std::vector<char> gw_a_rx_buf_;
	std::vector<char> gw_b_rx_buf_;
	std::unordered_map<int, std::unique_ptr<Peer>> control_peers_;

	int epoll_fd_ = -1;
	int timer_fd_ = -1;

	ParticipantID taker_id_;
	ParticipantID maker_id_;

	GatewayMode taker_gw_mode_ = GatewayMode::Naive;
	GatewayMode maker_gw_mode_ = GatewayMode::Naive;
	int naive_rr_ = 0;
	GatewayStats gw_a_stats_, gw_b_stats_;

	// 0=washing, 1=on (matches OrderBook's own default), 2=cancel-first
	int smp_mode_ = 1;

	// Seeded from a timestamp, not 1: the ME's duplicate-coid set is global
	// and persists for its whole lifetime, so two strategy processes (or
	// two runs of the same one) must not both start counting from 1.
	uint64_t next_coid_;
	std::unordered_map<ClientOrderID, OrderRole> coid_role_;
	std::unordered_map<ClientOrderID, uint64_t> coid_send_time_;
	// pending multi-shoot races: coid -> participant, erased once the first
	// of the two gateways' responses (Ack or Reject) resolves the race
	std::unordered_map<ClientOrderID, ParticipantID> race_participant_;

	OrderID maker_bid_id_ = NONE;
	OrderID maker_ask_id_ = NONE;
	Price mid_ = 100;
	Price spread_ = 2;
	Qty maker_qty_ = 5;
	Qty taker_qty_ = 1;

	std::optional<Price> best_bid_;
	std::optional<Price> best_ask_;

	std::optional<int64_t> last_ref_price_;
	int ref_direction_ = 0;

	uint64_t quote_refresh_ns_;
	uint64_t taker_check_ns_;
	uint64_t last_quote_ns_ = 0;
	uint64_t last_taker_ns_ = 0;

public:
	explicit Strategy(const StrategyConfig& config);
	void run();

private:
	void add_to_epoll(int fd);
	void accept_control();
	void handle_control_peer_readable(int fd, Peer& peer);
	void handle_gateway_readable(int gw_index, Connection& conn, std::vector<char>& rx_buf);
	void handle_market_data_readable();
	void handle_timer();

	void handle_control_msg(const Msg& msg);
	void handle_gateway_msg(int gw_index, const Msg& msg);
	void handle_market_data_msg(const Msg& msg);

	int pick_gateway(ParticipantID participant);
	void send_new_order(ParticipantID participant, Side side, Price price, Qty qty, OrderRole role);
	void send_cancel(ParticipantID participant, OrderID id);
	void update_latency(int gw_index, ClientOrderID coid);
	void resolve_race(ClientOrderID coid, int winner_gw);

	void requote();
	void taker_step();
};
