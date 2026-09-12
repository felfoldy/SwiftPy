// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport
import Foundation

let package = Package(
    name: "SwiftPy",
    // 15.4 / 18.4 / 2.4 are what isolated `deinit` needs.
    platforms: [.macOS("15.4"), .iOS("18.4"), .visionOS("2.4")],
    products: [
        .library(
            name: "SwiftPy",
            targets: [
                "SwiftPy",
            ]
        ),
    ],
    // One backend at a time; enabling both links pocketpy for nothing.
    traits: [
        .trait(
            name: "cpython",
            description: "Embed CPython from libswiftpy/cpython."
        ),
        .trait(
            name: "pocketpy",
            description: "Embed the bundled pocketpy instead of CPython."
        ),
        .default(enabledTraits: ["cpython"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftPy",
            dependencies: [
                .target(name: "PocketPython", condition: .when(traits: ["pocketpy"])),
                "SwiftPyMacros",
                .product(name: "Python", package: "cpython", condition: .when(traits: ["cpython"])),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftPyTests",
            dependencies: [
                "SwiftPy",
                "SwiftPyMacros",
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
            name: "PocketPython",
            dependencies: ["pocketpy"]
        ),
        .target(
            name: "pocketpy",
            sources: [
                "./src/pocketpy.c",
            ],
            cSettings: [
                .headerSearchPath("./include"),
                .define("PK_ENABLE_THREADS", to: "0"),
                .define("PK_ENABLE_WATCHDOG", to: "1"),
                .define("PK_ENABLE_ASYNC_AWAIT", to: "1"),
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

// Only pulled in by the "cpython" trait; SwiftPM prunes it from the graph
// entirely when the trait is off. The package links a libpython that its own
// Swift/build.sh stages and does not commit, so a fresh checkout has nothing to
// link against until that script has been run inside it — point
// SWIFTPY_CPYTHON_PATH at a local checkout that is already built.
if let cpython = ProcessInfo.processInfo.environment["SWIFTPY_CPYTHON_PATH"] {
    package.dependencies.append(.package(path: cpython))
} else {
    package.dependencies.append(
        .package(url: "https://github.com/libswiftpy/cpython.git", branch: "main")
    )
}

// Only pull in swift-docc-plugin when explicitly building documentation.
if ProcessInfo.processInfo.environment["SWIFTPY_BUILD_DOCS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
    )
}
