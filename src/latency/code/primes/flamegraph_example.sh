perf record -F 999 --call-graph dwarf -- python3 prime.py
perf script report flamegraph > flamegraph.html
