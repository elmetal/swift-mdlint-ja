// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-mdlint-ja",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mdlint-ja", targets: ["swift-mdlint-ja"]),
        .library(name: "MDLintCore", targets: ["MDLintCore"]),
        .library(name: "MDLintRules", targets: ["MDLintRules"]),
        .library(name: "MDLintConfig", targets: ["MDLintConfig"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "swift-mdlint-ja",
            dependencies: [
                "MDLintCore",
                "MDLintRules",
                "MDLintConfig",
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
        .target(
            name: "MDLintConfig",
            dependencies: [
                "MDLintRules"
            ]
        ),
        .testTarget(
            name: "MDLintCoreTests",
            dependencies: ["MDLintCore"]
        ),
        .testTarget(
            name: "MDLintRulesTests",
            dependencies: ["MDLintRules"]
        ),
        .testTarget(
            name: "MDLintConfigTests",
            dependencies: [
                "MDLintConfig",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
