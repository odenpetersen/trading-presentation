#include "Strategy.h"

#include <cerrno>
#include <cstring>
#include <sys/epoll.h>
#include <sys/timerfd.h>
#include <unistd.h>

namespace {
constexpr uint64_t TICK_NS = 100'000'000ull;  // 100ms reactor tick
}

Strategy::Strategy(const StrategyConfig& config)
	: control_listener_(config.control_port)
	, md_conn_(config.me_market_data_port, config.me_host)
	, feed_conn_(config.me_feed_in_port, config.me_host)
	, gw_a_conn_(config.gateway_a_port, config.gateway_a_host)
	, gw_b_conn_(config.gateway_b_port, config.gateway_b_host)
	, taker_id_(config.taker_participant)
	, maker_id_(config.maker_participant)
	, quote_refresh_ns_(config.quote_refresh_ms * 1'000'000ull)
	, taker_check_ns_(config.taker_check_ms * 1'000'000ull) {
	md_conn_.set_nonblocking();
	gw_a_conn_.set_nonblocking();
	gw_b_conn_.set_nonblocking();
	next_coid_ = now_ns();
}

void Strategy::add_to_epoll(int fd) {
	epoll_event ev{};
	ev.events = EPOLLIN;
	ev.data.fd = fd;
	epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev);
}

void Strategy::accept_control() {
	while (auto conn = control_listener_.accept()) {
		int fd = conn->native_handle();
		control_peers_[fd] = std::make_unique<Peer>(Peer{std::move(*conn), {}});
		add_to_epoll(fd);
	}
}

void Strategy::run() {
	epoll_fd_ = epoll_create1(0);

	timer_fd_ = timerfd_create(CLOCK_MONOTONIC, 0);
	itimerspec spec{};
	spec.it_value.tv_nsec = TICK_NS;
	spec.it_interval.tv_nsec = TICK_NS;
	timerfd_settime(timer_fd_, 0, &spec, nullptr);

	add_to_epoll(control_listener_.native_handle());
	add_to_epoll(md_conn_.native_handle());
	add_to_epoll(gw_a_conn_.native_handle());
	add_to_epoll(gw_b_conn_.native_handle());
	add_to_epoll(timer_fd_);

	std::vector<epoll_event> events(64);

	while (true) {
		int n = epoll_wait(epoll_fd_, events.data(), events.size(), -1);

		for (int i = 0; i < n; ++i) {
			int fd = events[i].data.fd;

			if (fd == control_listener_.native_handle())
				accept_control();
			else if (fd == md_conn_.native_handle())
				handle_market_data_readable();
			else if (fd == gw_a_conn_.native_handle())
				handle_gateway_readable(0, gw_a_conn_, gw_a_rx_buf_);
			else if (fd == gw_b_conn_.native_handle())
				handle_gateway_readable(1, gw_b_conn_, gw_b_rx_buf_);
			else if (fd == timer_fd_)
				handle_timer();
			else if (auto it = control_peers_.find(fd); it != control_peers_.end())
				handle_control_peer_readable(fd, *it->second);
		}
	}
}

void Strategy::handle_timer() {
	uint64_t expirations;
	auto n = read(timer_fd_, &expirations, sizeof(expirations));
	(void)n;

	uint64_t t = now_ns();

	if (t - last_quote_ns_ >= quote_refresh_ns_) {
		requote();
		last_quote_ns_ = t;
	}

	if (t - last_taker_ns_ >= taker_check_ns_) {
		taker_step();
		last_taker_ns_ = t;
	}
}

void Strategy::handle_control_peer_readable(int fd, Peer& peer) {
	char buf[4096];
	bool closed = false;

	while (true) {
		int n = peer.conn.receive(buf, sizeof(buf));

		if (n > 0) {
			peer.rx_buf.insert(peer.rx_buf.end(), buf, buf + n);
			continue;
		}

		if (n == 0 || (errno != EAGAIN && errno != EWOULDBLOCK))
			closed = true;

		break;
	}

	while (peer.rx_buf.size() >= sizeof(Msg)) {
		Msg msg;
		std::memcpy(&msg, peer.rx_buf.data(), sizeof(Msg));
		peer.rx_buf.erase(peer.rx_buf.begin(), peer.rx_buf.begin() + sizeof(Msg));
		handle_control_msg(msg);
	}

	if (closed) {
		epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
		control_peers_.erase(fd);
	}
}

void Strategy::handle_gateway_readable(int gw_index, Connection& conn, std::vector<char>& rx_buf) {
	char buf[4096];

	while (true) {
		int n = conn.receive(buf, sizeof(buf));

		if (n > 0) {
			rx_buf.insert(rx_buf.end(), buf, buf + n);
			continue;
		}

		break;  // EAGAIN, or gateway connection dropped (fatal for a demo - not handled further)
	}

	while (rx_buf.size() >= sizeof(Msg)) {
		Msg msg;
		std::memcpy(&msg, rx_buf.data(), sizeof(Msg));
		rx_buf.erase(rx_buf.begin(), rx_buf.begin() + sizeof(Msg));
		handle_gateway_msg(gw_index, msg);
	}
}

void Strategy::handle_market_data_readable() {
	char buf[4096];

	while (true) {
		int n = md_conn_.receive(buf, sizeof(buf));

		if (n > 0) {
			md_rx_buf_.insert(md_rx_buf_.end(), buf, buf + n);
			continue;
		}

		break;
	}

	while (md_rx_buf_.size() >= sizeof(Msg)) {
		Msg msg;
		std::memcpy(&msg, md_rx_buf_.data(), sizeof(Msg));
		md_rx_buf_.erase(md_rx_buf_.begin(), md_rx_buf_.begin() + sizeof(Msg));
		handle_market_data_msg(msg);
	}
}

void Strategy::handle_market_data_msg(const Msg& msg) {
	if (msg.type == MsgType::RefPrice) {
		if (last_ref_price_)
			ref_direction_ = msg.ref_price.price == *last_ref_price_ ? ref_direction_ : (msg.ref_price.price > *last_ref_price_ ? 1 : -1);
		last_ref_price_ = msg.ref_price.price;
		return;
	}

	if (msg.type != MsgType::LevelUpdate)
		return;

	auto& lu = msg.level_update;
	auto& best = lu.side == Side::Buy ? best_bid_ : best_ask_;

	// Naive local book view - tracks only the most recently added price per
	// side, good enough as a simple crossing signal for this demo's taker.
	if (lu.added)
		best = lu.price;
	else if (best && *best == lu.price)
		best.reset();
}

void Strategy::handle_gateway_msg(int gw_index, const Msg& msg) {
	switch (msg.type) {
		case MsgType::Ack: {
			update_latency(gw_index, msg.ack.client_order_id);
			if (auto it = coid_role_.find(msg.ack.client_order_id); it != coid_role_.end()) {
				if (it->second == OrderRole::MakerBid)
					maker_bid_id_ = msg.ack.id;
				else if (it->second == OrderRole::MakerAsk)
					maker_ask_id_ = msg.ack.id;
			}
			resolve_race(msg.ack.client_order_id, gw_index);
			break;
		}
		case MsgType::Fill:
			update_latency(gw_index, msg.fill.client_order_id);
			break;
		case MsgType::Reject:
			// Duplicate rejects are expected on the losing gateway in
			// multi-shoot mode - the OTHER gateway is the one that won.
			resolve_race(msg.reject.client_order_id, 1 - gw_index);
			break;
		default:
			break;
	}
}

void Strategy::handle_control_msg(const Msg& msg) {
	if (msg.type != MsgType::SetConfig)
		return;

	switch (msg.set_config.param) {
		case ConfigParam::GatewaySelectionMode: {
			auto mode = static_cast<GatewayMode>(msg.set_config.value);
			if (msg.set_config.target_participant == taker_id_)
				taker_gw_mode_ = mode;
			else if (msg.set_config.target_participant == maker_id_)
				maker_gw_mode_ = mode;
			break;
		}
		case ConfigParam::SelfMatchPrevention:
			smp_mode_ = static_cast<int>(msg.set_config.value);
			break;
		case ConfigParam::QuoteRefreshMs:
			quote_refresh_ns_ = static_cast<uint64_t>(msg.set_config.value) * 1'000'000ull;
			break;
		default:
			break;  // not applicable to the strategy
	}
}

int Strategy::pick_gateway(ParticipantID participant) {
	auto mode = participant == taker_id_ ? taker_gw_mode_ : maker_gw_mode_;

	if (mode == GatewayMode::Dynamic)
		return gw_a_stats_.ewma_us <= gw_b_stats_.ewma_us ? 0 : 1;

	naive_rr_ ^= 1;
	return naive_rr_;
}

void Strategy::update_latency(int gw_index, ClientOrderID coid) {
	auto it = coid_send_time_.find(coid);
	if (it == coid_send_time_.end())
		return;

	double us = (now_ns() - it->second) / 1000.0;
	auto& stats = gw_index == 0 ? gw_a_stats_ : gw_b_stats_;
	stats.ewma_us = stats.ewma_us <= 0 ? us : 0.7 * stats.ewma_us + 0.3 * us;

	coid_send_time_.erase(it);
}

void Strategy::resolve_race(ClientOrderID coid, int winner_gw) {
	auto it = race_participant_.find(coid);
	if (it == race_participant_.end())
		return;  // not a multi-shoot race, or already resolved by the other gateway's response

	auto msg = make_race_result(it->second, static_cast<uint8_t>(winner_gw));
	feed_conn_.send(&msg, sizeof(msg));
	race_participant_.erase(it);
}

void Strategy::send_new_order(ParticipantID participant, Side side, Price price, Qty qty, OrderRole role) {
	ClientOrderID coid = next_coid_++;
	coid_role_[coid] = role;

	Msg msg = make_new_order(coid, participant, side, price, qty);
	auto mode = participant == taker_id_ ? taker_gw_mode_ : maker_gw_mode_;

	if (mode == GatewayMode::MultiShoot) {
		coid_send_time_[coid] = now_ns();
		race_participant_[coid] = participant;
		gw_a_conn_.send(&msg, sizeof(msg));
		gw_b_conn_.send(&msg, sizeof(msg));
		return;
	}

	coid_send_time_[coid] = now_ns();
	(pick_gateway(participant) == 0 ? gw_a_conn_ : gw_b_conn_).send(&msg, sizeof(msg));
}

void Strategy::send_cancel(ParticipantID participant, OrderID id) {
	Msg msg = make_cancel(next_coid_++, participant, id);
	(pick_gateway(participant) == 0 ? gw_a_conn_ : gw_b_conn_).send(&msg, sizeof(msg));
}

void Strategy::requote() {
	if (maker_bid_id_ != NONE) {
		send_cancel(maker_id_, maker_bid_id_);
		maker_bid_id_ = NONE;
	}
	if (maker_ask_id_ != NONE) {
		send_cancel(maker_id_, maker_ask_id_);
		maker_ask_id_ = NONE;
	}

	send_new_order(maker_id_, Side::Buy, mid_ - spread_, maker_qty_, OrderRole::MakerBid);
	send_new_order(maker_id_, Side::Sell, mid_ + spread_, maker_qty_, OrderRole::MakerAsk);
}

void Strategy::taker_step() {
	// cancel-first heuristic: matches by price against our own resting quote,
	// since the taker has no way to know whose order it'd actually hit
	if (ref_direction_ > 0 && best_ask_) {
		if (smp_mode_ == 2 && maker_ask_id_ != NONE && *best_ask_ == mid_ + spread_) {
			send_cancel(maker_id_, maker_ask_id_);
			maker_ask_id_ = NONE;
		}
		send_new_order(taker_id_, Side::Buy, *best_ask_, taker_qty_, OrderRole::Taker);
	} else if (ref_direction_ < 0 && best_bid_) {
		if (smp_mode_ == 2 && maker_bid_id_ != NONE && *best_bid_ == mid_ - spread_) {
			send_cancel(maker_id_, maker_bid_id_);
			maker_bid_id_ = NONE;
		}
		send_new_order(taker_id_, Side::Sell, *best_bid_, taker_qty_, OrderRole::Taker);
	}
}
