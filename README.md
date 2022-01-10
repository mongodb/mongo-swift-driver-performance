# Driver performance tests for the MongoDB Swift Driver

This is a Swift implementation of the MongoDB standard driver performance [benchmark suite](https://github.com/mongodb/specifications/blob/master/source/benchmarking/benchmarking.rst).

The following executable targets are available:
* `BSON`: BSON benchmarks (requires Swift 5.1+)
* `IO`: I/O-performing benchmarks using the driver's synchronous and `EventLoopFuture`-based API (requires Swift 5.1+)
* `AsyncAwaitIO`: I/O-performing benchmarks using the driver's `async` API (requires Swift 5.5+)

A target should be run in release mode for optimal results: `swift run -c release TargetName`

Please note that each benchmark test runs for anywhere from 1 to 5 minutes and therefore **the entire benchmark suite will take around 20-30 minutes to complete**.
