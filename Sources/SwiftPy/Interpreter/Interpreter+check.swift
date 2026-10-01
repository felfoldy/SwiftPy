//
//  Interpreter+check.swift
//  SwiftPy
//

import Foundation

extension Interpreter {
    /// mypy's diagnostics for `source`, read as the code that follows
    /// `prelude`. Empty where mypy isn't available, or it failed.
    static func check(_ source: String, after prelude: String) async -> [Diagnostic] {
        #if cpython
        // Started first: PythonActor's thread needs a running interpreter.
        _ = await MainActor.run { Interpreter.shared }
        return await checkWithMypy(source, after: prelude)
        #else
        []
        #endif
    }
}

#if cpython
import mypy

extension Interpreter {
    /// Where mypy's incremental cache lives between launches.
    nonisolated static let mypyCache = URL.cachesDirectory.appending(path: "mypy", directoryHint: .isDirectory)

    @PythonActor
    private static var addedMypy = false

    // On the Python thread: mypy takes from tens of milliseconds to seconds,
    // which main can't spare.
    @PythonActor
    private static func checkWithMypy(_ source: String, after prelude: String) -> [Diagnostic] {
        do {
            if !addedMypy {
                for path in PythonModule.mypy.searchPaths {
                    try PyRuntime.addSearchPath(path)
                }
                addedMypy = true
            }
            guard let typeshed = PythonModule.mypyTypeshed else { return [] }
            let arguments = [source, prelude, mypyCache.path(percentEncoded: false), typeshed].map(pythonLiteral)
            let json = try PyRuntime.evaluate("__import__('interpreter')._check(\(arguments.joined(separator: ", ")))")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([Diagnostic].self, from: Data(json.utf8))
        } catch {
            log.error("check: \(error)")
            return []
        }
    }

    /// A Python string literal: JSON's is one, once `/` isn't escaped.
    nonisolated static func pythonLiteral(_ text: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = (try? encoder.encode(text)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
