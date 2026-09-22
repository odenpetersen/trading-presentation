CXX = g++
CXXFLAGS = -O0 -march=native -fno-omit-frame-pointer -fno-inline -std=c++20

VERSIONS = 1 2 3 4 5
TARGETS = $(addprefix matmul,$(VERSIONS))

.PHONY: all run flamegraph clean

all: $(TARGETS)


matmul1: matmul.cpp
	$(CXX) $(CXXFLAGS) -DVERSION=1 $< -o $@

matmul2: matmul.cpp
	$(CXX) $(CXXFLAGS) -DVERSION=2 $< -o $@

matmul3: matmul.cpp
	$(CXX) $(CXXFLAGS) -DVERSION=3 $< -o $@

matmul4: matmul.cpp
	$(CXX) $(CXXFLAGS) -DVERSION=4 $< -o $@

matmul5: matmul.cpp
	$(CXX) $(CXXFLAGS) -DVERSION=5 $< -o $@


run: all
	python3 run.py


flamegraph: all
	python3 run.py --flamegraph


clean:
	rm -f $(TARGETS)
	rm -f results.csv
	rm -f time.png
	rm -f cycles.png
	rm -f cache_misses.png
	rm -f perf*.data
	rm -f flamegraph*.html
