// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftPy",
    platforms: [.macOS(.v11), .iOS(.v14), .visionOS(.v2)],
    products: [
        .library(
            name: "SwiftPy",
            targets: [
                "SwiftPy",
                // TODO: Remove when the lib will be complete.
                "pocketpy",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/felfoldy/LogTools.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "SwiftPy",
            dependencies: [
                "pocketpy",
                "SwiftPyMacros",
                "LogTools"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftPyTests",
            dependencies: [
                "SwiftPy",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),
        .macro(
            name: "SwiftPyMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "pocketpy",
            sources: [
                "./src/pocketpy.c",
                "./src/pocketpy_extensions.c",
            ],
            cxxSettings: [
                .headerSearchPath("./include"),
            ]
        )
    ]
)
