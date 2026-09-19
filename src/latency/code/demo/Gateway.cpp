#include "Gateway.h"

#include <cerrno>
#include <cstring>
#include <sys/epoll.h>

Gateway::Gateway(const GatewayConfig& config)
	: strategy_listener_(config.strategy_port)
	, control_listener_(config.control_port)
	, me_conn_(config.me_order_entry_port, config.me_host)
	, auth_cache_ttl_ns_(config.auth_cache_ttl_ms * 1'000'000ull) {
	me_conn_.set_nonblocking();
}

void Gateway::add_to_epoll(int fd) {
	epoll_event ev{};
	ev.events = EPOLLIN;
	ev.data.fd = fd;
	epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev);
}

void Gateway::accept_all(Listener& listener, Role role) {
	while (auto conn = listener.accept()) {
		int fd = conn->native_handle();
		peers_[fd] = std::make_unique<Peer>(Peer{std::move(*conn), {}, role});
		add_to_epoll(fd);
	}
}

void Gateway::run() {
	epoll_fd_ = epoll_create1(0);

	add_to_epoll(strategy_listener_.native_handle());
	add_to_epoll(control_listener_.native_handle());
	add_to_epoll(me_conn_.native_handle());

	std::vector<epoll_event> events(64);

	while (true) {
		int n = epoll_wait(epoll_fd_, events.data(), events.size(), -1);

		for (int i = 0; i < n; ++i) {
			int fd = events[i].data.fd;

			if (fd == strategy_listener_.native_handle())
				accept_all(strategy_listener_, Role::Strategy);
			else if (fd == control_listener_.native_handle())
				accept_all(control_listener_, Role::Control);
			else if (fd == me_conn_.native_handle())
				handle_me_readable();
			else if (auto it = peers_.find(fd); it != peers_.end())
				handle_peer_readable(fd, *it->second);
		}
	}
}

void Gateway::handle_peer_readable(int fd, Peer& peer) {
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

		if (peer.role == Role::Strategy)
			handle_strategy_msg(fd, msg);
		else
			handle_control_msg(msg);
	}

	if (closed)
		close_peer(fd);
}

void Gateway::handle_me_readable() {
	char buf[4096];

	while (true) {
		int n = me_conn_.receive(buf, sizeof(buf));

		if (n > 0) {
			me_rx_buf_.insert(me_rx_buf_.end(), buf, buf + n);
			continue;
		}

		break;  // EAGAIN, or ME connection dropped (fatal for a demo - not handled further)
	}

	while (me_rx_buf_.size() >= sizeof(Msg)) {
		Msg msg;
		std::memcpy(&msg, me_rx_buf_.data(), sizeof(Msg));
		me_rx_buf_.erase(me_rx_buf_.begin(), me_rx_buf_.begin() + sizeof(Msg));
		handle_me_msg(msg);
	}
}

ParticipantID Gateway::participant_of(const Msg& msg) const {
	return msg.type == MsgType::NewOrder ? msg.new_order.participant_id : msg.cancel.participant_id;
}

void Gateway::forward_to_me(int strategy_fd, const Msg& msg) {
	ClientOrderID coid = msg.type == MsgType::NewOrder ? msg.new_order.client_order_id : msg.cancel.client_order_id;
	coid_to_strategy_fd_[coid] = strategy_fd;
	me_conn_.send(&msg, sizeof(msg));
}

void Gateway::drain_pending(ParticipantID participant) {
	auto it = pending_by_participant_.find(participant);
	if (it == pending_by_participant_.end())
		return;

	bool authorised = auth_cache_[participant].authorised;

	for (auto& pending : it->second) {
		if (authorised) {
			forward_to_me(pending.strategy_fd, pending.msg);
		} else {
			ClientOrderID coid = pending.msg.type == MsgType::NewOrder
				? pending.msg.new_order.client_order_id
				: pending.msg.cancel.client_order_id;
			send_to_fd(pending.strategy_fd, make_reject(coid, RejectReason::NotAuthorised));
		}
	}

	pending_by_participant_.erase(it);
}

void Gateway::handle_strategy_msg(int fd, const Msg& msg) {
	if (msg.type != MsgType::NewOrder && msg.type != MsgType::Cancel)
		return;

	ParticipantID participant = participant_of(msg);

	auto it = auth_cache_.find(participant);
	bool fresh = it != auth_cache_.end() && (now_ns() - it->second.checked_at_ns) <= auth_cache_ttl_ns_;

	if (fresh) {
		if (it->second.authorised) {
			forward_to_me(fd, msg);
		} else {
			ClientOrderID coid = msg.type == MsgType::NewOrder ? msg.new_order.client_order_id : msg.cancel.client_order_id;
			send_to_fd(fd, make_reject(coid, RejectReason::NotAuthorised));
		}
		return;
	}

	pending_by_participant_[participant].push_back({fd, msg});

	if (auth_check_in_flight_.insert(participant).second) {
		auto req = make_auth_check_request(participant);
		me_conn_.send(&req, sizeof(req));
	}
}

void Gateway::handle_me_msg(const Msg& msg) {
	switch (msg.type) {
		case MsgType::Ack: {
			Msg out = msg;
			out.ack.gateway_time = now_ns();
			if (auto it = coid_to_strategy_fd_.find(out.ack.client_order_id); it != coid_to_strategy_fd_.end())
				send_to_fd(it->second, out);
			break;
		}
		case MsgType::Fill: {
			Msg out = msg;
			out.fill.gateway_time = now_ns();
			if (auto it = coid_to_strategy_fd_.find(out.fill.client_order_id); it != coid_to_strategy_fd_.end())
				send_to_fd(it->second, out);
			break;
		}
		case MsgType::Reject: {
			if (auto it = coid_to_strategy_fd_.find(msg.reject.client_order_id); it != coid_to_strategy_fd_.end())
				send_to_fd(it->second, msg);
			break;
		}
		case MsgType::AuthCheckResponse: {
			auto participant = msg.auth_check_response.participant_id;
			auth_cache_[participant] = {msg.auth_check_response.authorised, now_ns()};
			auth_check_in_flight_.erase(participant);
			drain_pending(participant);
			break;
		}
		default:
			break;
	}
}

void Gateway::handle_control_msg(const Msg& msg) {
	if (msg.type != MsgType::SetConfig)
		return;

	if (msg.set_config.param == ConfigParam::AuthCacheTtlMs)
		auth_cache_ttl_ns_ = static_cast<uint64_t>(msg.set_config.value) * 1'000'000ull;
}

void Gateway::send_to_fd(int fd, const Msg& msg) {
	if (auto it = peers_.find(fd); it != peers_.end())
		it->second->conn.send(&msg, sizeof(msg));
}

void Gateway::close_peer(int fd) {
	epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
	peers_.erase(fd);
}
