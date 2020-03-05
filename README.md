# Driver performance tests for the MongoDB Swift Driver

This is a Swift implementation of the MongoDB standard driver performance [benchmark suite](https://github.com/mongodb/specifications/blob/master/source/benchmarking/benchmarking.rst). This implementation works in Swift 5.1.

The benchmarks should be run via the command line in release mode for optimal results: `swift run -c release`.

Please note that each benchmark test runs for a minimum of 1 minute and therefore **the entire benchmark suite will take around 20-30 minutes to complete**.
