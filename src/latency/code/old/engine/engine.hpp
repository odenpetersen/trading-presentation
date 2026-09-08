#pragma once
// Two-stage pipeline from spec.md, extended for real TCP fan-in/fan-out on
// a single port:
//
//   per-connection reader thread (one per socket)
//        |  hash(sender) % N   -- keeps one participant's own messages
//        v                        funnelled through a single worker, so
//   input queue[0..N)             their relative order survives validation
//        |
//   validation worker i: sender exists (tiny cache -> disk)?  --no--> drop
//        | yes
//        v
//   processing queue (single, shared)
//        |
//        v
//   matching thread (single): owns the book, order ids, seq numbers;
//   writes a private ACK/FILL back to the sender's own socket, and
//   broadcasts the public SEQ line to every connected socket.
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <condition_variable>
#include <cstring>
#include <deque>
#include <filesystem>
#include <functional>
#include <iostream>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "order_book.hpp"
#include "protocol.hpp"
#include "user_store.hpp"

template <class T>
class Queue {
public:
    void push(T v) {
        {
            std::lock_guard<std::mutex> lk(m_);
            q_.push_back(std::move(v));
        }
        cv_.notify_one();
    }
    T pop() {
        std::unique_lock<std::mutex> lk(m_);
        cv_.wait(lk, [&] { return !q_.empty(); });
        T v = std::move(q_.front());
        q_.pop_front();
        return v;
    }

private:
    std::deque<T> q_;
    std::mutex m_;
    std::condition_variable cv_;
};

class Engine {
public:
    Engine(int n_workers, std::filesystem::path users_dir, size_t cache_capacity, bool smp, bool verbose)
        : n_workers_(n_workers), book_(smp), in_(n_workers), verbose_(verbose) {
        for (int i = 0; i < n_workers_; ++i) users_.emplace_back(users_dir, cache_capacity);
    }

    void run(int port) {
        int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
        int yes = 1;
        setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        bind(listen_fd, (sockaddr*)&addr, sizeof(addr));
        listen(listen_fd, 64);
        std::cout << "engine listening on port " << port << " (book footprint "
                  << (NUM_TICKS * sizeof(Level)) / 1024 << " KB, " << n_workers_ << " validation workers)\n"
                  << std::flush;

        for (int i = 0; i < n_workers_; ++i) std::thread([this, i] { validate_loop(i); }).detach();
        std::thread([this] { match_loop(); }).detach();

        while (true) {
            int fd = accept(listen_fd, nullptr, nullptr);
            if (fd < 0) continue;
            {
                std::lock_guard<std::mutex> lk(fds_mtx_);
                fds_.insert(fd);
            }
            std::thread([this, fd] { read_loop(fd); }).detach();
        }
    }

private:
    int n_workers_;
    std::vector<UserStore> users_;  // one per worker, own cache each -- see user_store.hpp
    OrderBook book_;
    std::vector<Queue<Msg>> in_;
    Queue<Msg> processing_;
    uint64_t next_order_id_ = 0;
    bool verbose_;
    std::mutex log_mtx_;

    std::mutex fds_mtx_;
    std::unordered_set<int> fds_;
    std::unordered_map<uint32_t, int> sender_fd_;

    void read_loop(int fd) {
        std::string buf;
        char chunk[4096];
        while (true) {
            ssize_t n = recv(fd, chunk, sizeof(chunk), 0);
            if (n <= 0) break;
            buf.append(chunk, n);
            size_t pos;
            while ((pos = buf.find('\n')) != std::string::npos) {
                std::string line = buf.substr(0, pos);
                buf.erase(0, pos + 1);
                if (auto m = parse_line(line)) {
                    {
                        std::lock_guard<std::mutex> lk(fds_mtx_);
                        sender_fd_[m->sender] = fd;
                    }
                    in_[std::hash<uint32_t>{}(m->sender) % n_workers_].push(*m);
                }
            }
        }
        std::lock_guard<std::mutex> lk(fds_mtx_);
        fds_.erase(fd);
        close(fd);
    }

    void validate_loop(int i) {
        while (true) {
            Msg m = in_[i].pop();
            auto r = users_[i].check(m.sender);
            if (verbose_) {
                std::lock_guard<std::mutex> lk(log_mtx_);
                std::cout << "worker " << i << " sender " << m.sender << (r.cache_hit ? " HIT  " : " MISS ")
                          << r.cycles << " cyc\n"
                          << std::flush;
            }
            if (r.exists) processing_.push(m);
        }
    }

    void send_line(int fd, const std::string& line) {
        std::string s = line + "\n";
        send(fd, s.data(), s.size(), MSG_NOSIGNAL);
    }

    void match_loop() {
        auto priv = [this](uint32_t sender, const std::string& line) {
            int fd;
            {
                std::lock_guard<std::mutex> lk(fds_mtx_);
                auto it = sender_fd_.find(sender);
                if (it == sender_fd_.end()) return;
                fd = it->second;
            }
            send_line(fd, line);
        };
        auto pub = [this](const std::string& line) {
            std::lock_guard<std::mutex> lk(fds_mtx_);
            for (int fd : fds_) send_line(fd, line);
        };
        while (true) {
            Msg m = processing_.pop();
            uint64_t id = m.type == Msg::CANCEL ? 0 : ++next_order_id_;
            book_.apply(m, id, priv, pub);
        }
    }
};
