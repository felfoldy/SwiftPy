//
//  Interpreter.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import Foundation
import SwiftUI
import OSLog

/// A Swift interface for interacting with the embedded Python interpreter.
///
/// This class provides static methods to run scripts, evaluate expressions,
/// bind Swift types as Python modules, and handle REPL input.
///
/// ### Examples:
/// Execute a script with ``run(_:filename:mode:)-1ohhm``:
/// ```swift
/// Interpreter.run("print('Hello from Python')")
/// ```
///
/// Evaluate an expression with ``evaluate(_:)``:
/// ```swift
/// let result: Int? = Interpreter.evaluate("3 + 6")
/// ```
///
@MainActor
public final class Interpreter {
    /// Presents a SwiftUI view in the local console, one view at a time.
    public static var onDisplay: (AnyView) -> Void = { _ in }
    
    public static var silenceErrors = false

    @usableFromInline
    static let shared = Interpreter()

    var moduleFactory: [String: (PyRef?) -> Void] = [:]

    /// Python source registered from bundles, keyed by file name (e.g. `"module.py"`).
    var registeredSources: [String: String] = [:]

    let profiler = OSSignposter(logger: Logger(
        OSLog(subsystem: "com.felfoldy.SwiftPy",
              category: .pointsOfInterest)
    ))

    private var relays: OutputRelays?
    let builtinExec: PyAPI.CFunction
    let builtinEval: PyAPI.CFunction

    @usableFromInline
    let connection = LocalInterpreterConnection()

    init() {
        // Store builtin exec and eval.
        builtinExec = py.getbuiltin("exec")!.pointee._cfunc
        builtinEval = py.getbuiltin("eval")!.pointee._cfunc

        setCallbacks()
        
        log.info("pocketpy [\(py.version)] initialized")

        // Change default working directory to the applications Documents directory.
        let documentsPath = URL.documentsDirectory.path
        FileManager.default.changeCurrentDirectoryPath(documentsPath)

        relays = OutputRelays(interpreter: self)
        
        bindBuiltins()
        bindOS()
        bindAsyncio()
        bindSys()
        bindInterpreter()
        bindPathlib()
        bindP2P()
        bindStorages()

        // Register bundled source-only modules.
        bindModule("keyword", in: .module)
        bindModule("rlcompleter", in: .module)
    }

    @discardableResult
    func execute(_ code: PyObject, mode: CompileMode = .execution) throws(PythonError) -> PyObject {
        let retval = try PyAPI.convertRetval(code.reference) { code in
            let function = mode == .evaluation ? builtinEval : builtinExec
            let isExecuted = profiler.withIntervalSignpost("Python") {
                function(1, code)
            }

            return isExecuted
        }

        return py.retain(retval)
    }
}

public extension Interpreter {
    /// Compiles and runs source synchronously.
    ///
    /// Only plain code is run; source with top-level async is ignored.
    /// Compilation and execution failures are silently ignored.
    /// - Parameters:
    ///   - source: The Python source to execute.
    ///   - filename: Name used to identify the source in tracebacks. Defaults to `"<string>"`.
    ///   - mode: The compilation mode to use. Defaults to `.execution`.
    static func run(_ source: String, filename: String = "<string>", mode: CompileMode = .single) {
        guard let code = try? compile(source, filename: filename, mode: mode) else { return }
        _ = try? execute(code)
    }

    /// Compiles and runs source, awaiting top-level async.
    ///
    /// Source with top-level async is awaited; other source runs synchronously.
    /// Compilation and execution failures are silently ignored.
    ///
    /// ### Example:
    /// Run a script that uses top-level `await`:
    /// ```swift
    /// await Interpreter.run("""
    /// import asyncio
    ///
    /// await asyncio.sleep(3)
    /// print("Ran for at least 3 seconds")
    /// """)
    /// ```
    /// - Parameters:
    ///   - source: The Python source to execute.
    ///   - filename: Name used to identify the source in tracebacks. Defaults to `"<string>"`.
    ///   - mode: The compilation mode to use. Defaults to `.execution`.
    static func run(_ source: String, filename: String = "<string>", mode: CompileMode = .single) async {
        guard let code: CompiledCode = try? compile(source, filename: filename, mode: mode) else {
            return
        }
        _ = try? await execute(code)
    }
    
    /// Compiles Python source into reusable ``CompiledCode``.
    ///
    /// - Parameters:
    ///   - source: The Python source to compile.
    ///   - filename: Name used to identify the source in tracebacks. Defaults to `"<string>"`.
    ///   - mode: The compilation mode to use. Defaults to `.execution`.
    /// - Returns: The compiled code, ready to be executed.
    /// - Throws: A ``PythonError`` if the source fails to compile.
    static func compile(
        _ source: String,
        filename: String = "<string>",
        mode: CompileMode = .execution
    ) throws(PythonError) -> CompiledCode {
        try shared.compile(source, filename: filename, mode: mode)
    }
    
    /// Executes compiled code synchronously.
    ///
    /// Only plain code can be run synchronously; passing asynchronous code
    /// throws an error. Use the `async` overload to run async code.
    /// Use ``compile(_:filename:mode:)`` to produce the ``CompiledCode``.
    ///
    /// - Parameter code: The compiled code to execute.
    /// - Throws: A ``PythonError`` if the code is asynchronous or execution fails.
    static func execute(_ code: CompiledCode) throws(PythonError) -> PyObject? {
        if case let .plain(code, mode) = code {
            return try shared.execute(code, mode: mode)
        }
        throw .AssertionError("Cannot execute async code")
    }

    /// Executes compiled code, awaiting asynchronous code.
    ///
    /// Plain code runs synchronously, while asynchronous code is awaited.
    /// Use ``compile(_:filename:mode:)`` to produce the ``CompiledCode``.
    ///
    /// - Parameter code: The compiled code to execute.
    /// - Throws: A ``PythonError`` if execution fails.
    @discardableResult
    static func execute(_ code: CompiledCode) async throws(PythonError) -> PyObject? {
        switch code {
        case let .plain(code, mode):
            return try shared.execute(code, mode: mode)

        case let .async(code):
            try await shared.execute(code)
            return nil
        }
    }

    /// Evaluates the expression, casts to the given type and returns the result.
    ///
    /// - Parameter expression: Expression to evaluate.
    /// - Returns: The result of the expression.
    static func evaluate<Result: PythonConvertible>(_ expression: String) -> Result? {
        do {
            let code = try shared.compile(expression, mode: .evaluation)
            if case let .plain(code, _) = code {
                try shared.execute(code, mode: .evaluation)
            }
            let result = py.retain(py.retval)
            return try Result.cast(result.reference)
        } catch {
            return nil
        }
    }

    /// Provides autocomplete suggestions for a given text.
    ///
    /// - Parameter text: Text to complete.
    /// - Returns: An array of string completions.
    static func complete(_ text: String) -> [String] {
        let result: [String]? = try? py.module("interpreter")?.completions?(text)
        return result ?? []
    }

    /// Executes a block with Python error output suppressed.
    ///
    /// - Parameter block: A throwing closure to execute with errors silenced.
    /// - Returns: The value returned by `block`.
    /// - Throws: Any error thrown by `block`.
    @discardableResult
    static func silenceErrors<Result, Failure: Error>(
        block: () throws(Failure) -> Result
    ) throws(Failure) -> Result {
        silenceErrors = true
        defer { silenceErrors = false }
        return try block()
    }

    static var connection: any InterpreterConnection {
        shared.connection
    }
}
