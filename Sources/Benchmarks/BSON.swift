import Foundation
import MongoSwift

let bsonTestFiles = [
    TestFile(name: "flat_bson", size: 75.31),
    TestFile(name: "deep_bson", size: 19.64),
    TestFile(name: "full_bson", size: 57.34)
]

/// Runs a benchmark that tests how long it takes to parse JSON from the provided file into BSON data.
/// This is the "C driver version" of the BSON encoding benchmarks.
/// The caller should specify a number of iterations that satisfies the spec requirements for how long this benchmark
/// should run for.
func runJSONToBSONBenchmark(_ file: TestFile) throws -> Double {
    print("Benchmarking \(file.name.prefix(4)) JSON to BSON")
    let json = file.json
    let results = try measureTask {
        for _ in 1...10000 {
            _ = try BSONDocument(fromJSON: json)
        }
    }
    return calculateAndPrintResults(name: "\(file.name) JSON to BSON", time: results, size: file.size)
}

/// Runs a benchmark that tests how long it takes to convert BSON data corresponding to the JSON in the provided file
/// back to JSON. This is the "C driver version" of the BSON decoding benchmarks.
func runBSONToJSONBenchmark(_ file: TestFile) throws -> Double {
    print("Benchmarking \(file.name.prefix(4)) BSON to JSON")
    let document = try BSONDocument(fromJSON: file.json)
    let results = try measureTask {
        for _ in 1...10000 {
            _ = document.toCanonicalExtendedJSONString()
        }
    }
    return calculateAndPrintResults(name: "\(file.name) BSON to JSON", time: results, size: file.size)
}

func benchmarkBSON() throws {
    let allResults = try bsonTestFiles.map { file in
        [
            try runJSONToBSONBenchmark(file),
            try runBSONToJSONBenchmark(file)
        ]
    }.reduce([], +)
}
