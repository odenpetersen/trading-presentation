CXX = clang++
CXXFLAGS = --target=x86_64-linux-gnu -O2
MCPU ?= skylake

all: basic.s

basic.s: basic.cpp
	$(CXX) $(CXXFLAGS) basic.cpp -S -o $@

mca: basic.s
	llvm-mca -mcpu=$(MCPU) basic.s

clean:
	rm -f basic.s

.PHONY: all mca clean
