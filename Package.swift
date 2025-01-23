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
        .package(url: "https://github.com/felfoldy/LogTools.git", from: "1.0.2")
    ],
    targets: [
        .target(
            name: "SwiftPy",
            dependencies: [
                "pocketpy",
                "PythonToolsMacros",
                "LogTools"
            ]
        ),
        .testTarget(
            name: "PythonToolsTests",
            dependencies: ["SwiftPy"]
        ),
        .macro(
            name: "PythonToolsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "pocketpy",
            sources: [
                "./src/pocketpy.c",
            ],
            cxxSettings: [
                .headerSearchPath("./include"),
            ]
        )
    ]
)
