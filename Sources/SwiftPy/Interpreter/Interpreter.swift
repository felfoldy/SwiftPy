//
//  Interpreter.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import pocketpy
import Foundation

public enum InterpreterError: LocalizedError {
    case runtimeError(String)
    
    public var errorDescription: String? {
        switch self {
        case let .runtimeError(description):
            return description
        }
    }
}

@MainActor
public final class Interpreter {
    public static let shared = Interpreter()
    
    /// IO stream for console output.
    public static var output: any IOStream = DefaultIOStream()

    /// Bundles to import from python scripts.
    public static var bundles = [Bundle.module]

    public var replLines = [String]()
    
    @usableFromInline
    static var isFailed = false

    @usableFromInline
    static var lastFailure: String?
    
    let profiler = SignpostProfiler("Python")

    init() {
        py_initialize()
        
        py_callbacks().pointee.print = { cString in
            guard let cString else { return }
            let str = String(cString: cString)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if str.isEmpty { return }
            
            if Interpreter.isFailed {
                Interpreter.output.stderr(str)
                Interpreter.isFailed = false
                Interpreter.lastFailure = str
            } else {
                Interpreter.output.stdout(str)
            }
        }
        
        log.info("pocketpy [\(PK_VERSION)] initialized")
        
        py_callbacks().pointee.importfile = { cFilename in
            guard let cFilename else { return nil }
            
            let filename = String(cString: cFilename)
            if let content = Interpreter.importFromBundle(name: filename) {
                return strdup(content)
            }

            return nil
        }
        
        let builtins = py_getmodule("builtins")
        // Remove exit, maybe do a custom action instead later?
        py_deldict(builtins, py_name("exit"))
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String, filename: String = "<string>", mode: py_CompileMode = EXEC_MODE) throws {
        try Interpreter.printErrors {
            let isCompiled = py_compile(code, filename, mode, false)
            guard isCompiled else { return false }
            
            PyAPI.r0?.assign(py_retval())

            let function: PyAPI.Reference? = mode == EVAL_MODE ? .functions.eval : .functions.exec

            profiler.begin()
            let isExecuted = py_call(function, 1, PyAPI.r0)
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
    
    /// Evaluates the expression and returns the result.
    ///
    /// - Parameter expression: Expression to evaluate.
    /// - Returns: The result of the expression.
    static func evaluate(_ expression: String) -> PyAPI.Reference? {
        try? shared.execute(expression, mode: EVAL_MODE)

        PyAPI.r0?.assign(PyAPI.returnValue)
        return PyAPI.r0
    }

    /// Completes the text.
    ///
    /// - Note: Writes to R0 register.
    ///
    /// - Parameter text: Text to complete.
    /// - Returns: Array of possible results.
    static func complete(_ text: String) -> [String] {
        let module = Interpreter.shared.module("interpreter")
        let completions = module?["completions"]
        
        let result = try? PyAPI.call(
            completions,
            text.toRegister(0)
        )
        return [String](result) ?? []
    }
}
