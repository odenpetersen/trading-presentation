CC = gcc
CFLAGS = -O2 -march=native

all: cache_latency

cache_latency: cache_latency.c
	$(CC) $(CFLAGS) cache_latency.c -o cache_latency -lm

run: cache_latency
	./cache_latency

cache_latency.csv: cache_latency
	./cache_latency

plot: cache_latency.csv
	python3 plot.py

clean:
	rm -f cache_latency cache_latency.csv cdf.png

.PHONY: all run plot clean
