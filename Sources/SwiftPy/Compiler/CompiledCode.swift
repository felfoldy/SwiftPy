//
//  AsyncCompiler.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-06-27.
//

import Foundation
#if cpython
import Python
#endif

/// An object of whichever interpreter this build embeds.
#if cpython
public typealias InterpreterObject = PythonObject
#else
public typealias InterpreterObject = PyObject
#endif

/// Compiled Python code ready to execute.
public struct CompiledCode: Sendable {
    let code: InterpreterObject
    let mode: CompileMode

    init(_ code: InterpreterObject, mode: CompileMode) {
        self.code = code
        self.mode = mode
    }
}
