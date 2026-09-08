//
//  CPythonBridge.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

#if cpython
import Foundation
import Python

extension Interpreter {
    func compileWithCPython(
        _ source: String,
        filename: String,
        mode: CompileMode
    ) throws(PythonError) -> CompiledCode {
        do {
            let code = try PythonCompiler.compile(source, filename: filename, mode: mode.cpython)
            return CompiledCode(code, mode: mode)
        } catch {
            throw PythonError.SyntaxError("\(error)").withTraceback("\(error)")
        }
    }

    @discardableResult
    func executeWithCPython(
        _ code: PythonObject,
        globals: PythonObject? = nil,
        locals: PythonObject? = nil
    ) throws(PythonError) -> PythonObject {
        do {
            return try Python.execute(code, globals: globals, locals: locals)
        } catch {
            throw PythonError.RuntimeError("\(error)").withTraceback("\(error)")
        }
    }

    /// Points CPython's stdout and stderr at the sink pocketpy's `print` uses,
    /// so both interpreters reach the console the same way.
    func redirectCPythonOutput() {
        try? Python.redirectOutput { text in
            MainActor.assumeIsolated {
                if let output = InterpreterExecutionContext.current.output {
                    output(text)
                } else {
                    fputs(text, stdout)
                    fflush(stdout)
                }
            }
        }
    }
}

extension CompileMode {
    var cpython: PythonCompiler.Mode {
        switch self {
        case .execution: .execution
        case .evaluation: .evaluation
        case .single: .single
        }
    }
}
#endif
