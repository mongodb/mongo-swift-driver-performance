import Common
import Foundation
import MongoSwift
import NIO

/**
 * Imports all LDJSON files to the specified collection.
 *
 * The work will be spread over across the event loops in the provided group.
 * If addFileIds is true (useful for splitting up work in the export benchmark), the id of the source file is added to
 * each document that is inserted.
 */
@available(macOS 12.0, *)
func importAllFiles(
    to collection: MongoCollection<BSONDocument>,
    eventLoopGroup: EventLoopGroup,
    ioHandler: NonBlockingFileIO,
    addFileIds: Bool = false
) async throws {
    _ = await withThrowingTaskGroup(of: Void.self) { group in
        (0...99).map { id in
            group.addTask {
                try await importJSONFile(
                    id: id,
                    to: collection,
                    eventLoop: eventLoopGroup.next(),
                    ioHandler: ioHandler,
                    addFileId: addFileIds
                )
            }
        }
    }
}

@available(macOS 12.0, *)
func importJSONFile(
    id: Int32,
    to collection: MongoCollection<BSONDocument>,
    eventLoop: EventLoop,
    ioHandler: NonBlockingFileIO,
    addFileId: Bool
) async throws {
    let (handle, region) = try await ioHandler.openFile(
        path: getParallelInputFilePath(forId: id).path,
        eventLoop: eventLoop
    ).get()
    defer { _ = try? handle.close() }

    var buffer = try await ioHandler.read(
        fileRegion: region,
        allocator: allocator,
        eventLoop: eventLoop
    ).get()
    let docs = buffer.readBytes(length: parallelFileLength)! // swiftlint:disable:this force_unwrapping
        .split(separator: 10) // 10 is byte code for "\n"
        .map { try! BSONDocument(fromJSON: Data($0)) } // swiftlint:disable:this force_try

    if addFileId {
        let docsWithIds = docs.map { doc -> BSONDocument in
            var copy = doc
            copy["fileId"] = .int32(id)
            return copy
        }
        _ = try await collection.insertMany(docsWithIds)
    } else {
        _ = try await collection.insertMany(docs)
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
@available(macOS 12.0, *)
func exportCollection(
    _ collection: MongoCollection<BSONDocument>,
    eventLoopGroup: EventLoopGroup,
    ioHandler: NonBlockingFileIO
) async throws {
    _ = await withThrowingTaskGroup(of: Void.self) { group in
        (0...99).map { id in
            group.addTask {
                try await exportJSONFile(
                    id: id,
                    from: collection,
                    eventLoop: eventLoopGroup.next(),
                    ioHandler: ioHandler
                )
            }
        }
    }
}

@available(macOS 12.0, *)
func exportJSONFile(
    id: Int32,
    from collection: MongoCollection<BSONDocument>,
    eventLoop: EventLoop,
    ioHandler: NonBlockingFileIO
) async throws {
    let handle = try NIOFileHandle(path: getParallelOutputFilePath(forId: id).path, mode: .write)
    defer { try? handle.close() }

    var buffer = allocator.buffer(capacity: 1000 * 5000)
    for doc in try await collection.find(["fileId": .int32(id)], options: FindOptions(batchSize: 5000)).toArray() {
        _ = buffer.writeString(doc.toExtendedJSONString() + "\n")
    }

    try await ioHandler.write(fileHandle: handle, buffer: buffer, eventLoop: eventLoop).get()
}

@available(macOS 12.0, *)
func runMultiJSONBenchmarks() async throws -> (importScore: Double, outputScore: Double) {
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

    let importResult = try await measureTask(
        before: {
            _ = try await db.drop()
            _ = try await db.createCollection("corpus")
        },
        task: {
            try await importAllFiles(to: coll, eventLoopGroup: elg, ioHandler: fileIO)
        }
    )

    let importScore = calculateAndPrintResults(name: "LDJSON Multi-file Import", time: importResult, size: ldJSONSize)

    // One-time setup for the export benchmark.
    _ = try await db.drop()
    _ = try await importAllFiles(to: coll, eventLoopGroup: elg, ioHandler: fileIO, addFileIds: true)
    _ = try await coll.createIndex(["fileId": .int32(1)])

    let exportResult = try await measureTask(before: parallelOutputSetup) {
        _ = try await exportCollection(coll, eventLoopGroup: elg, ioHandler: fileIO)
    }

    let outputScore = calculateAndPrintResults(name: "LDJSON Multi-file Export", time: exportResult, size: ldJSONSize)
    try parallelOutputCleanup()

    return (importScore: importScore, outputScore: outputScore)
}
