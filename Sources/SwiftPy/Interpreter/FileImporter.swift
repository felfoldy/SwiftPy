//
//  FileImporter.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-06-30.
//

import Foundation
import Synchronization

/// Resolves Python source for a file name from a particular location.
/// Nonisolated: CPython imports on whichever thread runs the code.
protocol FileImporter: Sendable {
    /// Returns the contents of `name` if this importer can resolve it.
    ///
    /// - Parameter name: The file name to resolve (e.g. `"module.py"`).
    /// - Returns: The file contents, or `nil` if not found.
    func source(name: String) -> String?
}

/// Sources registered from bundles, readable from any thread.
final class SourceStore: Sendable {
    private let storage = Mutex<[String: String]>([:])

    subscript(name: String) -> String? {
        storage.withLock { $0[name] }
    }

    var names: [String] {
        storage.withLock { Array($0.keys) }
    }

    func register(_ source: String, as name: String) {
        storage.withLock { $0[name] = source }
    }
}

struct RegisteredSourceImporter: FileImporter {
    func source(name: String) -> String? {
        Interpreter.registeredSources[name]
    }
}

struct WorkingDirectoryImporter: FileImporter {
    func source(name: String) -> String? {
        try? String(contentsOf: URL.currentDirectory().appending(path: name), encoding: .utf8)
    }
}

struct SitePackagesImporter: FileImporter {
    func source(name: String) -> String? {
        guard let sitePackages = try? URL.sitePackages() else {
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
    nonisolated static let fileImporters: [FileImporter] = [
        WorkingDirectoryImporter(),
        RegisteredSourceImporter(),
        SitePackagesImporter(),
    ]

    /// Resolves Python source for the given file name by consulting
    /// ``fileImporters`` in order, returning the first match.
    ///
    /// - Parameter name: The file name to resolve (e.g. `"module.py"`).
    /// - Returns: The file contents, or `nil` if no source could be found.
    nonisolated static func importFromSource(name: String) -> String? {
        for importer in fileImporters {
            if let content = importer.source(name: name) {
                return content
            }
        }
        return nil
    }
}

public extension Interpreter {
    /// Returns the source of an importable module, or `nil` when none resolves:
    /// a native module bound in Swift, or an unknown name.
    ///
    /// - Parameter name: A module name (`"mylib"`), a dotted submodule name
    ///   (`"console.notebook"`), or a file name (`"mylib.py"`).
    nonisolated static func source(name: String) -> String? {
        guard !name.hasSuffix(".py") else {
            return importFromSource(name: name)
        }

        // Dotted submodules are registered as slashed paths.
        let path = name.replacingOccurrences(of: ".", with: "/")
        return importFromSource(name: path + ".py")
    }
}
