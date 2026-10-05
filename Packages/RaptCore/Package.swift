// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RaptCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RaptCore", targets: ["RaptCore"]),
    ],
    targets: [
        .target(name: "RaptCore"),
        .testTarget(name: "RaptCoreTests", dependencies: ["RaptCore"]),
    ]
)
