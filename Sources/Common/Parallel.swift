import NIO

let parallelInputPath = "\(dataPath)/ldjson_multi"
/// Output directory for parallel benchmark files.
public let parallelOutputPath = "\(dataPath)/ldjson_multi_output"

public func paddedId(_ id: Int32) -> String {
    var num = String(id)
    while num.count < 3 {
        num = "0" + num
    }
    return num
}

/// Gets the input path for a file in the parallel benchmark with the specified id.
public func getParallelInputFilePath(forId id: Int32) -> String {
    "\(parallelInputPath)/ldjson\(paddedId(id)).txt"
}

/// Gets the output path for a file in the parallel benchmark with the specified id.
public func getParallelOutputFilePath(forId id: Int32) -> String {
    "\(parallelOutputPath)/ldjson\(paddedId(id)).txt"
}

/// Length of each LDJSON file in bytes.
public let parallelFileLength = 5_650_000
/// Total size of dataset in MB.
public let ldJSONSize = 565.0
/// Shared allocator to use throughout the benchmarks.
public let allocator = ByteBufferAllocator()
