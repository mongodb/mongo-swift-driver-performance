// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "mongo-swift-driver-performance",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("main")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.33.0"))
    ],
    targets: [
        .target(name: "BSON", dependencies: ["MongoSwift", "Common"]),
        .target(name: "Common", dependencies: ["MongoSwift"]),
        .target(name: "IO", dependencies: ["MongoSwiftSync", "NIO", "Common"]),
        .target(name: "AsyncAwaitIO", dependencies: ["MongoSwift", "NIO", "Common"])
    ]
)
