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
    func startCPython() {
        // Touching `cpy` starts CPython, which also keeps the linker from
        // dropping it: a static libpython contributes nothing unless something
        // references it.
        PocketPython.log.info("CPython [\(cpy.version)] initialized")
        redirectCPythonOutput()
    }

    func compileWithCPython(
        _ source: String,
        filename: String,
        mode: CompileMode
    ) throws(PocketPython.PythonError) -> CompiledCode {
        do {
            let code = try PythonCompiler.compile(source, filename: filename, mode: mode.cpython)
            return CompiledCode(code, mode: mode)
        } catch {
            throw PocketPython.PythonError.SyntaxError("\(error)").withTraceback("\(error)")
        }
    }

    @discardableResult
    func executeWithCPython(
        _ code: Python.PyObject,
        globals: Python.PyObject? = nil,
        locals: Python.PyObject? = nil
    ) throws(PocketPython.PythonError) -> Python.PyObject {
        do {
            return try PyRuntime.execute(code, globals: globals, locals: locals)
        } catch {
            throw PocketPython.PythonError.RuntimeError("\(error)").withTraceback("\(error)")
        }
    }

    /// Points CPython's stdout and stderr at the sink pocketpy's `print` uses,
    /// so both interpreters reach the console the same way.
    func redirectCPythonOutput() {
        try? PyRuntime.redirectOutput { text in
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
