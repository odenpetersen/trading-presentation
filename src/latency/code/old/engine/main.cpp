// ./engine [N] [roster_file] [--smp] [--cache N] [--verbose]
//   N            validation worker threads (default 1)
//   roster_file  one known sender id per line (default roster.txt)
//   --smp        enable self-match prevention (default off -> wash trades happen)
//   --cache N    per-worker "does this user exist" cache capacity (default 1)
//   --verbose    log each validation as a cache HIT/MISS with its cost
#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>

#include "engine.hpp"

static const int PORT = 7000;

int main(int argc, char** argv) {
    int n_workers = 1;
    bool smp = false;
    bool verbose = false;
    size_t cache_capacity = 1;
    std::string roster_path = "roster.txt";

    std::vector<std::string> positional;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--smp")
            smp = true;
        else if (a == "--verbose")
            verbose = true;
        else if (a == "--cache" && i + 1 < argc)
            cache_capacity = std::stoul(argv[++i]);
        else
            positional.push_back(a);
    }
    if (positional.size() >= 1) n_workers = std::stoi(positional[0]);
    if (positional.size() >= 2) roster_path = positional[1];

    // roster.txt is the human-editable list; engine/users/<id> is the
    // on-disk "ground truth" each validation cache miss actually reads.
    std::filesystem::path users_dir = "users";
    std::filesystem::remove_all(users_dir);
    std::filesystem::create_directory(users_dir);
    size_t n_users = 0;
    std::ifstream f(roster_path);
    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;
        std::ofstream(users_dir / line).close();
        ++n_users;
    }
    std::cout << "loaded " << n_users << " known senders from " << roster_path << " into " << users_dir
              << ", per-worker cache=" << cache_capacity << ", smp=" << (smp ? "on" : "off") << "\n"
              << std::flush;

    Engine engine(n_workers, users_dir, cache_capacity, smp, verbose);
    engine.run(PORT);
}
