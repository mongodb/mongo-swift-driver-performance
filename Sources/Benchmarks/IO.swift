import Foundation
import MongoSwiftSync

let tweetFile = TestFile(name: "tweet", size: 16.22)
let smallFile = TestFile(name: "small_doc", size: 2.75)
let largeFile = TestFile(name: "large_doc", size: 27.31)

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

func runFindManyAndEmptyCursorBenchmark(using db: MongoDatabase, file: TestFile) throws -> Double {
    print("Benchmarking \(file.name) find() and empty cursor")

    let document = try BSONDocument(fromJSON: file.json)
    let collection = db.collection("corpus")
    try collection.insertMany((1...10000).map { _ in document })

    let results = try measureTask {
        let cursor = try collection.find()
        _ = Array(cursor)
    }
    return calculateAndPrintResults(name: "findManyAndEmptyCursor", time: results, size: tweetFile.size)
}

func runSmallFindManyBenchmark(using db: MongoDatabase) throws -> Double {
    try runFindManyAndEmptyCursorBenchmark(using: db, file: smallFile)
}

func runLargeFindManyBenchmark(using db: MongoDatabase) throws -> Double {
    try runFindManyAndEmptyCursorBenchmark(using: db, file: largeFile)
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

@discardableResult
func withDBCleanup(db: MongoDatabase, body: (MongoDatabase) throws -> Double) throws -> Double {
    try db.drop()
    return try body(db)
}

func benchmarkIO() throws {
    let db = try MongoClient().db("perftest")

    try withDBCleanup(db: db, body: runFindOneByIdBenchmark)

    try withDBCleanup(db: db, body: runSmallInsertOneBenchmark)
    try withDBCleanup(db: db, body: runLargeInsertOneBenchmark)

    try withDBCleanup(db: db, body: runSmallBulkInsertBenchmark)
    try withDBCleanup(db: db, body: runLargeBulkInsertBenchmark)

    try withDBCleanup(db: db, body: runSmallFindManyBenchmark)
    try withDBCleanup(db: db, body: runLargeFindManyBenchmark)
}
