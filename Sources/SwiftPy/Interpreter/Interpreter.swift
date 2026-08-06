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

    /// CPU-time budget for an execution before the interpreter aborts it with
    /// a `TimeoutError`.
    ///
    /// Defaults to `1000`. Set to `nil` to disable the watchdog and allow
    /// unbounded execution.
    public static var timeout: Int? = 1000

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

    private var _activeConnection: (any InterpreterConnection)?
    private var hostPeer: Peer?
    private var hostEventTask: Task<Void, Never>?

    var activeConnection: any InterpreterConnection {
        _activeConnection ?? connection
    }

    var registeredModuleNames: [String] {
        let hiddenModules: Set<String> = [
            "help",
            "keyword",
            "rlcompleter",
        ]
        let nativeModules = moduleFactory.keys
        let sourceModules = registeredSources.keys.map { name in
            name.hasSuffix(".py") ? String(name.dropLast(3)) : name
        }

        return Array(Set(nativeModules).union(sourceModules))
            .filter { name in
                !name.contains(".") && !name.contains("/") && !hiddenModules.contains(name)
            }
            .sorted()
    }

    init() {
        // Store builtin exec and eval.
        builtinExec = py.getbuiltin("exec")!.pointee._cfunc
        builtinEval = py.getbuiltin("eval")!.pointee._cfunc

        bindFunctools()
        
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
        bindKeyring()
        bindStorage()

        // Register bundled source-only modules.
        bindModule("help", in: .module)
        bindModule("keyword", in: .module)
        bindModule("rlcompleter", in: .module)
    }

    func compile(
        _ source: String,
        filename: String = "<string>",
        mode: CompileMode = .execution
    ) throws(PythonError) -> CompiledCode {
        let compiledCode = PyObject(try py.compile(source: source, filename: filename, mode: mode))
        return CompiledCode(compiledCode, mode: mode)
    }

    @discardableResult
    func execute(
        _ code: PyObject,
        globals: PyObject? = nil,
        locals: PyObject? = nil,
        mode: CompileMode = .execution
    ) throws(PythonError) -> PyObject {
        if let globals {
            let function = py.getbuiltin(mode == .evaluation ? "eval" : "exec")!
            let retval = try py.call(function, args: code, globals, locals ?? globals)
            return py.retain(retval)
        }

        let retval = try PyAPI.convertRetval(code.reference) { code in
            let function = mode == .evaluation ? builtinEval : builtinExec
            let isExecuted = profiler.withIntervalSignpost("Python") {
                if let timeout = Interpreter.timeout { py.beginWatchdog(milliseconds: timeout) }
                defer { py.endWatchdog() }
                return function(1, code)
            }

            return isExecuted
        }

        return py.retain(retval)
    }

    /// Reports a Python error to the local interpreter output as `stderr`.
    func report(_ error: PythonError) {
        guard let traceback = error.traceback else { return }
        connection.send(id: 0, .stderr(text: traceback))
    }
}

public extension Interpreter {
    /// Enables relaying process `stderr` output to the local interpreter output.
    static func enableStderrRelay() {
        shared.relays?.enableStderrRelay()
    }

    /// Compiles and runs source synchronously.
    ///
    /// Only plain code is run; source with top-level async is ignored.
    /// Errors are reported to the interpreter's output as `stderr`.
    /// - Parameters:
    ///   - source: The Python source to execute.
    ///   - filename: Name used to identify the source in tracebacks. Defaults to `"<string>"`.
    ///   - mode: The compilation mode to use. Defaults to `.execution`.
    static func run(_ source: String, filename: String = "<string>", mode: CompileMode = .single) {
        do {
            let code = try compile(source, filename: filename, mode: mode)
            try execute(code)
        } catch {
            shared.report(error)
        }
    }

    /// Compiles and runs source, awaiting top-level async.
    ///
    /// Source with top-level async is awaited; other source runs synchronously.
    /// Errors are reported to the interpreter's output as `stderr`.
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
        do {
            let code = try compile(source, filename: filename, mode: mode)
            try await execute(code)
        } catch {
            shared.report(error)
        }
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
    /// Use ``compile(_:filename:mode:)`` to produce the ``CompiledCode``.
    ///
    /// - Parameters:
    ///   - code: The compiled code to execute.
    ///   - globals: The global namespace. Defaults to the shared interpreter state.
    ///   - locals: The local namespace. Defaults to the same mapping as `globals`.
    /// - Throws: A ``PythonError`` if execution fails.
    @discardableResult
    static func execute(
        _ code: CompiledCode,
        globals: PyObject? = nil,
        locals: PyObject? = nil
    ) throws(PythonError) -> PyObject? {
        try shared.execute(code.code, globals: globals, locals: locals, mode: code.mode)
    }

    /// Executes compiled code, awaiting any generator the code returns.
    ///
    /// If the code returns a generator (e.g. from a top-level `await`), it is
    /// iterated asynchronously as an ``AsyncTask``.
    /// Use ``compile(_:filename:mode:)`` to produce the ``CompiledCode``.
    ///
    /// - Parameters:
    ///   - code: The compiled code to execute.
    ///   - globals: The global namespace. Defaults to the shared interpreter state.
    ///   - locals: The local namespace. Defaults to the same mapping as `globals`.
    /// - Throws: A ``PythonError`` if execution fails.
    @discardableResult
    static func execute(
        _ code: CompiledCode,
        globals: PyObject? = nil,
        locals: PyObject? = nil
    ) async throws(PythonError) -> PyObject? {
        let result = try shared.execute(code.code, globals: globals, locals: locals, mode: code.mode)
        if py.istype(result.reference, type: .generator) {
            let task = try AsyncTask(generator: result)
            return try await task.untilCompletes()
        }
        return result
    }

    /// Evaluates the expression, casts to the given type and returns the result.
    ///
    /// - Parameter expression: Expression to evaluate.
    /// - Returns: The result of the expression.
    static func evaluate<Result: PythonConvertible>(_ expression: String) -> Result? {
        do {
            let code = try shared.compile(expression, mode: .evaluation)
            try shared.execute(code.code, mode: .evaluation)
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
        let result: [String]? = try? py.module("interpreter")?._completions?(text)
        return result ?? []
    }

    static var connection: any InterpreterConnection {
        shared.activeConnection
    }

    /// Advertises this device as a remote interpreter host under `name`.
    static func host(name: String) {
        let peer = Peer(name: name)
        let connection = shared.connection
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        peer.messageReceived { data in
            guard let command = try? decoder.decode(ConsoleCommand.self, from: data) else { return }
            Task { await connection.perform(command) }
        }

        shared.hostEventTask?.cancel()
        shared.hostEventTask = Task {
            for await event in await connection.events {
                guard let data = try? encoder.encode(event) else { continue }
                try? peer.send(data: data)
            }
        }

        peer.advertise()
        shared.hostPeer = peer
    }

    /// Replaces the active connection with a remote connection to `target`.
    static func connect(to target: String) {
        shared._activeConnection = RemoteInterpreterConnection(target: target)
    }
}
