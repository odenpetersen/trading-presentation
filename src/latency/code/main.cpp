#include "MatchingEngine.h"

static const int PORT = 7000;
static const size_t BOOK_CAPACITY = 1 << 20;

int main() {
	MatchingEngine engine(PORT, BOOK_CAPACITY);
	engine.run();
}
