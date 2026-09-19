#pragma once

#include <cstddef>

class Listener;

// Owns exactly one TCP socket. Move-only: copying would double-close the fd.
class Connection {
	int fd = -1;

	explicit Connection(int adopted_fd, std::nullptr_t) : fd(adopted_fd) {}

	friend class Listener;

	public:
	explicit Connection(int port, const char* remote_ip = nullptr);

	Connection(const Connection&) = delete;
	Connection& operator=(const Connection&) = delete;

	Connection(Connection&& other) noexcept;
	Connection& operator=(Connection&& other) noexcept;

	void set_nonblocking();

	// Best-effort: assumes messages are small enough to always fit in the
	// socket send buffer in one go. Fine for this demo's tiny fixed-size
	// messages at low rates; a real reactor would need an EPOLLOUT-driven
	// write queue for backpressure.
	void send(const void* data, size_t size);

	int receive(char* buf, int size);
	bool receive_exact(void* buf, size_t size);

	int native_handle() const { return fd; }

	~Connection();
};
