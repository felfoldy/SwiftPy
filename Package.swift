// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PythonTools",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "PythonTools",
            targets: ["PythonTools", "pocketpy"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .target(
            name: "PythonTools",
            dependencies: ["pocketpy", "PythonToolsMacros"]
        ),
        .testTarget(
            name: "PythonToolsTests",
            dependencies: ["PythonTools"]
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
