import Foundation
import MongoSwift
import NIO

let filePaths: [String] = (0...99).map { i in
    var num = String(i)
    while num.count < 3 {
        num = "0" + num
    }
    return "\(dataPath)/ldjson_multi/ldjson\(num).txt"
}
let allocator = ByteBufferAllocator()

func importAllFiles(to collection: MongoCollection<Document>, using elg: EventLoopGroup) throws {
    EventLoopFuture.andAllSucceed(
        filePaths.map {
            importJSONFile(ioHandler: fileIO, path: $0, to: coll, eventLoop: elg.next())
        },
    on: elg.next())
}

func importJSONFile(
    ioHandler: NonBlockingFileIO,
    path: String,
    to collection: MongoCollection<Document>,
    eventLoop: EventLoop
) -> EventLoopFuture<InsertManyResult?> {
    ioHandler.openFile(path: path, eventLoop: eventLoop).flatMap { handle, region in
        let readAndInsert: EventLoopFuture<InsertManyResult?> = ioHandler.read(fileRegion: region,
                                           allocator: allocator,
                                           eventLoop: eventLoop).flatMap {
            var buffer = $0
            var docs = [Document]()
            while let next = buffer.readString(length: 1129) {
                docs.append(try! Document(fromJSON: next))
                // drop the newline character at the end of each line
                buffer.moveReaderIndex(forwardBy: 1)
            }

            return collection.insertMany(docs)
        }

        readAndInsert.whenComplete { _ in
            _ = try? handle.close()
        }

        return readAndInsert
    }
}

// func exportCollection(
//     ioHandler: NonBlockingFileIO,
//     to directory: String,
//     from collection: MongoCollection<Document>,
//     eventLoop: EventLoop
// ) -> EventLoopFuture<Void> {

// }

func runMultiJSONBenchmarks() throws {
    // Setup
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    let client = try MongoClient(using: elg)
    defer {
        client.syncShutdown()
    }
    let db = client.db("perftest")

    let threadPool = NIOThreadPool(numberOfThreads: NonBlockingFileIO.defaultThreadPoolSize)
    threadPool.start()
    let fileIO = NonBlockingFileIO(threadPool: threadPool)

    let coll = try db.drop().flatMap { _ in
        db.createCollection("corpus")
    }.wait()

    let importResult = try measureOp {
        try importAllFiles.wait()
    }

    print("JSON Import Benchmark Result: \(importResult)")
}
