// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TuringCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TuringCore", targets: ["TuringCore"])],
    targets: [
        .target(name: "TuringCore"),
        .testTarget(name: "TuringCoreTests", dependencies: ["TuringCore"])
    ]
)
