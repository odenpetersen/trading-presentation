#include <cstdlib>
#include <iostream>
#include <list>
#include <new>
#include <vector>


// -----------------------------------------------------------------------------
// Deliberately fragmented allocator
// -----------------------------------------------------------------------------

struct Fragmentation {
    static inline std::vector<void*> junk;

    static void clear() {
        for (void* p : junk)
            std::free(p);

        junk.clear();
    }
};

template<class T>
struct FragmentingAllocator {
    using value_type = T;

    FragmentingAllocator() noexcept = default;

    template<class U>
    FragmentingAllocator(const FragmentingAllocator<U>&) noexcept {}

    T* allocate(std::size_t n) {
        const std::size_t bytes = n * sizeof(T);

        // Keep a junk allocation alive between every real allocation.
        void* hole = std::malloc(bytes + 64);
        if (!hole)
            throw std::bad_alloc();

        Fragmentation::junk.push_back(hole);

        void* p = std::malloc(bytes);
        if (!p)
            throw std::bad_alloc();

        return static_cast<T*>(p);
    }

    void deallocate(T* p, std::size_t) noexcept {
        std::free(p);
    }

    template<class U>
    bool operator==(const FragmentingAllocator<U>&) const noexcept {
        return true;
    }

    template<class U>
    bool operator!=(const FragmentingAllocator<U>&) const noexcept {
        return false;
    }
};


// -----------------------------------------------------------------------------
// List matrices
// -----------------------------------------------------------------------------

template<class Alloc>
using ListRow = std::list<double, Alloc>;

template<class Alloc>
using ListMatrix = std::list<ListRow<Alloc>>;


template<class Alloc>
ListMatrix<Alloc> make_list_matrix(int N, double value) {
    ListMatrix<Alloc> matrix;

    for (int i = 0; i < N; ++i)
        matrix.emplace_back(N, value);

    return matrix;
}


template<class Alloc>
void matmul_list(
    const ListMatrix<Alloc>& A,
    const ListMatrix<Alloc>& B,
    ListMatrix<Alloc>& C,
    int N)
{
    auto ai = A.begin();
    auto ci = C.begin();

    for (int i = 0; i < N; ++i, ++ai, ++ci) {

        auto a = ai->begin();
        auto bk = B.begin();

        for (int k = 0; k < N; ++k, ++a, ++bk) {

            const double a_ik = *a;

            auto b = bk->begin();
            auto c = ci->begin();

            for (int j = 0; j < N; ++j, ++b, ++c)
                *c += a_ik * *b;
        }
    }
}


// -----------------------------------------------------------------------------
// Vector matrices
// -----------------------------------------------------------------------------

void matmul_vector_bad(
    const std::vector<double>& A,
    const std::vector<double>& B,
    std::vector<double>& C,
    int N)
{
    for (int i = 0; i < N; ++i)
        for (int j = 0; j < N; ++j)
            for (int k = 0; k < N; ++k)
                C[i * N + j] +=
                    A[i * N + k] * B[k * N + j];
}


void matmul_vector_good(
    const std::vector<double>& A,
    const std::vector<double>& B,
    std::vector<double>& C,
    int N)
{
    for (int i = 0; i < N; ++i)
        for (int k = 0; k < N; ++k) {

            const double a_ik = A[i * N + k];

            for (int j = 0; j < N; ++j)
                C[i * N + j] +=
                    a_ik * B[k * N + j];
        }
}


// -----------------------------------------------------------------------------
// Versions 1 and 2: list
// -----------------------------------------------------------------------------

template<class Alloc>
double run_list(int N, int repetitions) {
    auto A = make_list_matrix<Alloc>(N, 1.0);
    auto B = make_list_matrix<Alloc>(N, 1.0);
    auto C = make_list_matrix<Alloc>(N, 0.0);

    for (int r = 0; r < repetitions; ++r) {
        for (auto& row : C)
            for (auto& x : row)
                x = 0.0;

        matmul_list(A, B, C, N);
    }

    double checksum = C.front().front();

    return checksum;
}


// -----------------------------------------------------------------------------
// Versions 3, 4 and 5: vector
// -----------------------------------------------------------------------------

double run_vector(int N, int repetitions, bool reserve, bool good_loops) {
    const std::size_t size = static_cast<std::size_t>(N) * N;

    std::vector<double> A;
    std::vector<double> B;
    std::vector<double> C;

    if (reserve) {
        A.reserve(size);
        B.reserve(size);
        C.reserve(size);
    }

    // push_back deliberately makes version 3 grow repeatedly.
    for (std::size_t i = 0; i < size; ++i) {
        A.push_back(1.0);
        B.push_back(1.0);
        C.push_back(0.0);
    }

    for (int r = 0; r < repetitions; ++r) {
        std::fill(C.begin(), C.end(), 0.0);

        if (good_loops)
            matmul_vector_good(A, B, C, N);
        else
            matmul_vector_bad(A, B, C, N);
    }

    return C[0];
}


// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------

#ifndef VERSION
#error "Compile with -DVERSION=1, 2, 3, 4, or 5"
#endif


int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0]
                  << " N [repetitions]\n";
        return 1;
    }

    const int N = std::atoi(argv[1]);
    const int repetitions = argc >= 3 ? std::atoi(argv[2]) : 1;

    if (N <= 0 || repetitions < 0) {
        std::cerr << "Invalid N or repetitions\n";
        return 1;
    }

    double checksum = 0.0;

#if VERSION == 1

    checksum = run_list<FragmentingAllocator<double>>(
        N, repetitions
    );

    Fragmentation::clear();

#elif VERSION == 2

    checksum = run_list<std::allocator<double>>(
        N, repetitions
    );

#elif VERSION == 3

    checksum = run_vector(
        N, repetitions,
        false,  // no reserve
        false   // bad loop order
    );

#elif VERSION == 4

    checksum = run_vector(
        N, repetitions,
        true,   // reserve
        false   // bad loop order
    );

#elif VERSION == 5

    checksum = run_vector(
        N, repetitions,
        true,   // reserve
        true    // good loop order
    );

#else

#error "VERSION must be 1, 2, 3, 4, or 5"

#endif

    // Make the computation observable so the compiler cannot discard it.
    std::cout << checksum << '\n';

    return 0;
}
