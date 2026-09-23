#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <iostream>
#include <string>
#include <thread>

class Connection {
	int fd;

	public:
	Connection(int port, const char* remote_ip = nullptr) {
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

	void send(const void* data, size_t size) {
		auto* p = static_cast<const char*>(data);
		size_t sent = 0;

		while (sent < size) {
			ssize_t n = ::send(fd, p + sent, size - sent, 0);
			if (n <= 0)
				break;
			sent += n;
		}
	}

	int receive(char* buf, int size) {
		return recv(fd, buf, size, 0);
	}

	~Connection() {
		close(fd);
	}
};

int main(int argc, char** argv) {
	Connection conn(9000, argc > 1 ? argv[1] : nullptr);

	std::thread receiver([&] {
		char buf[1024];

		while (true) {
			int n = conn.receive(buf, sizeof(buf));
			if (n <= 0) break;

			std::cout.write(buf, n);
			std::cout.flush();
		}
	});

	std::string msg;
	while (std::getline(std::cin, msg)) {
		msg += '\n';
		conn.send(msg.data(), msg.size());
	}

	receiver.join();
}
