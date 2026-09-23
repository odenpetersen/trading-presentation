CXX = g++
CXXFLAGS = -O2 -march=native -std=c++17

all: bench

bench: bench.cpp
	$(CXX) $(CXXFLAGS) bench.cpp -o bench

run: bench
	./bench

branch_latency.csv: bench
	./bench

plot: branch_latency.csv
	python3 plot.py

clean:
	rm -f bench branch_latency.csv branch_latency.png tsc_ghz.txt

.PHONY: all run plot clean
