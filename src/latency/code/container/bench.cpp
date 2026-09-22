#include <cstdio>
#include <cstdint>
#include <cmath>
#include <vector>
#include <unordered_set>
#include <set>
#include <list>
#include <algorithm>
#include <random>
#include <x86intrin.h>
#include <sched.h>

static std::vector<std::pair<void*,size_t>> g_log;
static bool g_tracking = false;

template <typename T>
struct TrackAlloc {
	using value_type = T;
	TrackAlloc() noexcept = default;
	template <typename U> TrackAlloc(const TrackAlloc<U>&) noexcept {}
	T* allocate(std::size_t n) {
		T* p = static_cast<T*>(::operator new(n * sizeof(T)));
		if (g_tracking) g_log.emplace_back(p, n * sizeof(T));
		return p;
	}
	void deallocate(T* p, std::size_t) noexcept { ::operator delete(p); }
	template <typename U> bool operator==(const TrackAlloc<U>&) const noexcept { return true; }
	template <typename U> bool operator!=(const TrackAlloc<U>&) const noexcept { return false; }
};

static inline uint64_t timestamp(void) {
	unsigned lo, hi, aux;
	_mm_mfence();
	asm volatile("rdtscp" : "=a"(lo), "=d"(hi), "=c"(aux) :: "memory");
	return ((uint64_t)hi << 32) | lo;
}

static void flush_log(void) {
	for (auto& [p, sz] : g_log) {
		char* c = (char*)p;
		for (size_t off = 0; off < sz; off += 64) _mm_clflush(c + off);
	}
	_mm_mfence();
}

using Vec = std::vector<int, TrackAlloc<int>>;
using Set = std::unordered_set<int, std::hash<int>, std::equal_to<int>, TrackAlloc<int>>;
using Tree = std::set<int, std::less<int>, TrackAlloc<int>>;
using List = std::list<int, TrackAlloc<int>>;

const int TRIALS = 101;

template <typename Cont, typename Build, typename Query>
void bench(const char* name, long n, std::mt19937_64& rng, Build build, Query query, FILE* out) {
	g_log.clear();
	g_tracking = true;
	Cont cont = build(n, rng);
	g_tracking = false;

	std::uniform_int_distribution<long> pick(0, n - 1);
	std::vector<long> targets(TRIALS);
	for (auto& t : targets) t = pick(rng);

	for (int trial = 0; trial < TRIALS; trial++) {
		long target = targets[trial];
		flush_log();
		uint64_t t0 = timestamp();
		bool found = query(cont, target);
		uint64_t t1 = timestamp();
		asm volatile("" :: "r"(found) : "memory");
		fprintf(out, "%s,%ld,%lu\n", name, n, t1 - t0);
	}
}

static std::vector<int> shuffled_range(long n, std::mt19937_64& rng) {
	std::vector<int> vals(n);
	for (long i = 0; i < n; i++) vals[i] = (int)i;
	std::shuffle(vals.begin(), vals.end(), rng);
	return vals;
}

int main() {
	cpu_set_t cpuset;
	CPU_ZERO(&cpuset);
	CPU_SET(2, &cpuset);
	sched_setaffinity(0, sizeof(cpuset), &cpuset);

	std::mt19937_64 rng(12345);

	std::vector<long> sizes;
	for (double p = 4; p <= 20.001; p += 0.5) sizes.push_back(std::lround(std::pow(2.0, p)));

	FILE* out = fopen("container_latency.csv", "w");
	fprintf(out, "container,n,cycles\n");

	for (long n : sizes) {
		bench<Vec>("vector", n, rng,
			[](long n, std::mt19937_64& rng) {
				Vec v; v.reserve(n);
				for (int x : shuffled_range(n, rng)) v.push_back(x);
				return v;
			},
			[](const Vec& v, long target) {
				return std::find(v.begin(), v.end(), (int)target) != v.end();
			}, out);

		bench<Set>("unordered_set", n, rng,
			[](long n, std::mt19937_64& rng) {
				Set s; s.reserve(n);
				for (int x : shuffled_range(n, rng)) s.insert(x);
				return s;
			},
			[](const Set& s, long target) {
				return s.find((int)target) != s.end();
			}, out);

		bench<Tree>("set", n, rng,
			[](long n, std::mt19937_64& rng) {
				Tree t;
				for (int x : shuffled_range(n, rng)) t.insert(x);
				return t;
			},
			[](const Tree& t, long target) {
				return t.find((int)target) != t.end();
			}, out);

		bench<List>("list", n, rng,
			[](long n, std::mt19937_64& rng) {
				List l;
				for (int x : shuffled_range(n, rng)) l.push_back(x);
				return l;
			},
			[](const List& l, long target) {
				return std::find(l.begin(), l.end(), (int)target) != l.end();
			}, out);

		fprintf(stderr, "n=%ld done\n", n);
	}

	fclose(out);
}
