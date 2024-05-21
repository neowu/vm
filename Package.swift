// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "vz",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "vz", targets: ["vz"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.1"),
        .package(url: "https://github.com/apple/swift-format.git", branch: ("release/5.10")),
    ],
    targets: [
        .executableTarget(
            name: "vz",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ])
    ]
)
