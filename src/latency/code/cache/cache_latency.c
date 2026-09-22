#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <time.h>
#include <x86intrin.h>

#define HEAP_BYTES (128L*1024*1024)
#define LINE 64
#define SAMPLES 300000

static inline uint64_t timestamp(void) {
	unsigned lo, hi, aux;
	_mm_mfence();
	asm volatile("rdtscp" : "=a"(lo), "=d"(hi), "=c"(aux) :: "memory");
	return ((uint64_t)hi << 32) | lo;
}

static long log_uniform(long lo, long hi) {
	double u = (double)rand() / ((double)RAND_MAX + 1);
	double v = log((double)lo) + u * (log((double)hi) - log((double)lo));
	long d = (long)exp(v);
	return d < lo ? lo : d;
}

static double calibrate_tsc_hz(void) {
	struct timespec ts0, ts1;
	struct timespec sleep_for = {0, 200000000};
	clock_gettime(CLOCK_MONOTONIC, &ts0);
	uint64_t t0 = timestamp();
	nanosleep(&sleep_for, NULL);
	uint64_t t1 = timestamp();
	clock_gettime(CLOCK_MONOTONIC, &ts1);
	double elapsed = (ts1.tv_sec - ts0.tv_sec) + (ts1.tv_nsec - ts0.tv_nsec) / 1e9;
	return (double)(t1 - t0) / elapsed;
}

int main(void) {
	srand(12345);
	double tsc_hz = calibrate_tsc_hz();
	fprintf(stderr, "TSC frequency: %.3f GHz\n", tsc_hz / 1e9);
	long n = HEAP_BYTES / LINE;
	char *heap = aligned_alloc(LINE, n * LINE);
	long *last = malloc(n * sizeof(long));
	long *touched = malloc((n + SAMPLES) * sizeof(long));

	for (long i = 0; i < n; i++) {
		*(volatile long *)(heap + i * LINE) = i;
		last[i] = i;
		touched[i] = i;
	}

	FILE *out = fopen("cache_latency.csv", "w");
	fprintf(out, "reuse_distance,nanoseconds\n");

	for (long s = n; s < n + SAMPLES; s++) {
		long r = log_uniform(1, n);
		long idx = touched[s - r];
		char *addr = heap + idx * LINE;
		uint64_t t0 = timestamp();
		long val = *(volatile long *)addr;
		uint64_t t1 = timestamp();
		long reuse = s - last[idx];
		last[idx] = s;
		touched[s] = idx;
		(void)val;
		double ns = (double)(t1 - t0) / tsc_hz * 1e9;
		fprintf(out, "%ld,%.3f\n", reuse, ns);
	}

	fclose(out);
	free(touched);
	free(last);
	free(heap);
	fprintf(stderr, "done: n=%ld lines, %ld samples\n", n, (long)SAMPLES);
	return 0;
}
