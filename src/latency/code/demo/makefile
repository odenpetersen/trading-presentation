CXX = g++
CXXFLAGS = -std=c++20 -Wall -Wextra

ENGINE_OBJS = main.o MatchingEngine.o Connection.o Listener.o OrderBook.o FIFO.o
CLIENT_OBJS = main_client.o Client.o Connection.o
GATEWAY_OBJS = main_gateway.o Gateway.o Connection.o Listener.o
STRATEGY_OBJS = main_strategy.o Strategy.o Connection.o Listener.o

all: a.out client.out gateway.out strategy.out

a.out: $(ENGINE_OBJS)
	$(CXX) $(CXXFLAGS) -o a.out $(ENGINE_OBJS)

client.out: $(CLIENT_OBJS)
	$(CXX) $(CXXFLAGS) -o client.out $(CLIENT_OBJS)

gateway.out: $(GATEWAY_OBJS)
	$(CXX) $(CXXFLAGS) -o gateway.out $(GATEWAY_OBJS)

strategy.out: $(STRATEGY_OBJS)
	$(CXX) $(CXXFLAGS) -o strategy.out $(STRATEGY_OBJS)

main.o: main.cpp MatchingEngine.h
	$(CXX) $(CXXFLAGS) -c main.cpp

main_client.o: main_client.cpp Client.h Protocol.h
	$(CXX) $(CXXFLAGS) -c main_client.cpp

main_gateway.o: main_gateway.cpp Gateway.h
	$(CXX) $(CXXFLAGS) -c main_gateway.cpp

main_strategy.o: main_strategy.cpp Strategy.h
	$(CXX) $(CXXFLAGS) -c main_strategy.cpp

MatchingEngine.o: MatchingEngine.cpp MatchingEngine.h Connection.h Listener.h OrderBook.h Protocol.h
	$(CXX) $(CXXFLAGS) -c MatchingEngine.cpp

Gateway.o: Gateway.cpp Gateway.h Connection.h Listener.h Protocol.h
	$(CXX) $(CXXFLAGS) -c Gateway.cpp

Strategy.o: Strategy.cpp Strategy.h Connection.h Listener.h Protocol.h
	$(CXX) $(CXXFLAGS) -c Strategy.cpp

Connection.o: Connection.cpp Connection.h
	$(CXX) $(CXXFLAGS) -c Connection.cpp

Listener.o: Listener.cpp Listener.h Connection.h
	$(CXX) $(CXXFLAGS) -c Listener.cpp

OrderBook.o: OrderBook.cpp OrderBook.h FIFO.h
	$(CXX) $(CXXFLAGS) -c OrderBook.cpp

FIFO.o: FIFO.cpp FIFO.h
	$(CXX) $(CXXFLAGS) -c FIFO.cpp

Client.o: Client.cpp Client.h Connection.h Protocol.h
	$(CXX) $(CXXFLAGS) -c Client.cpp

clean:
	rm -f a.out client.out gateway.out strategy.out *.o
