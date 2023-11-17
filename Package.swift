// swift-tools-version:5.9

import PackageDescription
let package = Package(
  name: "vm",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "vm", targets: ["vm"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.3"),
  ],
  targets: [
    .executableTarget(name: "vm", dependencies: [
      .product(name: "ArgumentParser", package: "swift-argument-parser"),
    ])
  ]
)
