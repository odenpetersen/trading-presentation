#include "Connection.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>

namespace {

void die(const char* what) {
	fprintf(stderr, "Connection: %s failed: %s\n", what, strerror(errno));
	exit(1);
}

}  // namespace

Connection::Connection(int port, const char* remote_ip) {
	if (remote_ip) {
		fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
		if (fd < 0)
			die("socket");

		sockaddr_in addr{};
		addr.sin_family = AF_INET;
		addr.sin_port = htons(port);
		inet_pton(AF_INET, remote_ip, &addr.sin_addr);

		if (connect(fd, (sockaddr*)&addr, sizeof(addr)) < 0)
			die("connect");
	} else {
		int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
		if (listen_fd < 0)
			die("socket");

		int reuse = 1;
		setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

		sockaddr_in local{};
		local.sin_family = AF_INET;
		local.sin_port = htons(port);
		local.sin_addr.s_addr = INADDR_ANY;

		if (bind(listen_fd, (sockaddr*)&local, sizeof(local)) < 0)
			die("bind");
		if (listen(listen_fd, 10) < 0)
			die("listen");

		fd = accept(listen_fd, nullptr, nullptr);
		if (fd < 0)
			die("accept");

		close(listen_fd);
	}

	int nodelay = 1;
	setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
}

Connection::Connection(Connection&& other) noexcept : fd(other.fd) {
	other.fd = -1;
}

Connection& Connection::operator=(Connection&& other) noexcept {
	if (this != &other) {
		if (fd >= 0)
			close(fd);
		fd = other.fd;
		other.fd = -1;
	}
	return *this;
}

void Connection::set_nonblocking() {
	int flags = fcntl(fd, F_GETFL, 0);
	fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

void Connection::send(const void* data, size_t size) {
	auto* p = static_cast<const char*>(data);
	size_t sent = 0;

	while (sent < size) {
		ssize_t n = ::send(fd, p + sent, size - sent, 0);
		if (n <= 0)
			break;
		sent += n;
	}
}

int Connection::receive(char* buf, int size) {
	return recv(fd, buf, size, 0);
}

bool Connection::receive_exact(void* buf, size_t size) {
	auto* p = static_cast<char*>(buf);
	size_t got = 0;

	while (got < size) {
		int n = receive(p + got, size - got);
		if (n <= 0)
			return false;
		got += n;
	}

	return true;
}

Connection::~Connection() {
	if (fd >= 0)
		close(fd);
}
