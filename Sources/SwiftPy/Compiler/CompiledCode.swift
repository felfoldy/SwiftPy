//
//  AsyncCompiler.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-27.
//

import Foundation

/// The result of compiling async-aware Python: either plain compiled code to
/// run directly, or an ``AsyncCode`` await chain to drive asynchronously.
public enum CompiledCode: Sendable {
    case plain(PyObject, mode: CompileMode)
    case async(AsyncCode)
}
