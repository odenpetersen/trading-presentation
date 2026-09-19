#include "MatchingEngine.h"

#include <cerrno>
#include <cstring>
#include <sys/epoll.h>

namespace {

Side opposite(Side s) {
	return s == Side::Buy ? Side::Sell : Side::Buy;
}

}  // namespace

MatchingEngine::MatchingEngine(const MatchingEngineConfig& config)
	: order_entry_listener_(config.order_entry_port)
	, market_data_listener_(config.market_data_port)
	, feed_in_listener_(config.feed_in_port)
	, control_listener_(config.control_port)
	, book_(config.book_capacity) {
}

void MatchingEngine::add_to_epoll(int fd) {
	epoll_event ev{};
	ev.events = EPOLLIN;
	ev.data.fd = fd;
	epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev);
}

void MatchingEngine::accept_all(Listener& listener, Role role) {
	while (auto conn = listener.accept()) {
		int fd = conn->native_handle();
		peers_[fd] = std::make_unique<Peer>(Peer{std::move(*conn), {}, role});
		add_to_epoll(fd);
	}
}

void MatchingEngine::run() {
	epoll_fd_ = epoll_create1(0);

	add_to_epoll(order_entry_listener_.native_handle());
	add_to_epoll(market_data_listener_.native_handle());
	add_to_epoll(feed_in_listener_.native_handle());
	add_to_epoll(control_listener_.native_handle());

	std::vector<epoll_event> events(64);

	while (true) {
		int n = epoll_wait(epoll_fd_, events.data(), events.size(), -1);

		for (int i = 0; i < n; ++i) {
			int fd = events[i].data.fd;

			if (fd == order_entry_listener_.native_handle())
				accept_all(order_entry_listener_, Role::OrderEntry);
			else if (fd == market_data_listener_.native_handle())
				accept_all(market_data_listener_, Role::MarketData);
			else if (fd == feed_in_listener_.native_handle())
				accept_all(feed_in_listener_, Role::FeedIn);
			else if (fd == control_listener_.native_handle())
				accept_all(control_listener_, Role::Control);
			else if (auto it = peers_.find(fd); it != peers_.end())
				handle_peer_readable(fd, *it->second);
		}
	}
}

void MatchingEngine::handle_peer_readable(int fd, Peer& peer) {
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

		switch (peer.role) {
			case Role::OrderEntry: handle_order_entry_msg(fd, msg); break;
			case Role::FeedIn: handle_feed_in_msg(msg); break;
			case Role::Control: handle_control_msg(msg); break;
			case Role::MarketData: break;
		}
	}

	if (closed)
		close_peer(fd);
}

void MatchingEngine::handle_order_entry_msg(int fd, const Msg& msg) {
	uint64_t me_time = now_ns();

	switch (msg.type) {
		case MsgType::NewOrder: {
			auto o = msg.new_order;
			participant_fd_[o.participant_id] = fd;

			if (!seen_client_order_ids_.insert(o.client_order_id).second) {
				send_to_fd(fd, make_reject(o.client_order_id, RejectReason::Duplicate));
				break;
			}

			if (auto it = authorised_.find(o.participant_id); it != authorised_.end() && !it->second) {
				send_to_fd(fd, make_reject(o.client_order_id, RejectReason::NotAuthorised));
				break;
			}

			auto result = book_.add(o.side, o.price, o.qty, o.participant_id, o.client_order_id, self_match_prevention_);

			send_to_fd(fd, make_ack(result.id, o.client_order_id, me_time, 0, now_ns()));

			for (auto& f : result.fills) {
				auto publish_time = now_ns();

				send_to_fd(fd, make_fill(result.id, o.client_order_id, f.price, f.qty, me_time, 0, publish_time));

				if (auto maker_it = participant_fd_.find(f.maker_participant); maker_it != participant_fd_.end())
					send_to_fd(maker_it->second, make_fill(f.maker_id, f.maker_client_order_id, f.price, f.qty, me_time, 0, publish_time));

				broadcast_market_data(make_trade(o.side, f.price, f.qty));
				broadcast_market_data(make_trade_report(o.client_order_id, o.participant_id, f.maker_participant, o.side, f.price, f.qty, me_time, publish_time));
				broadcast_market_data(make_level_update(opposite(o.side), f.price, f.qty, false));
			}

			if (result.id != NONE)
				broadcast_market_data(make_level_update(o.side, o.price, o.qty - result.filled_qty, true));

			break;
		}
		case MsgType::Cancel: {
			auto c = msg.cancel;
			participant_fd_[c.participant_id] = fd;

			auto result = book_.cancel(c.id, c.participant_id);

			if (!result.ok) {
				send_to_fd(fd, make_reject(c.client_order_id, RejectReason::WrongOwner));
				break;
			}

			broadcast_market_data(make_level_update(result.side, result.price, result.qty, false));
			break;
		}
		case MsgType::AuthCheckRequest: {
			auto participant = msg.auth_check_request.participant_id;
			auto it = authorised_.find(participant);
			bool ok = it == authorised_.end() ? true : it->second;
			send_to_fd(fd, make_auth_check_response(participant, ok, now_ns()));
			break;
		}
		default:
			break;
	}
}

void MatchingEngine::handle_feed_in_msg(const Msg& msg) {
	if (msg.type == MsgType::RefPrice || msg.type == MsgType::RaceResult)
		broadcast_market_data(msg);
}

void MatchingEngine::handle_control_msg(const Msg& msg) {
	if (msg.type != MsgType::SetConfig)
		return;

	auto& c = msg.set_config;

	switch (c.param) {
		case ConfigParam::SelfMatchPrevention:
			self_match_prevention_ = c.value == 1;  // 0=washing, 1=on, 2=cancel-first (ME side is same as washing)
			break;
		case ConfigParam::ParticipantAuthorised:
			authorised_[c.target_participant] = c.value != 0;
			break;
		case ConfigParam::GatewaySelectionMode:
		case ConfigParam::AuthCacheTtlMs:
		case ConfigParam::QuoteRefreshMs:
			break;  // not applicable to the ME
	}
}

void MatchingEngine::send_to_fd(int fd, const Msg& msg) {
	if (auto it = peers_.find(fd); it != peers_.end())
		it->second->conn.send(&msg, sizeof(msg));
}

void MatchingEngine::broadcast_market_data(const Msg& msg) {
	for (auto& [fd, peer] : peers_) {
		(void)fd;
		if (peer->role == Role::MarketData)
			peer->conn.send(&msg, sizeof(msg));
	}
}

void MatchingEngine::close_peer(int fd) {
	epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
	std::erase_if(participant_fd_, [fd](const auto& kv) { return kv.second == fd; });
	peers_.erase(fd);
}
