#include <sys/socket.h>   // socket(), bind(), listen(), connect(), accept(), send(), recv()
#include <netinet/in.h>   // sockaddr_in, INADDR_ANY, IPPROTO_TCP
#include <arpa/inet.h>    // htons(), inet_pton()
#include <unistd.h>       // close()
#include <cstring>        // strlen()
#include <iostream>       // std::cout
#include <string>         // std::string

class Peer {
    int listen_fd;
    int fd;

public:
    Peer(int local_port, const char* peer_ip, int peer_port) {
        listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

        sockaddr_in local{};
        local.sin_family = AF_INET;
        local.sin_port = htons(local_port);
        local.sin_addr.s_addr = INADDR_ANY;

        bind(listen_fd, (sockaddr*)&local, sizeof(local));
        listen(listen_fd, 10);

        if (peer_ip) {
            fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

            sockaddr_in peer{};
            peer.sin_family = AF_INET;
            peer.sin_port = htons(peer_port);
            inet_pton(AF_INET, peer_ip, &peer.sin_addr);

            connect(fd, (sockaddr*)&peer, sizeof(peer));
        } else {
            fd = accept(listen_fd, nullptr, nullptr);
        }
    }

    void send(const char* msg) {
        ::send(fd, msg, strlen(msg), 0);
    }

    int receive(char* buf, int size) {
        return recv(fd, buf, size, 0);
    }

    ~Peer() {
        close(fd);
        close(listen_fd);
    }
};

int main(int argc, char** argv) {
    Peer peer(9000, argc > 1 ? argv[1] : nullptr);

    char buf[1024];

    while (true) {
        int n = peer.receive(buf, sizeof(buf));

        if (n <= 0)
            break;

        std::cout.write(buf, n);
        std::cout.flush();
    }
}
