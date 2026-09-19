// usage: strategy.out [control_port] [taker_participant] [maker_participant] [me_host] [me_md_port] [gw_a_host] [gw_a_port] [gw_b_host] [gw_b_port]
#include <cstdlib>

#include "Strategy.h"

int main(int argc, char** argv) {
	int control_port = argc > 1 ? std::atoi(argv[1]) : 19000;
	ParticipantID taker = argc > 2 ? std::strtoul(argv[2], nullptr, 10) : 100;
	ParticipantID maker = argc > 3 ? std::strtoul(argv[3], nullptr, 10) : 101;
	const char* me_host = argc > 4 ? argv[4] : "127.0.0.1";
	int me_md_port = argc > 5 ? std::atoi(argv[5]) : 17001;
	const char* gw_a_host = argc > 6 ? argv[6] : "127.0.0.1";
	int gw_a_port = argc > 7 ? std::atoi(argv[7]) : 18000;
	const char* gw_b_host = argc > 8 ? argv[8] : "127.0.0.1";
	int gw_b_port = argc > 9 ? std::atoi(argv[9]) : 18010;

	StrategyConfig config{
		.control_port = control_port,
		.me_host = me_host,
		.me_market_data_port = me_md_port,
		.me_feed_in_port = me_md_port + 1,  // ME's ports are order-entry/md/feed-in/control, always consecutive
		.gateway_a_host = gw_a_host,
		.gateway_a_port = gw_a_port,
		.gateway_b_host = gw_b_host,
		.gateway_b_port = gw_b_port,
		.taker_participant = taker,
		.maker_participant = maker,
	};

	Strategy strategy(config);
	strategy.run();
}
