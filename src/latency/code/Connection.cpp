#include "Connection.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string>

Connection::Connection(int port, const char* remote_ip) {
	int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

	sockaddr_in local{};
	local.sin_family = AF_INET;
	local.sin_port = htons(port);
	local.sin_addr.s_addr = INADDR_ANY;

	bind(listen_fd, (sockaddr*)&local, sizeof(local));
	listen(listen_fd, 10);

	if (remote_ip) {
		fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

		sockaddr_in addr{};
		addr.sin_family = AF_INET;
		addr.sin_port = htons(port);
		inet_pton(AF_INET, remote_ip, &addr.sin_addr);

		connect(fd, (sockaddr*)&addr, sizeof(addr));
	} else {
		fd = accept(listen_fd, nullptr, nullptr);
	}

	close(listen_fd);
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
	close(fd);
}
