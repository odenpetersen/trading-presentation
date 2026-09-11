#pragma once

#include <cstddef>

class Connection {
        int fd;

        public:
        Connection(int port, const char* remote_ip = nullptr);

        void send(const void* data, size_t size);

        int receive(char* buf, int size);
        bool receive_exact(void* buf, size_t size);

        ~Connection();
};
