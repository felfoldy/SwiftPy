// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PythonTools",
    products: [
        .library(
            name: "PythonTools",
            targets: ["PythonTools", "pocketpy"]
        ),
    ],
    targets: [
        .target(
            name: "PythonTools",
            dependencies: ["pocketpy"]
        ),
        .testTarget(
            name: "PythonToolsTests",
            dependencies: ["PythonTools"]
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
