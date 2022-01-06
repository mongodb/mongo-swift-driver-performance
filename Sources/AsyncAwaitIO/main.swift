#if compiler(>=5.5) && canImport(_Concurrency)

import Common
import Foundation
import MongoSwift
import NIO

@available(macOS 12, *)
func runCommandBenchmark(using db: MongoDatabase) async throws -> Double {
    print("Benchmarking runCommand")

    let results = try await measureTask {
        for _ in 1...10000 {
            _ = try await db.runCommand(helloCommand)
        }
    }
    return calculateAndPrintResults(name: "runCommand", time: results, size: helloCommandSize)
}

@available(macOS 12, *)
func runFindOneByIdBenchmark(using db: MongoDatabase) async throws -> Double {
    print("Benchmarking findOne by _id")

    let collection = db.collection("perftest")
    var doc = try BSONDocument(fromJSON: tweetFile.json)

    let ids = (1...10000).map { BSON.int32(Int32($0)) }

    for id in ids {
        doc["_id"] = id
        try await collection.insertOne(doc)
    }
    // Pre-create queries in order to not include the time spent encoding in results.
    let queries: [BSONDocument] = ids.map { ["_id": $0] }

    let results = try await measureTask {
        for query in queries {
            _ = try await collection.findOne(query)
        }
    }
    return calculateAndPrintResults(name: "findOneById", time: results, size: tweetFile.size)
}

/// Runs a single insertOne benchmark with the given file using the given DB.
@available(macOS 12, *)
func runInsertOneBenchmark(using db: MongoDatabase, file: TestFile, copies: Int) async throws -> Double {
    print("Benchmarking \(file.name) insertOne")

    try await db.drop()
    let collection = db.collection("corpus")
    let document = try BSONDocument(fromJSON: file.json)

    let results = try await measureTask(
        before: {
            try await db.drop()
            _ = try await db.createCollection("corpus")
        },
        task: {
            for _ in 1...copies {
                try await collection.insertOne(document)
            }
        }
    )
    return calculateAndPrintResults(name: "\(file.name) insertOne", time: results, size: file.size)
}

@available(macOS 12, *)
func runSmallInsertOneBenchmark(using db: MongoDatabase) async throws -> Double {
    try await runInsertOneBenchmark(using: db, file: smallFile, copies: 10000)
}

@available(macOS 12, *)
func runLargeInsertOneBenchmark(using db: MongoDatabase) async throws -> Double {
    try await runInsertOneBenchmark(using: db, file: largeFile, copies: 10)
}

@available(macOS 12, *)
func runFindManyAndEmptyCursorBenchmark(using db: MongoDatabase) async throws -> Double {
    print("Benchmarking find() and empty cursor")

    let document = try BSONDocument(fromJSON: tweetFile.json)
    let collection = db.collection("corpus")
    try await collection.insertMany((1...10000).map { _ in document })

    let results = try await measureTask {
        let cursor = try await collection.find()
        for try await _ in cursor {}
    }
    return calculateAndPrintResults(name: "findManyAndEmptyCursor", time: results, size: tweetFile.size)
}

@available(macOS 12, *)
func runBulkInsertBenchmark(using db: MongoDatabase, file: TestFile, copies: Int) async throws -> Double {
    print("Benchmarking \(file.name) bulk insert")

    let collection = db.collection("corpus")
    let document = try BSONDocument(fromJSON: file.json)
    let toInsert = (1...copies).map { _ in document }

    let results = try await measureTask(
        before: {
            try await db.drop()
            _ = try await db.createCollection("corpus")
        },
        task: {
            try await collection.insertMany(toInsert)
        }
    )
    return calculateAndPrintResults(name: "\(file.name) bulk insert", time: results, size: file.size)
}

@available(macOS 12, *)
func runSmallBulkInsertBenchmark(using db: MongoDatabase) async throws -> Double {
    try await runBulkInsertBenchmark(using: db, file: smallFile, copies: 10000)
}

@available(macOS 12, *)
func runLargeBulkInsertBenchmark(using db: MongoDatabase) async throws -> Double {
    try await runBulkInsertBenchmark(using: db, file: largeFile, copies: 10)
}

@available(macOS 12, *)
func withDBCleanup(db: MongoDatabase, body: (MongoDatabase) async throws -> Double) async throws -> Double {
    try await db.drop()
    return try await body(db)
}

@available(macOS 12, *)
func benchmarkIO() async throws {
//    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
//    defer {
//        try? elg.syncShutdownGracefully()
//    }
//    let client = try MongoClient(using: elg)
//    defer {
//        try? client.syncClose()
//    }
//    let db = client.db("perftest")

//    // this benchmark isn't factored into any composite scores.
//    _ = try await withDBCleanup(db: db, body: runCommandBenchmark)
//
//    let findOne = try await withDBCleanup(db: db, body: runFindOneByIdBenchmark)
//    let smallInsertOne = try await withDBCleanup(db: db, body: runSmallInsertOneBenchmark)
//    let largeInsertOne = try await withDBCleanup(db: db, body: runLargeInsertOneBenchmark)
//    let findMany = try await withDBCleanup(db: db, body: runFindManyAndEmptyCursorBenchmark)
//    let smallBulk = try await withDBCleanup(db: db, body: runSmallBulkInsertBenchmark)
//    let largeBulk = try await withDBCleanup(db: db, body: runLargeBulkInsertBenchmark)
    let (multiImport, multiExport) = try await runMultiJSONBenchmarks()
//
//    let singleBenchResult = average([findOne, smallInsertOne, largeInsertOne])
//    print("SingleBench score: \(singleBenchResult)")
//
//    let multiBenchResult = average([findMany, smallBulk, largeBulk])
//    print("MultiBench score: \(multiBenchResult)")
//
//    // TODO: add gridfs results
//    let readBenchResult = average([findOne, findMany, multiExport])
//    print("ReadBench score: \(readBenchResult)")
//
//    // TODO: add gridfs results
//    let writeBenchResult = average([smallInsertOne, largeInsertOne, smallBulk, largeBulk, multiImport])
//    print("WriteBench score: \(writeBenchResult)")
//
//    // TODO: add gridfs results
//    let parallelBenchResult = average([multiImport, multiExport])
//    print("ParallelBench score: \(parallelBenchResult)")
//
//    let driverBenchResult = average([readBenchResult, writeBenchResult])
//    print("DriverBench score: \(driverBenchResult)")
}

if #available(macOS 12, *) {
    let dg = DispatchGroup()
    dg.enter()
    Task {
        do {
            try await benchmarkIO()
        } catch {
            print("Error executing async/await IO benchmarks: \(error)")
        }
        dg.leave()
    }
    dg.wait()
} else {
    print("Platform does not support running concurrency benchmarks")
}

#endif
