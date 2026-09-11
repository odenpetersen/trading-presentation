CXX = g++
CXXFLAGS = -std=c++20 -Wall -Wextra

ENGINE_OBJS = main.o MatchingEngine.o Connection.o OrderBook.o FIFO.o
CLIENT_OBJS = main_client.o Client.o Connection.o

all: a.out client.out

a.out: $(ENGINE_OBJS)
	$(CXX) $(CXXFLAGS) -o a.out $(ENGINE_OBJS)

client.out: $(CLIENT_OBJS)
	$(CXX) $(CXXFLAGS) -o client.out $(CLIENT_OBJS)

main.o: main.cpp MatchingEngine.h
	$(CXX) $(CXXFLAGS) -c main.cpp

main_client.o: main_client.cpp Client.h Protocol.h
	$(CXX) $(CXXFLAGS) -c main_client.cpp

MatchingEngine.o: MatchingEngine.cpp MatchingEngine.h Connection.h OrderBook.h Protocol.h
	$(CXX) $(CXXFLAGS) -c MatchingEngine.cpp

Connection.o: Connection.cpp Connection.h
	$(CXX) $(CXXFLAGS) -c Connection.cpp

OrderBook.o: OrderBook.cpp OrderBook.h FIFO.h
	$(CXX) $(CXXFLAGS) -c OrderBook.cpp

FIFO.o: FIFO.cpp FIFO.h
	$(CXX) $(CXXFLAGS) -c FIFO.cpp

Client.o: Client.cpp Client.h Connection.h Protocol.h
	$(CXX) $(CXXFLAGS) -c Client.cpp

clean:
	rm -f a.out client.out *.o
