//
//  AsyncCompiler.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-27.
//

import Foundation

/// Turns async-aware Python source into a chain of compiled ``AsyncCode``
/// values, compiling every link of the await chain up front.
enum AsyncCompiler {
    @MainActor
    static func compile(
        _ source: String,
        filename: String,
        mode: CompileMode
    ) throws(PythonError) -> AsyncCode {
        let parsed = AsyncParser(source)

        let continuation: AsyncCode?
        if let continuationCode = parsed.continuationCode {
            continuation = try compile(continuationCode, filename: filename, mode: mode)
        } else {
            continuation = nil
        }

        let compiledCode = PyObject(try py.compile(source: parsed.code, filename: filename, mode: mode))

        return AsyncCode(
            compiledCode: compiledCode,
            continuation: continuation,
            call: parsed.call,
        )
    }
}
