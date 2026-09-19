#include "Listener.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <fcntl.h>
#include <unistd.h>

namespace {

void die(const char* what, int port) {
	fprintf(stderr, "Listener: %s failed on port %d: %s\n", what, port, strerror(errno));
	exit(1);
}

}  // namespace

Listener::Listener(int port) {
	fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (fd < 0)
		die("socket", port);

	int reuse = 1;
	setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

	sockaddr_in local{};
	local.sin_family = AF_INET;
	local.sin_port = htons(port);
	local.sin_addr.s_addr = INADDR_ANY;

	if (bind(fd, (sockaddr*)&local, sizeof(local)) < 0)
		die("bind", port);
	if (listen(fd, 64) < 0)
		die("listen", port);

	int flags = fcntl(fd, F_GETFL, 0);
	fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

std::optional<Connection> Listener::accept() {
	int client_fd = ::accept(fd, nullptr, nullptr);
	if (client_fd < 0)
		return std::nullopt;

	int nodelay = 1;
	setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

	Connection conn(client_fd, nullptr);
	conn.set_nonblocking();
	return conn;
}

Listener::~Listener() {
	if (fd >= 0)
		close(fd);
}
