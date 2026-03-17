//
//  Interpreter.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import pocketpy
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A Swift interface for interacting with the embedded Python interpreter.
///
/// This class provides static methods to run scripts, evaluate expressions,
/// bind Swift types as Python modules, and handle REPL input.
///
/// ### Examples:
/// Execute a script with ``run(_:)``:
/// ```swift
/// Interpreter.run("print('Hello from Python')")
/// ```
///
/// Evaluate an expression with ``evaluate(_:)``:
/// ```swift
/// let result: Int? = Interpreter.evaluate("3 + 6")
/// ```
///
/// Bind a module with ``bindModule(_:_:)``:
/// ```swift
/// Interpreter.bindModule("my_module", [MySwiftClass.self])
/// ```
@MainActor
public final class Interpreter {
    /// IO stream for console output.
    public static var output: any IOStream = DefaultIOStream()

    /// Bundles to import from python scripts.
    public static var bundles = [Bundle.module]

    @usableFromInline
    static let shared = Interpreter()

    var replLines = [String]()
    
    @usableFromInline
    static var isFailed = false

    @usableFromInline
    static var lastFailure: String?
    
    static var moduleBuilders: [String: (PyAPI.Reference?) -> Void] = [:]
    
    let profiler = SignpostProfiler("Python")

    init() {
        py_initialize()
        
        setCallbacks()
        
        log.info("pocketpy [\(PK_VERSION)] initialized")
        
        let builtins = py_getmodule("builtins")
        py_deldict(builtins, py_name("exit"))
        
        // Change default working directory to the applications Documents directory.
        FileManager.default.changeCurrentDirectoryPath(Path.home())
        
        Interpreter.bindModules()

        if #available(macOS 15, iOS 18, visionOS 2, *) {
            hookStoragesModule()
        }
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String, filename: String, mode: CompileMode = .execution) throws {
        try Interpreter.printErrors {
            py_compile(code, filename, mode.pyMode, false)
        }
        
        let code = PyAPI.returnValue.retained
        
        try Interpreter.printErrors {
            let function: PyAPI.Reference? = mode == .evaluation ? .functions.eval : .functions.exec

            profiler.begin()
            let isExecuted = py_call(function, 1, code.reference)
            profiler.end()

            Interpreter.output.executionTime(profiler.executionTime)

            return isExecuted
        }
    }

    static func importFromBundle(name: String) -> String? {
        for bundle in bundles {
            if let path = bundle.path(forResource: name, ofType: nil) {
                do {
                    return try String(contentsOfFile: path, encoding: .utf8)
                } catch {
                    log.error(error.localizedDescription)
                }
            }
        }

        // Read from [current]/site-packages/...
        if let sitePackage = try? String(contentsOfFile: "\(Path.sitePackages())/\(name)", encoding: .utf8) {
            return sitePackage
        }
        // Read from documents/site-packages/...
        return try? String(contentsOfFile: "\(Path.cwd())/\(name)", encoding: .utf8)
    }
    
    @inlinable
    static func printErrors(_ call: () -> Bool) throws {
        let p0 = py_peek(0)
        if call() { return }
        Interpreter.isFailed = true
        py_printexc()
        py_clearexc(p0)
        if let lastFailure {
            throw PythonError.RuntimeError(lastFailure)
        }
    }
    
    @inlinable
    static func ignoreErrors(_ call: () -> Bool) -> Bool {
        let p0 = py_peek(0)
        if call() { return true }
        py_clearexc(p0)
        return false
    }
    
    @inlinable
    static func printItemError(_ call: @autoclosure () -> Int32) throws -> Bool {
        let p0 = py_peek(0)
        let result = call()
        if result != -1 { return result == 1 }
        Interpreter.isFailed = true
        py_printexc()
        py_clearexc(p0)
        if let lastFailure {
            throw PythonError.RuntimeError(lastFailure)
        }
        return false
    }
}

public extension Interpreter {
    /// Runs a code in execution mode.
    ///
    /// Does not output the input to the console.
    /// - Parameter code: Code to execute.
    static func execute(_ code: String, filename: String = "<string>", mode: CompileMode = .execution) {
        try? shared.execute(code, filename: filename, mode: mode)
    }

    /// Runs a code in execution mode.
    /// 
    /// Performs profiling and outputs the input to the console.
    /// - Parameter code: Code to execute.
    static func run(_ code: String, filename: String = "<string>", mode: CompileMode = .execution) {
        output.input(code)
        try? shared.execute(code, filename: filename, mode: mode)
    }

    static func asyncRun(_ code: String, filename: String = "<string>", mode: CompileMode = .execution) async {
        output.input(code)
        await shared.asyncExecute(code, filename: filename, mode: mode)
    }

    /// Evaluates the expression, casts to the given type and returns the result.
    ///
    /// - Parameter expression: Expression to evaluate.
    /// - Returns: The result of the expression.
    static func evaluate<Result: PythonConvertible>(_ expression: String) -> Result? {
        do {
            try shared.execute(expression, filename: "<string>", mode: .evaluation)
            let result = PyAPI.returnValue.retained
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
        let module = Interpreter.shared.module("interpreter")
        let completions = module?["completions"]
        let textStack = text.retained
        
        let result = try? completions?.call([textStack.reference])
        return [String](result) ?? []
    }

    @available(*, deprecated, renamed: "PyBind.module")
    static func bindModule(_ name: String, _ types: [PythonBindable.Type], block: @escaping (PyAPI.Reference?) -> Void = { _ in }) {
        PyBind.module(name, types, block: block)
    }
}
