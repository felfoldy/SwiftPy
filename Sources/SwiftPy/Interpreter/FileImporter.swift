//
//  FileImporter.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-30.
//

import Foundation

/// Resolves Python source for a file name from a particular location.
@MainActor
protocol FileImporter {
    /// Returns the contents of `name` if this importer can resolve it.
    ///
    /// - Parameter name: The file name to resolve (e.g. `"module.py"`).
    /// - Returns: The file contents, or `nil` if not found.
    func source(name: String) -> String?
}

struct RegisteredSourceImporter: FileImporter {
    func source(name: String) -> String? {
        Interpreter.shared.registeredSources[name]
    }
}

struct WorkingDirectoryImporter: FileImporter {
    func source(name: String) -> String? {
        try? String(contentsOf: Path.cwd().url.appending(path: name), encoding: .utf8)
    }
}

struct SitePackagesImporter: FileImporter {
    func source(name: String) -> String? {
        guard let sitePackages = try? Path.sitePackages().url else {
            return nil
        }

        // Direct child of site-packages.
        if let content = try? String(contentsOf: sitePackages.appending(path: name), encoding: .utf8) {
            return content
        }

        // One level deep: /site-packages/*/name
        let contents = try? FileManager.default.contentsOfDirectory(
            at: sitePackages,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for url in contents ?? [] {
            if let content = try? String(contentsOf: url.appending(path: name), encoding: .utf8) {
                return content
            }
        }
        return nil
    }
}

extension Interpreter {
    /// Importers consulted in order when resolving Python source.
    static let fileImporters: [FileImporter] = [
        WorkingDirectoryImporter(),
        RegisteredSourceImporter(),
        SitePackagesImporter(),
    ]

    /// Resolves Python source for the given file name by consulting
    /// ``fileImporters`` in order, returning the first match.
    ///
    /// - Parameter name: The file name to resolve (e.g. `"module.py"`).
    /// - Returns: The file contents, or `nil` if no source could be found.
    static func importFromSource(name: String) -> String? {
        for importer in fileImporters {
            if let content = importer.source(name: name) {
                return content
            }
        }
        return nil
    }
}
