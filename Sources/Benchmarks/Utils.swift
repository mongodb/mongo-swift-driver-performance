import Foundation
import MongoSwift

let dataPath = "./data"

struct TestFile {
    let name: String
    let size: Double
    let json: String

    init(name: String, size: Double) {
        self.name = name
        self.size = size
        // we only call this method with known valid paths, so it won't fail.
        // swiftlint:disable:next force_try
        self.json = try! String(contentsOf: URL(fileURLWithPath: "\(dataPath)/\(name).json"))
    }
}

/// Measure the time for a single execution of the provided closure.
func measureTime(_ operation: () throws -> Void) throws -> Double {
    let startTime = ProcessInfo.processInfo.systemUptime
    try operation()
    let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime
    return Double(timeElapsed)
}

/// Measure the median time for `iterations` executions of the provided closure.
func measureOp(operation: () throws -> Void) throws -> Double {
    var results = [Double]()
    var iterations = 0
    var totalTime = 0.0

    // Iterations should loop for at least 1 minute cumulative execution time.
    // Iterations should stop after 100 iterations or 5 minutes cumulative execution time,
    // whichever is shorter.
    while totalTime < 60.0 || (iterations < 100 && totalTime < 300.0) {
        let measurement = try measureTime(operation)
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

func printResults(name: String, time: Double, size: Double) {
    let roundedTime = Double(floor(time * 1000) / 1000)
    let roundedScore = Double(floor(size / time * 10000) / 10000)
    print("Results for \(name): median time \(roundedTime) seconds, score \(roundedScore) MB/s")
}