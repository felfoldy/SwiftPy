// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport
import Foundation

let package = Package(
    name: "SwiftPy",
    platforms: [.macOS(.v13), .iOS(.v16), .visionOS(.v1)],
    products: [
        .library(
            name: "SwiftPy",
            targets: [
                "SwiftPy",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftPy",
            dependencies: [
                "pocketpy",
                "SwiftPyMacros",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftPyTests",
            dependencies: [
                "SwiftPy",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
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
            ],
            cSettings: [
                .headerSearchPath("./include"),
                .define("PK_ENABLE_THREADS", to: "0")
            ]
        ),
        .plugin(
            name: "UpdatePocketPy",
            capability: .command(
                intent: .custom(verb: "update-pocketpy", description: "Update pocketpy"),
                permissions: [
                    .allowNetworkConnections(scope: .all(), reason: "Download latest pocketpy"),
                    .writeToPackageDirectory(reason: "Update pocketpy")
                ]
            )
        ),
    ]
)

// Only pull in swift-docc-plugin when explicitly building documentation
// (the CI docs workflow sets SWIFTPY_BUILD_DOCS). This keeps the plugin and
// its SymbolKit dependency out of SwiftPy's default graph, so packages that
// depend on SwiftPy don't resolve them transitively.
if ProcessInfo.processInfo.environment["SWIFTPY_BUILD_DOCS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
    )
}
