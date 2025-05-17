//
//  Interpreter.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import pocketpy
import Foundation

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
        // Remove exit, maybe do a custom action instead later?
        py_deldict(builtins, py_name("exit"))
        
        if #available(macOS 15, iOS 18, *) {
            Interpreter.bindModule("views", [
                PythonView.self,
            ])
            
            hookStoragesModule()
        }
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String, filename: String = "<string>", mode: py_CompileMode = EXEC_MODE) throws {
        try Interpreter.printErrors {
            py_compile(code, filename, mode, false)
        }
        
        let code = PyAPI.returnValue.toStack
        
        try Interpreter.printErrors {
            let function: PyAPI.Reference? = mode == EVAL_MODE ? .functions.eval : .functions.exec

            profiler.begin()
            let isExecuted = py_call(function, 1, code.reference)
            profiler.end()

            Interpreter.output.executionTime(
                profiler.executionTime
            )

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
        
        return nil
    }

    func repl(input: String) {
        for line in input.components(separatedBy: .newlines) {
            if line.isEmpty, !replLines.isEmpty {
                let joinedBuffer = replLines.joined(separator: "\n")
                try? execute(joinedBuffer, filename: "<stdin>", mode: SINGLE_MODE)
                replLines.removeAll()
            }

            guard let lastChar = line.last else {
                continue
            }

            if !replLines.isEmpty || ":({[".contains(lastChar) {
                replLines.append(line)
                continue
            }
            
            try? execute(line, filename: "<stdin>", mode: SINGLE_MODE)
        }
    }
    
    @inlinable
    static func printErrors(_ call: () -> Bool) throws {
        let p0 = py_peek(0)
        if call() { return }
        Interpreter.isFailed = true
        py_printexc()
        py_clearexc(p0)
        if let lastFailure {
            throw InterpreterError.runtimeError(lastFailure)
        }
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
            throw InterpreterError.runtimeError(lastFailure)
        }
        return false
    }
}

public extension Interpreter {
    /// Runs a code in execution mode.
    ///
    /// Does not output the input to the console.
    /// - Parameter code: Code to execute.
    static func execute(_ code: String) {
        try? shared.execute(code)
    }

    /// Runs a code in execution mode.
    /// 
    /// Performs profiling and outputs the input to the console.
    /// - Parameter code: Code to execute.
    static func run(_ code: String) {
        output.input(code)
        try? shared.execute(code, filename: "<string>", mode: EXEC_MODE)
    }

    static func asyncRun(_ code: String) async {
        output.input(code)
        await shared.asyncExecute(code)
    }

    /// Interactive interpreter input.
    ///
    /// - Parameter input: Input to run.
    static func input(_ input: String) {
        output.input(input)
        shared.repl(input: input)
    }

    /// Evaluates the expression, casts to the given type and returns the result.
    ///
    /// - Parameter expression: Expression to evaluate.
    /// - Returns: The result of the expression.
    static func evaluate<Result: PythonConvertible>(_ expression: String) -> Result? {
        do {
            try shared.execute(expression, mode: EVAL_MODE)
            let result = PyAPI.returnValue.toStack
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
        let textStack = text.toStack
        
        let result = try? PyAPI.call(
            completions,
            textStack.reference
        )
        return [String](result) ?? []
    }

    /// Registers a new Python module by binding Swift types and loading optional source code.
    ///
    /// - Parameters:
    ///   - name: The name of the module to register.
    ///   - types: An array of types conforming to ``PythonBindable`` to expose to Python.
    ///
    /// This function enables dynamic module creation by:
    /// 1. Registering Swift types as Python classes.
    /// 2. Optionally loading and executing a `.py` file with the same name from ``bundles``.
    /// 3. Setting module-level metadata such as documentation.
    ///
    /// ### Example:
    /// ```swift
    /// Interpreter.bindModule("my_module", [MySwiftClass.self])
    /// ```
    /// This exposes `MySwiftClass` to Python and runs `my_module.py` if found in the app bundle.
    static func bindModule(_ name: String, _ types: [PythonBindable.Type]) {
        moduleBuilders[name] = { module in
            // Set types.
            for type in types {
                let pyType = type.pyType
                module?.setAttribute(pyType.name, pyType.object)
            }

            // Load source.
            if let content = Interpreter.importFromBundle(name: name + ".py") {
                try? Interpreter.printErrors {
                    py_exec(content, name, EXEC_MODE, module)
                }
            }

            // Add module.__doc__.
            let interpreter = Interpreter.shared.module("interpreter")
            let bind_interfaces = interpreter?["bind_interfaces"]
            
            _ = try? PyAPI.call(
                bind_interfaces,
                module
            )
        }
    }
}
