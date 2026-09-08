CXX = g++
CXXFLAGS = -O2 -std=c++17 -Wall -pthread

engine: main.cpp engine.hpp order_book.hpp protocol.hpp user_store.hpp
	$(CXX) $(CXXFLAGS) -o engine main.cpp

clean:
	rm -f engine
