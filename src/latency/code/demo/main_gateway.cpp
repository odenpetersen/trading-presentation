// usage: gateway.out [strategy_port] [control_port] [me_host] [me_order_entry_port] [auth_cache_ttl_ms]
#include <cstdlib>

#include "Gateway.h"

int main(int argc, char** argv) {
	int strategy_port = argc > 1 ? std::atoi(argv[1]) : 18000;
	int control_port = argc > 2 ? std::atoi(argv[2]) : 18001;
	const char* me_host = argc > 3 ? argv[3] : "127.0.0.1";
	int me_order_entry_port = argc > 4 ? std::atoi(argv[4]) : 17000;
	uint64_t ttl_ms = argc > 5 ? std::strtoull(argv[5], nullptr, 10) : 1000;

	GatewayConfig config{
		.strategy_port = strategy_port,
		.control_port = control_port,
		.me_host = me_host,
		.me_order_entry_port = me_order_entry_port,
		.auth_cache_ttl_ms = ttl_ms,
	};

	Gateway gateway(config);
	gateway.run();
}
