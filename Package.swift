// swift-tools-version:5.9
import PackageDescription

// Privatus Analytics for Swift and Vapor. Version 1.0.0. MIT licence, (c) Two Phase LLC.
// Homepage: https://privatusanalytics.com
// Repository: https://github.com/Privatus-Analytics/swift

let package = Package(
  name: "PrivatusAnalytics",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(name: "PrivatusAnalytics", targets: ["PrivatusAnalytics"]),
    .library(name: "PrivatusAnalyticsVapor", targets: ["PrivatusAnalyticsVapor"]),
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
  ],
  targets: [
    .target(name: "PrivatusAnalytics"),
    .target(
      name: "PrivatusAnalyticsVapor",
      dependencies: [
        "PrivatusAnalytics",
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Leaf", package: "leaf"),
      ]
    ),
    .testTarget(name: "PrivatusAnalyticsTests", dependencies: ["PrivatusAnalytics"]),
    .testTarget(
      name: "PrivatusAnalyticsVaporTests",
      dependencies: [
        "PrivatusAnalyticsVapor",
        .product(name: "XCTVapor", package: "vapor"),
      ]
    ),
  ]
)
