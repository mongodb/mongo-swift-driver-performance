import Foundation
import NIO

func paddedId(_ id: Int32) -> String {
    String(format: "%03d", id)
}

let parallelInputPath = dataPath.appendingPathComponent("ldjson_multi")
let parallelOutputPath = dataPath.appendingPathComponent("ldjson_multi_output")

/// Gets the input path for a file in the parallel benchmark with the specified id.
public func getParallelInputFilePath(forId id: Int32) -> URL {
    parallelInputPath.appendingPathComponent("ldjson\(paddedId(id)).txt")
}

/// Gets the output path for a file in the parallel benchmark with the specified id.
public func getParallelOutputFilePath(forId id: Int32) -> URL {
    parallelOutputPath.appendingPathComponent("ldjson\(paddedId(id)).txt")
}

/// Length of each LDJSON file in bytes.
public let parallelFileLength = 5_650_000
/// Total size of dataset in MB.
public let ldJSONSize = 565.0
/// Shared allocator to use throughout the benchmarks.
public let allocator = ByteBufferAllocator()

/// Setup code for the LDJSON export benchmark.
public func parallelOutputSetup() throws {
    try? FileManager.default.removeItem(at: parallelOutputPath)
    try FileManager.default.createDirectory(atPath: parallelOutputPath.path, withIntermediateDirectories: false)
    (0...99).forEach { id in
        _ = FileManager.default.createFile(
            atPath: getParallelOutputFilePath(forId: Int32(id)).path,
            contents: nil
        )
    }
}

/// Cleanup code for the parallel output benchmark.
public func parallelOutputCleanup() throws {
    try FileManager.default.removeItem(at: parallelOutputPath)
}
