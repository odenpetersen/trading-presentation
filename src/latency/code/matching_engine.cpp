#include <thread>
#include <iostream>
#include "Connection.h"

#include <string>

int main(int argc, char** argv) {
	Connection conn(9000, argc > 1 ? argv[1] : nullptr);

	std::thread receiver([&] {
		char buf[1024];

		while (true) {
			int n = conn.receive(buf, sizeof(buf));
			if (n <= 0) break;

			std::cout.write(buf, n);
			std::cout << std::endl;
			std::cout.flush();
		}
	});

	std::string msg;
	while (std::getline(std::cin, msg))
		conn.send(msg);

	receiver.join();
}
