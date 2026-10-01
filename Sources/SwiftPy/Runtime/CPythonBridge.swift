//
//  CPythonBridge.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

#if cpython
import Foundation
import Synchronization

extension Interpreter {
    /// The context id of the code ``PythonActor`` is running, while it does.
    /// A stop interrupts that one only: a cell queued behind it must not be
    /// the one to die.
    nonisolated static let executing = Mutex<UInt64?>(nil)

    /// Raises `KeyboardInterrupt` in the execution `contextId`, if it is the
    /// one running. It lands at the next bytecode; a blocking C call
    /// returns first.
    static func interrupt(contextId: UInt64) {
        Self.executing.withLock { executing in
            if executing == contextId { PyRuntime.interrupt() }
        }
    }

    func startCPython() {
        // Touching `cpy` starts CPython, which also keeps the linker from
        // dropping it: a static libpython contributes nothing unless something
        // references it.
        log.info("CPython [\(cpy.version)] initialized")
        redirectCPythonOutput()
        // The app bundle is read-only, so bytecode compiled from source
        // outside the stdlib zip is kept in Caches instead of rebuilt per launch.
        let pycache = URL.cachesDirectory.appending(path: "pycache").path(percentEncoded: false)
        try? PyRuntime.run("import sys; sys.pycache_prefix = \(Self.pythonLiteral(pycache))")
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
    @PythonActor
    @discardableResult
    func executeWithCPython(
        _ code: PyObject,
        globals: PyObject? = nil,
        locals: PyObject? = nil
    ) async throws(PythonError) -> PyObject {
        Self.executing.withLock { $0 = InterpreterExecutionContext.current.contextId }
        defer {
            // Under the lock, so an interrupt can't land after the code ended
            // and wait for the next cell.
            Self.executing.withLock {
                $0 = nil
                PyRuntime.clearInterrupt()
            }
        }
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
