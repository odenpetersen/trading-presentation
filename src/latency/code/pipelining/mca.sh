clang++ demo.cpp -S -o - | llvm-mca --iterations=50 --timeline --timeline-max-cycles=100 --timeline-max-iterations=50
