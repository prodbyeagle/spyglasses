// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "SpyGlasses",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "SpyGlasses", targets: ["SpyGlasses"]),
  ],
  targets: [
    .executableTarget(
      name: "SpyGlasses",
      path: "Sources/SpyGlasses",
      linkerSettings: [
        .linkedFramework("IOKit"),
        .linkedFramework("ServiceManagement")
      ]
    ),
    .testTarget(
      name: "SpyGlassesTests",
      dependencies: ["SpyGlasses"]
    )
  ]
)
