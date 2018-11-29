import XCTest

#if !os(macOS)
/// A function that returns all tests that can be run.
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(EncodingBenchmarks.allTests),
        testCase(DecodingBenchmarks.allTests),
        testCase(SingleDocumentBenchmarks.allTests),
        testCase(MultiDocumentBenchmarks.allTests)
    ]
}
#endif
