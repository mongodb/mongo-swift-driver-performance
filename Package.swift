// swift-tools-version:4.0
import PackageDescription

let package = Package(
	name: "MongoSwift-Performance",
	dependencies: [
		.package(url: "https://github.com/mongodb/mongo-swift-driver", from: "0.0.7"),
		.package(url: "https://github.com/Quick/Nimble.git", from: "7.3.0")
	],
	targets: [
		.testTarget(name: "Benchmarks", dependencies: ["MongoSwift", "Nimble"])
	]
)
