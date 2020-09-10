// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "mongo-swift-driver-performance",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(name: "Benchmarks", dependencies: ["MongoSwift", "MongoSwiftSync"])
    ]
)
