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

void Connection::send(const std::string& msg) {
	::send(fd, msg.data(), msg.size(), 0);
}

int Connection::receive(char* buf, int size) {
	return recv(fd, buf, size, 0);
}

Connection::~Connection() {
	close(fd);
}
