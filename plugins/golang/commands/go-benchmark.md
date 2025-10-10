Run Go benchmarks and analyze performance metrics.

Execute benchmark tests to measure code performance and identify optimization opportunities. This command will:
- Run all benchmark functions
- Generate performance reports
- Compare results across runs
- Identify performance regressions

Usage:
- `/go-benchmark` - Run all benchmarks
- `/go-benchmark BenchmarkMyFunc` - Run specific benchmark
- `/go-benchmark -mem` - Include memory allocation stats
- `/go-benchmark -cpuprofile` - Generate CPU profile

Benchmark analysis:
- Operations per second
- Nanoseconds per operation
- Memory allocations
- Bytes allocated

Common workflows:
1. Baseline measurement: `/go-benchmark > old.txt`
2. After optimization: `/go-benchmark > new.txt`
3. Compare results: `/go-benchmark -compare old.txt new.txt`
4. Profile hotspots: `/go-benchmark -cpuprofile=cpu.prof`

The command will analyze results and suggest performance improvements.
