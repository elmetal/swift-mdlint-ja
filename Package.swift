// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-mdlint-ja",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "swift-mdlint-ja", targets: ["swift-mdlint-ja"]),
        .library(name: "MDLintCore", targets: ["MDLintCore"]),
        .library(name: "MDLintRules", targets: ["MDLintRules"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "swift-mdlint-ja",
            dependencies: [
                "MDLintCore",
                "MDLintRules",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "MDLintCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .target(
            name: "MDLintRules",
            dependencies: [
                "MDLintCore",
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .testTarget(
            name: "MDLintCoreTests",
            dependencies: ["MDLintCore"]
        )
    ]
)
