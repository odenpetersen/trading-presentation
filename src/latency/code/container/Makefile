CXX = g++
CXXFLAGS = -O2 -march=native -std=c++17

all: bench

bench: bench.cpp
	$(CXX) $(CXXFLAGS) bench.cpp -o bench

run: bench
	./bench

container_latency.csv: bench
	./bench

plot: container_latency.csv
	python3 plot.py

clean:
	rm -f bench container_latency.csv container_latency.png

.PHONY: all run plot clean
