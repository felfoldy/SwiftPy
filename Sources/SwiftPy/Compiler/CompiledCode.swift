//
//  AsyncCompiler.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-27.
//

import Foundation

/// Compiled Python code ready to execute.
public struct CompiledCode: Sendable {
    let code: PyObject
    let mode: CompileMode

    init(_ code: PyObject, mode: CompileMode) {
        self.code = code
        self.mode = mode
    }
}
