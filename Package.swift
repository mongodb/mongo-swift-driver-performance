// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "mongo-swift-driver-performance",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        //.package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.0.0"))
        //.package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("SWIFT-936/new-bson-library"))
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("new-bson-library-and-updates"))
    ],
    targets: [
        .target(name: "Benchmarks", dependencies: ["MongoSwift", "MongoSwiftSync"])
    ]
)
