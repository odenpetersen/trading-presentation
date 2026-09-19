#pragma once

#include <optional>

#include "Connection.h"

// Non-blocking listening socket for use in an epoll-driven accept loop.
class Listener {
	int fd = -1;

public:
	explicit Listener(int port);

	Listener(const Listener&) = delete;
	Listener& operator=(const Listener&) = delete;

	// Non-blocking: returns nullopt if there's no pending connection right now.
	std::optional<Connection> accept();

	int native_handle() const { return fd; }

	~Listener();
};
