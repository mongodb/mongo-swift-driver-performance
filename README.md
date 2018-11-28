# Driver performance tests for MongoSwift

This is a Swift implementation of the MongoDB standard driver performance [benchmark suite](https://github.com/mongodb/specifications/blob/master/source/benchmarking/benchmarking.rst). 

The benchmarks must be run from the command line. Simply run `make` in the base directory. This will run every benchmark and pipe the output to a python script, which parses and prints the output in a more readable dictionary form. 

You can also use the `FILTER` environment variable to run a subset of benchmarks: for example, `make FILTER=testDeepDecoding`.

Please note that each benchmark test runs for a minimum of 1 minute and therefore **the entire benchmark suite will take around 20-30 minutes to complete**.