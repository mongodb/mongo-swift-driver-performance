import Foundation
import MongoSwiftSync

let tweetFile = TestFile(name: "tweet", size: 16.22)
let smallFile = TestFile(name: "small_doc", size: 2.75)
let largeFile = TestFile(name: "large_doc", size: 27.31)

// Size in MB of {"isMaster": true}.
let runCommandSize = 0.16

func runCommandBenchmark(using db: MongoDatabase) throws {
    print("Benchmarking runCommand")

    let command: Document = ["isMaster": true]
    let results = try measureOp {
        for _ in 1...10000 {
            _ = try db.runCommand(command)
        }
    }
    printResults(name: "runCommand", time: results, size: runCommandSize)
}

func runFindOneByIdBenchmark(using db: MongoDatabase) throws {
    print("Benchmarking findOne by _id")

    let collection = db.collection("perftest")
    var doc = try Document(fromJSON: tweetFile.json)

    let ids = (1...10000).map { BSON.int32(Int32($0)) }

    for id in ids {
        doc["_id"] = id
        try collection.insertOne(doc)
    }
    // Pre-create queries in order to not include the time spent encoding in results.
    let queries: [Document] = ids.map { ["_id": $0] }

    let results = try measureOp {
        for query in queries {
            _ = try collection.findOne(query)
        }
    }
    printResults(name: "findOneById", time: results, size: tweetFile.size)
}

/// Runs a single insertOne benchmark with the given file using the given DB.
func runInsertOneBenchmark(using db: MongoDatabase, file: TestFile, copies: Int) throws {
    print("Benchmarking \(file.name) insertOne")

    try db.drop()
    let collection = try db.createCollection("corpus")
    let document = try Document(fromJSON: file.json)

    let results = try measureOp {
        for _ in 1...copies {
            try collection.insertOne(document)
        }
    }
    printResults(name: "\(file.name) insertOne", time: results, size: file.size)
}

/// Runs all insertOne benchmarks.
func runInsertOneBenchmarks(using db: MongoDatabase) throws {
    try runInsertOneBenchmark(using: db, file: smallFile, copies: 10000)
    try runInsertOneBenchmark(using: db, file: largeFile, copies: 10)
}

func runFindManyAndEmptyCursorBenchmark(using db: MongoDatabase) throws {
    print("Benchmarking find() and empty cursor")

    let document = try Document(fromJSON: tweetFile.json)
    let collection = db.collection("corpus")
    for _ in 1...10000 {
        try collection.insertOne(document)
    }

    let results = try measureOp {
        let cursor = try collection.find()
        _ = Array(cursor)
    }
    printResults(name: "findManyAndEmptyCursor", time: results, size: tweetFile.size)
}

func runBulkInsertBenchmark(using db: MongoDatabase, file: TestFile, copies: Int) throws {
    print("Benchmarking \(file.name) bulk insert")

    try db.drop()
    let collection = try db.createCollection("corpus")
    let document = try Document(fromJSON: file.json)
    let toInsert = (1...copies).map { _ in document }

    let results = try measureOp {
        try collection.insertMany(toInsert)
    }
    printResults(name: "\(file.name) bulk insert", time: results, size: file.size)
}

func runBulkInsertBenchmarks(using db: MongoDatabase) throws {
    try runBulkInsertBenchmark(using: db, file: smallFile, copies: 10000)
    try runBulkInsertBenchmark(using: db, file: largeFile, copies: 10)
}

let ioBenchmarks: [(MongoDatabase) throws -> Void] = [
    // runCommandBenchmark,
    // runFindOneByIdBenchmark,
    runInsertOneBenchmarks,
    runFindManyAndEmptyCursorBenchmark,
    runBulkInsertBenchmarks
]

func benchmarkIO() throws {
    let db = try MongoClient().db("perftest")
    try db.drop()
    for benchmark in ioBenchmarks {
        try db.drop()
        try benchmark(db)
        try db.drop()
    }
}
