#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>
#include <algorithm>
#include <random>
#include <x86intrin.h>
#include <sched.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <linux/perf_event.h>

static inline uint64_t timestamp_start(void) {
	unsigned lo, hi;
	_mm_lfence();
	asm volatile("rdtsc" : "=a"(lo), "=d"(hi) :: "memory");
	return ((uint64_t)hi << 32) | lo;
}

static inline uint64_t timestamp_end(void) {
	unsigned lo, hi, aux;
	asm volatile("rdtscp" : "=a"(lo), "=d"(hi), "=c"(aux) :: "memory");
	_mm_lfence();
	return ((uint64_t)hi << 32) | lo;
}

static double calibrate_tsc_ghz(void) {
	struct timespec t0, t1;
	clock_gettime(CLOCK_MONOTONIC, &t0);
	uint64_t c0 = timestamp_start();
	do { clock_gettime(CLOCK_MONOTONIC, &t1); }
	while ((t1.tv_sec - t0.tv_sec) * 1000000000L + (t1.tv_nsec - t0.tv_nsec) < 200000000L);
	uint64_t c1 = timestamp_end();
	double ns = (t1.tv_sec - t0.tv_sec) * 1e9 + (t1.tv_nsec - t0.tv_nsec);
	return (double)(c1 - c0) / ns;
}

static int open_branch_misses(void) {
	perf_event_attr a;
	memset(&a, 0, sizeof(a));
	a.size = sizeof(a);
	a.type = PERF_TYPE_HARDWARE;
	a.config = PERF_COUNT_HW_BRANCH_MISSES;
	a.exclude_kernel = 1;
	a.exclude_hv = 1;
	return (int)syscall(SYS_perf_event_open, &a, 0, -1, -1, 0);
}

static inline uint64_t read_ctr(int fd) {
	uint64_t v = 0;
	if (fd >= 0 && read(fd, &v, sizeof(v)) != sizeof(v)) v = 0;
	return v;
}

__attribute__((noinline)) uint64_t branchy(const uint8_t* d, long n) {
	uint64_t s = 0;
	for (long i = 0; i < n; i++) {
		if (d[i]) { asm volatile(""); s += i; }
		else s ^= i;
	}
	return s;
}

__attribute__((noinline)) uint64_t branchless(const uint8_t* d, long n) {
	uint64_t s = 0;
	for (long i = 0; i < n; i++) {
		uint64_t m = -(uint64_t)d[i];
		s = ((s + i) & m) | ((s ^ i) & ~m);
		asm volatile("" : "+r"(s));
	}
	return s;
}

const long N = 1 << 16;
const int TRIALS = 31;

template <typename F>
void bench(const char* name, double x, const std::vector<uint8_t>& d, F f, int fd, FILE* out) {
	f(d.data(), N);
	for (int trial = 0; trial < TRIALS; trial++) {
		uint64_t m0 = read_ctr(fd);
		uint64_t t0 = timestamp_start();
		uint64_t s = f(d.data(), N);
		uint64_t t1 = timestamp_end();
		uint64_t m1 = read_ctr(fd);
		asm volatile("" :: "r"(s) : "memory");
		fprintf(out, "%s,%.1f,%.4f,%.5f\n", name, x, (double)(t1 - t0) / N, (double)(m1 - m0) / N);
	}
}

int main() {
	cpu_set_t cpuset;
	CPU_ZERO(&cpuset);
	CPU_SET(2, &cpuset);
	sched_setaffinity(0, sizeof(cpuset), &cpuset);

	double tsc_ghz = calibrate_tsc_ghz();
	FILE* gf = fopen("tsc_ghz.txt", "w");
	fprintf(gf, "%.6f\n", tsc_ghz);
	fclose(gf);
	fprintf(stderr, "tsc: %.4f GHz\n", tsc_ghz);

	int fd = open_branch_misses();
	if (fd < 0) fprintf(stderr, "perf_event_open failed, branch misses will read 0\n");
	else ioctl(fd, PERF_EVENT_IOC_ENABLE, 0);

	std::mt19937_64 rng(12345);
	std::vector<uint8_t> d(N);

	for (int i = 0; i < 2000; i++) asm volatile("" :: "r"(branchless(d.data(), N)));

	FILE* out = fopen("branch_latency.csv", "w");
	fprintf(out, "variant,x,cycles_per_iter,misses_per_iter\n");

	for (int k = 0; k <= 100; k += 2) {
		double x = k;
		std::bernoulli_distribution taken(x / 100.0);
		for (auto& b : d) b = taken(rng);
		bench("random", x, d, branchy, fd, out);
		bench("branchless", x, d, branchless, fd, out);
		std::sort(d.begin(), d.end());
		bench("sorted", x, d, branchy, fd, out);
		fprintf(stderr, "x=%.0f%% done\n", x);
	}

	fclose(out);
}
