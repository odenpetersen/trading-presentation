perf record -e branch-misses -- "$@"
perf report
