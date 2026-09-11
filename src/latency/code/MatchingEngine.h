#include "Connection.h"
#include "OrderBook.h"

class MatchingEngine {
	Connection conn;
	OrderBook book;
	public:
	MatchingEngine(int port, size_t capacity);
	void run();
};
