import Foundation
import MongoSwift

func getDataPath() -> URL {
        let thisFile = URL(fileURLWithPath: #file)
        // We are in Sources/Common/Utils.swift; drop 3 components to get up to the root directory.
        let baseDirectory = thisFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return baseDirectory.appendingPathComponent("data")
}

/// Get where benchmarking data is stored.
public let dataPath = getDataPath()

/// Struct representing a file used for the benchmarks.
public struct TestFile {
    /// The name of this file.
    public let name: String
    /// The size of the file, in MB.
    public let size: Double
    /// The JSON contents of the file.
    public let json: String

    /// Initializes a new `TestFile`.
    public init(name: String, size: Double) {
        self.name = name
        self.size = size
        // we only call this method with known valid paths, so it won't fail.
        // swiftlint:disable:next force_try
        self.json = try! String(contentsOf: dataPath.appendingPathComponent("\(name).json"))
    }
}

/// Tweet file for use in benchmarks.
public let tweetFile = TestFile(name: "tweet", size: 16.22)
/// Small file for use in benchmarks.
public let smallFile = TestFile(name: "small_doc", size: 2.75)
/// Large file for use in benchmarks.
public let largeFile = TestFile(name: "large_doc", size: 27.31)

/// Hello command for use in benchmarks.
/// Per spec: "We use {hello:true} rather than {hello:1} to ensure a consistent command size."
public let helloCommand: BSONDocument = ["hello": true]
/// Size in MB of hello command.
public let helloCommandSize = 0.13

/// Measure the time for a single execution of the provided closure.
func measureTime(_ task: () throws -> Void) throws -> TimeInterval {
    let startTime = ProcessInfo.processInfo.systemUptime
    try task()
    let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime
    return timeElapsed
}

/// Measure the time for a single execution of the provided closure.
@available(macOS 12.0, *)
func measureTime(_ task: () async throws -> Void) async throws -> TimeInterval {
    let startTime = ProcessInfo.processInfo.systemUptime
    try await task()
    let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime
    return timeElapsed
}

/// Measure the median time for executing the provided operation. If `setup` is provided, it will be run before each
/// measurement is taken.
public func measureTask(before: () throws -> Void = {}, task: () throws -> Void) throws -> TimeInterval {
    var results = [TimeInterval]()
    var iterations = 0
    var totalTime = 0.0

    // Iterations should loop for at least 1 minute cumulative execution time.
    // Iterations should stop after 100 iterations or 5 minutes cumulative execution time,
    // whichever is shorter.
    while totalTime < 60.0 || (iterations < 100 && totalTime < 300.0) {
        try before()
        let measurement = try measureTime(task)
        results.append(measurement)
        iterations += 1
        totalTime += measurement
    }
    return median(results)
}

/// Measure the median time for executing the provided operation. If `setup` is provided, it will be run before each
/// measurement is taken.
@available(macOS 12.0, *)
public func measureTask(
    before: () async throws -> Void = {},
    task: () async throws -> Void
) async throws -> TimeInterval {
    var results = [TimeInterval]()
    var iterations = 0
    var totalTime = 0.0

    // Iterations should loop for at least 1 minute cumulative execution time.
    // Iterations should stop after 100 iterations or 5 minutes cumulative execution time,
    // whichever is shorter.
    while totalTime < 60.0 || (iterations < 100 && totalTime < 300.0) {
        try await before()
        let measurement = try await measureTime(task)
        results.append(measurement)
        iterations += 1
        totalTime += measurement
    }
    return median(results)
}

/// Compute the median of the provided array.
func median<T: Comparable>(_ input: [T]) -> T {
    input.sorted(by: <)[input.count / 2]
}

/// Calculates the average value of an array of doubles.
public func average(_ input: [Double]) -> Double {
    input.reduce(0, +) / Double(input.count)
}

/// Calculates and prints the score for a benchmark.
public func calculateAndPrintResults(name: String, time: TimeInterval, size: Double) -> Double {
    let roundedTime = floor(time * 1000) / 1000
    let roundedScore = floor(size / time * 10000) / 10000
    print("Results for \(name): median time \(roundedTime) seconds, score \(roundedScore) MB/s")
    return roundedScore
}
