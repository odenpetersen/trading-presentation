#include <sys/socket.h>   // socket(), bind(), listen(), connect(), accept(), send(), recv()
#include <netinet/in.h>   // sockaddr_in, INADDR_ANY, IPPROTO_TCP
#include <arpa/inet.h>    // htons(), inet_pton()
#include <unistd.h>       // close()
#include <thread>         // std::thread
#include <iostream>       // std::cin, std::cout
#include <string>         // std::string

class Peer {
    int fd;

public:
    Peer(int port, const char* peer_ip) {
        int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

        sockaddr_in local{};
        local.sin_family = AF_INET;
        local.sin_port = htons(port);
        local.sin_addr.s_addr = INADDR_ANY;

        bind(listen_fd, (sockaddr*)&local, sizeof(local));
        listen(listen_fd, 10);

        if (peer_ip) {
            fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

            sockaddr_in peer{};
            peer.sin_family = AF_INET;
            peer.sin_port = htons(port);
            inet_pton(AF_INET, peer_ip, &peer.sin_addr);

            connect(fd, (sockaddr*)&peer, sizeof(peer));
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

    ~Peer() {
        close(fd);
    }
};

int main(int argc, char** argv) {
    Peer peer(9000, argc > 1 ? argv[1] : nullptr);

    std::thread receiver([&] {
        char buf[1024];

        while (true) {
            int n = peer.receive(buf, sizeof(buf));
            if (n <= 0) break;

            std::cout.write(buf, n);
            std::cout.flush();
        }
    });

    std::string msg;
    while (std::getline(std::cin, msg))
        peer.send(msg);

    receiver.join();
}
