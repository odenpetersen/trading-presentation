#include "Connection.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string>

class Connection {
	int fd;

	public:
	Connection(int port, const char* remote_ip = nullptr) {
		int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

		sockaddr_in local = {
			.sin_family = AF_INET,
			.sin_port = htons(port),
			.sin_addr = { .s_addr = INADDR_ANY }
		};

		bind(listen_fd, (sockaddr*)&local, sizeof(local));
		listen(listen_fd, 10);

		if (remote_ip) {
			fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

			sockaddr_in connection = {
				.sin_family = AF_INET,
				.sin_port = htons(port)
			};
			inet_pton(AF_INET, remote_ip, &connection.sin_addr);

			connect(fd, (sockaddr*)&connection, sizeof(connection));
		} else {
			fd = accept(listen_fd, nullptr, nullptr);
		}

		close(listen_fd);
	}

	void send(const std::string& msg) {
		::send(fd, msg.data(), msg.size(), 0);
	}

	int receive(char* buf, int size) {
		return recv(fd, buf, size, 0);
	}

	~Connection() {
		close(fd);
	}
};
