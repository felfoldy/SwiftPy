//
//  CPythonBridge.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

#if cpython
import Foundation

extension Interpreter {
    func startCPython() {
        // Touching `cpy` starts CPython, which also keeps the linker from
        // dropping it: a static libpython contributes nothing unless something
        // references it.
        log.info("CPython [\(cpy.version)] initialized")
        redirectCPythonOutput()
    }

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

    /// Runs on ``PythonActor``; main is free meanwhile.
    @discardableResult
    nonisolated func executeWithCPython(
        _ code: PyObject,
        globals: PyObject? = nil,
        locals: PyObject? = nil
    ) async throws(PythonError) -> PyObject {
        do {
            return try await PyRuntime.execute(code, globals: globals, locals: locals)
        } catch {
            throw PythonError.RuntimeError("\(error)").withTraceback("\(error)")
        }
    }

    /// Points CPython's stdout and stderr at the sink pocketpy's `print` uses,
    /// so both interpreters reach the console the same way. Called on whichever
    /// thread runs Python, inside the execution's task, so the task-local sink
    /// is in reach.
    func redirectCPythonOutput() {
        try? PyRuntime.redirectOutput { text in
            if let output = InterpreterExecutionContext.current.output {
                output(text)
            } else {
                fputs(text, stdout)
                fflush(stdout)
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
