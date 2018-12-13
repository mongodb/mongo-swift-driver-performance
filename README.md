# Driver performance tests for MongoSwift

This is a Swift implementation of the MongoDB standard driver performance [benchmark suite](https://github.com/mongodb/specifications/blob/master/source/benchmarking/benchmarking.rst). The implementation works in Swift 4.0+.

The benchmarks can be run from the command line or XCode. 

**Command line**: Simply run `make` in the base directory. This will run every benchmark and pipe the output to a python script, which parses and prints the output in a more readable dictionary form. You can also use the `FILTER` environment variable to run a subset of benchmarks: for example, `make FILTER=testDeepDecoding`.

**XCode**: First generate the `.xcodeproj` folder by running `make project` from the command line. Then open `MongoSwift-Performance.xcodeproj` and run tests as usual. 

Please note that each benchmark test runs for a minimum of 1 minute and therefore **the entire benchmark suite will take around 20-30 minutes to complete**.
