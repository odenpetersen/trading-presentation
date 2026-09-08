XX = g++
CXXFLAGS = -std=c++20 -Wall -Wextra

a.out: matching_engine.o Connection.o
	$(CXX) $(CXXFLAGS) -o a.out matching_engine.o Connection.o

matching_engine.o: matching_engine.cpp Connection.h
	$(CXX) $(CXXFLAGS) -c matching_engine.cpp

Connection.o: Connection.cpp Connection.h
	$(CXX) $(CXXFLAGS) -c Connection.cpp

clean:
	rm -f a.out *.o
