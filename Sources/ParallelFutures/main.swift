import Foundation
import MongoSwift
import NIO

let inputPath = "\(dataPath)/ldjson_multi"
let outputPath = "\(dataPath)/ldjson_multi_output"

func paddedId(_ id: Int32) -> String {
    var num = String(id)
    while num.count < 3 {
        num = "0" + num
    }
    return num
}

func getInputFilePath(forId id: Int32) -> String {
    "\(inputPath)/ldjson\(paddedId(id)).txt"
}

func getOutputFilePath(forId id: Int32) -> String {
    "\(outputPath)/ldjson\(paddedId(id)).txt"
}

// Length of each LDJSON file in bytes.
let fileLength = 5_650_000
// Total size of dataset in MB.
let ldJSONSize = 565.0
// Shared allocator to use throughout the benchmarks.
let allocator = ByteBufferAllocator()

 /**
 * Imports all LDJSON files to the specified collection. This works by firing off 1 chained async call for each file
 * and combining their results into a single future. Each chained call works by:
 * 1. Reading in the entire contents of the file using `NonBlockingFileIO`.
 * 2. Converting the resulting bytes into documents.
 * 3. Bulk inserting the documents into the collection.
 *
 * The work will be spread over across the event loops in the provided group.
 * If addFileIds is true (useful for splitting up work in the export benchmark), the id of the source file is added to
 * each document that is insered.
 */
func importAllFiles(
    to collection: MongoCollection<BSONDocument>,
    eventLoopGroup: EventLoopGroup,
    ioHandler: NonBlockingFileIO,
    addFileIds: Bool = false
) throws -> EventLoopFuture<Void> {
    EventLoopFuture.andAllSucceed(
        (0...99).map {
            importJSONFile(
                id: $0,
                to: collection,
                eventLoop: eventLoopGroup.next(),
                ioHandler: ioHandler,
                addFileId: addFileIds
            )
        },
        on: eventLoopGroup.next()
    )
}

func importJSONFile(
    id: Int32,
    to collection: MongoCollection<BSONDocument>,
    eventLoop: EventLoop,
    ioHandler: NonBlockingFileIO,
    addFileId: Bool
) -> EventLoopFuture<InsertManyResult?> {
    ioHandler.openFile(path: getInputFilePath(forId: id), eventLoop: eventLoop).flatMap { handle, region in
        let readAndInsert: EventLoopFuture<InsertManyResult?> = ioHandler.read(
            fileRegion: region,
            allocator: allocator,
            eventLoop: eventLoop
        ).flatMap {
            var buffer = $0
            // these swiftlint disables are ok because we know the data is well-formed.
            let docs = buffer.readBytes(length: fileLength)! // swiftlint:disable:this force_unwrapping
                .split(separator: 10) // 10 is byte code for "\n"
                .map { try! BSONDocument(fromJSON: Data($0)) } // swiftlint:disable:this force_try
            if addFileId {
                let docsWithIds: [BSONDocument] = docs.map { doc in
                    var copy = doc
                    copy["fileId"] = .int32(id)
                    return copy
                }
                return collection.insertMany(docsWithIds)
            } else {
                return collection.insertMany(docs)
            }
        }

        readAndInsert.whenComplete { _ in
            _ = try? handle.close()
        }

        return readAndInsert
    }
}

 /**
 * Exports the specified collection to a set of LDJSON files. This works by firing off 1 chained async call for each
 * file and combining their results into a single future. Each chained call works by:
 * 1. Creating a cursor over documents in the collection with the specified file id.
 * 2. Writing all of the JSON data for the file into a ByteBuffer.
 * 3. Using `NonBlockingFileIO` to write the contents of the `ByteBuffer` to to disk.
 *
 * The work will be spread over across the event loops in the provided group.
 */
func exportCollection(
    _ collection: MongoCollection<BSONDocument>,
    eventLoopGroup: EventLoopGroup,
    ioHandler: NonBlockingFileIO
) throws -> EventLoopFuture<Void> {
    EventLoopFuture.andAllSucceed(
        try (0...99).map {
            try exportJSONFile(
                id: $0,
                from: collection,
                eventLoop: eventLoopGroup.next(),
                ioHandler: ioHandler
            )
        },
        on: eventLoopGroup.next()
    )
}

func exportJSONFile(
    id: Int32,
    from collection: MongoCollection<BSONDocument>,
    eventLoop: EventLoop,
    ioHandler: NonBlockingFileIO
) throws -> EventLoopFuture<Void> {
    let handle = try NIOFileHandle(path: getOutputFilePath(forId: id), mode: .write)
    let write: EventLoopFuture<Void> = collection.find(["fileId": .int32(id)], options: FindOptions(batchSize: 5000))
        .flatMap { $0.toArray() }
        .flatMap { docs in
            var buffer = allocator.buffer(capacity: docs[0].toExtendedJSONString().utf8.count * 5000)
            docs.forEach { doc in
                _ = buffer.writeString(doc.toExtendedJSONString() + "\n")
            }
            return ioHandler.write(fileHandle: handle, buffer: buffer, eventLoop: eventLoop)
        }

    write.whenComplete { _ in
        _ = try? handle.close()
    }

    return write
}

func runMultiJSONBenchmarks() throws -> (importScore: Double, outputScore: Double) {
    // Setup
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    let client = try MongoClient(using: elg)
    defer {
        try? client.syncClose()
    }
    let db = client.db("perftest")
    let coll = db.collection("corpus")

    let threadPool = NIOThreadPool(numberOfThreads: NonBlockingFileIO.defaultThreadPoolSize)
    threadPool.start()
    defer {
        try? threadPool.syncShutdownGracefully()
    }
    let fileIO = NonBlockingFileIO(threadPool: threadPool)

    let importResult = try measureTask(
        before: {
            _ = try db.drop().wait()
            _ = try db.createCollection("corpus").wait()
        },
        task: {
            try importAllFiles(to: coll, eventLoopGroup: elg, ioHandler: fileIO).wait()
        }
    )

    let importScore = calculateAndPrintResults(name: "LDJSON Multi-file Import", time: importResult, size: ldJSONSize)

    // One-time setup for the export benchmark.
    _ = try db.drop().wait()
    _ = try importAllFiles(to: coll, eventLoopGroup: elg, ioHandler: fileIO, addFileIds: true).wait()
    _ = try coll.createIndex(["fileId": .int32(1)]).wait()

    let exportResult = try measureTask(
        before: {
            try? FileManager.default.removeItem(atPath: outputPath)
            try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: false)
            (0...99).forEach { id in
                _ = FileManager.default.createFile(atPath: getOutputFilePath(forId: Int32(id)), contents: nil)
            }
        },
        task: {
            _ = try exportCollection(coll, eventLoopGroup: elg, ioHandler: fileIO).wait()
        }
    )

    let outputScore = calculateAndPrintResults(name: "LDJSON Multi-file Export", time: exportResult, size: ldJSONSize)
    try FileManager.default.removeItem(atPath: outputPath)

    return (importScore: importScore, outputScore: outputScore)
}
