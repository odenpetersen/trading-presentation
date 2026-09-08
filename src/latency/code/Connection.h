#pragma once

#include <string>

class Connection {
        int fd; 

        public:
        Connection(int port, const char* remote_ip = nullptr);

        void send(const std::string& msg);

        int receive(char* buf, int size);

        ~Connection();
};
