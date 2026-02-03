// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AsyncClosureLinter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "async-closure-lint", targets: ["AsyncClosureLinter"]),
        .library(name: "AsyncClosureLinterCore", targets: ["AsyncClosureLinterCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "AsyncClosureLinterCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "AsyncClosureLinter",
            dependencies: [
                "AsyncClosureLinterCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "AsyncClosureLinterTests",
            dependencies: ["AsyncClosureLinterCore"]
        )
    ]
)
