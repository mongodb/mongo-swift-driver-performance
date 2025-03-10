import Common
import Foundation
import MongoSwiftSync

func runCommandBenchmark(using db: MongoDatabase) throws -> Double {
    print("Benchmarking runCommand")

    let results = try measureTask {
        for _ in 1...10000 {
            _ = try db.runCommand(helloCommand)
        }
    }
    return calculateAndPrintResults(name: "runCommand", time: results, size: helloCommandSize)
}

func runFindOneByIdBenchmark(using db: MongoDatabase) throws -> Double {
    print("Benchmarking findOne by _id")

    let collection = db.collection("perftest")
    var doc = try BSONDocument(fromJSON: tweetFile.json)

    let ids = (1...10000).map { BSON.int32(Int32($0)) }

    for id in ids {
        doc["_id"] = id
        try collection.insertOne(doc)
    }
    // Pre-create queries in order to not include the time spent encoding in results.
    let queries: [BSONDocument] = ids.map { ["_id": $0] }

    let results = try measureTask {
        for query in queries {
            _ = try collection.findOne(query)
        }
    }
    return calculateAndPrintResults(name: "findOneById", time: results, size: tweetFile.size)
}

/// Runs a single insertOne benchmark with the given file using the given DB.
func runInsertOneBenchmark(using db: MongoDatabase, file: TestFile, copies: Int) throws -> Double {
    print("Benchmarking \(file.name) insertOne")

    try db.drop()
    let collection = db.collection("corpus")
    let document = try BSONDocument(fromJSON: file.json)

    let results = try measureTask(
        before: {
            try db.drop()
            _ = try db.createCollection("corpus")
        },
        task: {
            for _ in 1...copies {
                try collection.insertOne(document)
            }
        }
    )
    return calculateAndPrintResults(name: "\(file.name) insertOne", time: results, size: file.size)
}

func runSmallInsertOneBenchmark(using db: MongoDatabase) throws -> Double {
    try runInsertOneBenchmark(using: db, file: smallFile, copies: 10000)
}

func runLargeInsertOneBenchmark(using db: MongoDatabase) throws -> Double {
    try runInsertOneBenchmark(using: db, file: largeFile, copies: 10)
}

func runFindManyAndEmptyCursorBenchmark(using db: MongoDatabase) throws -> Double {
    print("Benchmarking find() and empty cursor")

    let document = try BSONDocument(fromJSON: tweetFile.json)
    let collection = db.collection("corpus")
    try collection.insertMany((1...10000).map { _ in document })

    let results = try measureTask {
        let cursor = try collection.find()
        for _ in cursor {}
    }
    return calculateAndPrintResults(name: "findManyAndEmptyCursor", time: results, size: tweetFile.size)
}

func runBulkInsertBenchmark(using db: MongoDatabase, file: TestFile, copies: Int) throws -> Double {
    print("Benchmarking \(file.name) bulk insert")

    let collection = db.collection("corpus")
    let document = try BSONDocument(fromJSON: file.json)
    let toInsert = (1...copies).map { _ in document }

    let results = try measureTask(
        before: {
            try db.drop()
            _ = try db.createCollection("corpus")
        },
        task: {
            try collection.insertMany(toInsert)
        }
    )
    return calculateAndPrintResults(name: "\(file.name) bulk insert", time: results, size: file.size)
}

func runSmallBulkInsertBenchmark(using db: MongoDatabase) throws -> Double {
    try runBulkInsertBenchmark(using: db, file: smallFile, copies: 10000)
}

func runLargeBulkInsertBenchmark(using db: MongoDatabase) throws -> Double {
    try runBulkInsertBenchmark(using: db, file: largeFile, copies: 10)
}

func withDBCleanup(db: MongoDatabase, body: (MongoDatabase) throws -> Double) throws -> Double {
    try db.drop()
    return try body(db)
}

func benchmarkIO() throws {
    let db = try MongoClient().db("perftest")

    // this benchmark isn't factored into any composite scores.
    _ = try withDBCleanup(db: db, body: runCommandBenchmark)

    let findOne = try withDBCleanup(db: db, body: runFindOneByIdBenchmark)
    let smallInsertOne = try withDBCleanup(db: db, body: runSmallInsertOneBenchmark)
    let largeInsertOne = try withDBCleanup(db: db, body: runLargeInsertOneBenchmark)
    let findMany = try withDBCleanup(db: db, body: runFindManyAndEmptyCursorBenchmark)
    let smallBulk = try withDBCleanup(db: db, body: runSmallBulkInsertBenchmark)
    let largeBulk = try withDBCleanup(db: db, body: runLargeBulkInsertBenchmark)
    let (multiImport, multiExport) = try runMultiJSONBenchmarks()

    let singleBenchResult = average([findOne, smallInsertOne, largeInsertOne])
    print("SingleBench score: \(singleBenchResult)")

    let multiBenchResult = average([findMany, smallBulk, largeBulk])
    print("MultiBench score: \(multiBenchResult)")

    // TODO: add gridfs results
    let readBenchResult = average([findOne, findMany, multiExport])
    print("ReadBench score: \(readBenchResult)")

    // TODO: add gridfs results
    let writeBenchResult = average([smallInsertOne, largeInsertOne, smallBulk, largeBulk, multiImport])
    print("WriteBench score: \(writeBenchResult)")

    // TODO: add gridfs results
    let parallelBenchResult = average([multiImport, multiExport])
    print("ParallelBench score: \(parallelBenchResult)")

    let driverBenchResult = average([readBenchResult, writeBenchResult])
    print("DriverBench score: \(driverBenchResult)")
}

try benchmarkIO()
