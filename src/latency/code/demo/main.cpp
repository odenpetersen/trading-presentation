#include "MatchingEngine.h"

static const int ORDER_ENTRY_PORT = 17000;
static const int MARKET_DATA_PORT = 17001;
static const int FEED_IN_PORT = 17002;
static const int CONTROL_PORT = 17003;
static const size_t BOOK_CAPACITY = 1 << 20;

int main() {
	MatchingEngineConfig config{
		.order_entry_port = ORDER_ENTRY_PORT,
		.market_data_port = MARKET_DATA_PORT,
		.feed_in_port = FEED_IN_PORT,
		.control_port = CONTROL_PORT,
		.book_capacity = BOOK_CAPACITY,
	};

	MatchingEngine engine(config);
	engine.run();
}
