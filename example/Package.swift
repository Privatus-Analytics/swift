// swift-tools-version:5.9
import PackageDescription

// The conformance example app (Vapor + Leaf). It uses the package from this
// repo's own source (the path dependency below), not from a release.
let package = Package(
  name: "Example",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(path: ".."),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
  ],
  targets: [
    .executableTarget(
      name: "Example",
      dependencies: [
        .product(name: "PrivatusAnalyticsVapor", package: "swift"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Leaf", package: "leaf"),
      ]
    )
  ]
)
