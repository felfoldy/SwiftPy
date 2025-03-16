//
//  plugin.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-16.
//

import Foundation
import PackagePlugin

@main
struct UpdatePocketPy: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let url = URL(string: "https://github.com/pocketpy/pocketpy/releases/latest/download")!

        let pocketpy_h = try String(
            contentsOf:  url.appending(path: "pocketpy.h"),
            encoding: .utf8
        )
        // Insert extensions.
        .appending(#"#include "pocketpy_extensions.h""#)
        
        let pocketpy_c = try String(
            contentsOf: url.appending(path: "pocketpy.c"),
            encoding: .utf8
        )
        
        let outUrl = context.package.directoryURL
            .appending(path: "Sources/pocketpy")

        try pocketpy_h.write(
            to: outUrl.appending(path: "include/pocketpy.h"),
            atomically: true,
            encoding: .utf8
        )

        try pocketpy_c.write(
            to: outUrl.appending(path: "src/pocketpy.c"),
            atomically: true,
            encoding: .utf8
        )
    }
}
