import Common
import Foundation
import MongoSwift

struct DocElem {
    let key: String
    let value: SwiftBSON
}

enum SwiftBSON {
    case document([DocElem])
    case other(BSON)
}

/// Extension of Document to allow conversion to and from arrays.
extension BSONDocument {
    internal init(fromArray array: [DocElem]) {
        self.init()

        for elem in array {
            switch elem.value {
            case let .document(els):
                self[elem.key] = .document(BSONDocument(fromArray: els))
            case let .other(b):
                self[elem.key] = b
            }
        }
    }

    internal func toArray() -> [DocElem] {
        map { kvp in
            if let subdoc = kvp.value.documentValue {
                return DocElem(key: kvp.key, value: .document(subdoc.toArray()))
            }
            return DocElem(key: kvp.key, value: .other(kvp.value))
        }
    }
}

let bsonTestFiles = [
    TestFile(name: "flat_bson", size: 75.31),
    TestFile(name: "deep_bson", size: 19.64),
    TestFile(name: "full_bson", size: 57.34)
]

// Note: the BSON benchmarks are intended to test native type <-> BSON speeds. However, for drivers like C that don't
// have a document type backed by native types (i.e. the document is just raw bytes) there are alternate versions
// defined that instead test JSON <-> BSON speeds.
// While a Swift document is backed by raw BSON data stored in a `bson_t` and is therefore just required to implement
// the JSON <-> BSON tests, it is still valuable to implement a version of native type <-> BSON benchmarks that test
// (array of key-value pair) <-> BSON conversion, so we define methods to support both here.

/// Runs a benchmark that tests how long it takes to parse JSON from the provided file into BSON data.
/// This is the "C driver version" of the BSON encoding benchmarks.
/// The caller should specify a number of iterations that satisfies the spec requirements for how long this benchmark
/// should run for.
func runJSONToBSONBenchmark(_ file: TestFile) throws -> Double {
    print("Benchmarking \(file.name) JSON to BSON")
    let json = file.json
    let results = try measureTask {
        for _ in 1...10000 {
            _ = try BSONDocument(fromJSON: json)
        }
    }
    return calculateAndPrintResults(name: "\(file.name) JSON to BSON", time: results, size: file.size)
}

/// Runs a benchmark that tests how long it takes to encode native Swift data types corresponding to the provided JSON
/// file into BSON. This is the non-"C driver version" of the BSON encoding benchmarks.
func runNativeToBSONBenchmark(_ file: TestFile) throws -> Double {
    print("Benchmarking \(file.name) native to BSON")
    let document = try BSONDocument(fromJSON: file.json)
    let docAsArray = document.toArray()
    let results = try measureTask {
        for _ in 1...10000 {
            _ = BSONDocument(fromArray: docAsArray)
        }
    }
    return calculateAndPrintResults(name: "\(file.name) native to BSON", time: results, size: file.size)
}

/// Runs a benchmark that tests how long it takes to convert BSON data corresponding to the JSON in the provided file
/// back to JSON. This is the "C driver version" of the BSON decoding benchmarks.
func runBSONToJSONBenchmark(_ file: TestFile) throws -> Double {
    print("Benchmarking \(file.name) BSON to JSON")
    let document = try BSONDocument(fromJSON: file.json)
    let results = try measureTask {
        for _ in 1...10000 {
            _ = document.toCanonicalExtendedJSONString()
        }
    }
    return calculateAndPrintResults(name: "\(file.name) BSON to JSON", time: results, size: file.size)
}

/// Runs a benchmark that tests how long it takes to decode BSON corresponding to the provided JSON file into
/// equivalent Swift data types. This is the non-"C driver version" of the BSON decoding benchmarks.
func runBSONToNativeBenchmark(_ file: TestFile) throws -> Double {
    print("Benchmarking \(file.name) BSON to native")
    let document = try BSONDocument(fromJSON: file.json)
    let results = try measureTask {
        for _ in 1...10000 {
            _ = document.toArray()
        }
    }
    return calculateAndPrintResults(name: "\(file.name) BSON to native", time: results, size: file.size)
}

func benchmarkBSON() throws {
    let allResults = try bsonTestFiles.map { file in
        [
            try runJSONToBSONBenchmark(file),
            try runNativeToBSONBenchmark(file),
            try runBSONToJSONBenchmark(file),
            try runBSONToNativeBenchmark(file)
        ]
    }.reduce([], +)
    print("BSONBench score: \(average(allResults))")
}
