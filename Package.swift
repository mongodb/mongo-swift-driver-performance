// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "mongo-swift-driver-performance",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("main")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.33.0"))
    ],
    targets: [
        .executableTarget(name: "BSON", dependencies: [
            .product(name: "MongoSwift", package: "mongo-swift-driver"),
            "Common"
        ]),
        .executableTarget(name: "IO", dependencies: [
            .product(name: "MongoSwiftSync", package: "mongo-swift-driver"),
            "Parallel",
            "Common"
        ]),
        .executableTarget(name: "AsyncIO", dependencies: [
            .product(name: "MongoSwift", package: "mongo-swift-driver"),
            .product(name: "NIO", package: "swift-nio"),
            "Common"
        ]),
        .target(name: "Parallel", dependencies: [
            .product(name: "MongoSwift", package: "mongo-swift-driver"),
            .product(name: "NIO", package: "swift-nio"),
            "Common"
        ]),
        .target(name: "AsyncParallel", dependencies: [
            .product(name: "MongoSwift", package: "mongo-swift-driver"),
            .product(name: "NIO", package: "swift-nio"),
            "Common"
        ]),
        .target(name: "Common")
    ]
)
