import Benchmarks
import XCTest

var tests = [XCTestCaseEntry]()
tests += Benchmarks.allTests()

XCTMain(tests)
