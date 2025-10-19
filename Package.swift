// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SCServoSDK",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SCServoSDK",
            targets: ["SCServoSDK"]),
        .executable(
            name: "PingExample",
            targets: ["PingExample"]),
        .executable(
            name: "ReadWriteExample", 
            targets: ["ReadWriteExample"]),
        .executable(
            name: "SyncReadWriteExample",
            targets: ["SyncReadWriteExample"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SCServoSDK",
            dependencies: []),
        .executableTarget(
            name: "PingExample",
            dependencies: ["SCServoSDK"],
            path: "Sources/PingExample"),
        .executableTarget(
            name: "ReadWriteExample",
            dependencies: ["SCServoSDK"],
            path: "Sources/ReadWriteExample"),
        .executableTarget(
            name: "SyncReadWriteExample",
            dependencies: ["SCServoSDK"],
            path: "Sources/SyncReadWriteExample"),
        .testTarget(
            name: "SCServoSDKTests",
            dependencies: ["SCServoSDK"]),
    ]
)