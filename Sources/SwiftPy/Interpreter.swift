//
//  Interpreter.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import pocketpy
import Foundation
import OSLog

@available(macOS 12.0, iOS 15.0, *)
@MainActor
final class PerformanceMonitor {
    static let standard = PerformanceMonitor()
    
    let signposter: OSSignposter
    var state: OSSignpostIntervalState?
    
    init() {
        signposter = OSSignposter(logger: Logger(OSLog(subsystem: "com.felfoldy.SwiftPy", category: .pointsOfInterest)))
    }
    
    @inlinable static func begin() {
        standard.state = standard.signposter.beginInterval("Python")
    }
    
    @inlinable static func end() {
        if let state = standard.state {
            standard.signposter.endInterval("Python", state)
        }
    }
}

@MainActor
public final class Interpreter {
    public static let shared = Interpreter()
    
    /// IO stream for console output.
    public static var output: any OutputStream = DefaultOutputStream()

    /// Bundles to import from python scripts.
    public static var bundles = [Bundle.module]

    public var replLines = [String]()

    public static var onImport: (String) -> String? = { module in
        log.fault("Tried to import \(module), but  Interpreter.onImport is not set")
        return nil
    }
    
    static var isFailed = false

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
            } else {
                Interpreter.output.stdout(str)
            }
        }
        
        log.info("PocketPython [\(PK_VERSION)] initialized")
        
        py_callbacks().pointee.importfile = { cFilename in
            guard let cFilename else { return nil }
            
            let filename = String(cString: cFilename)
            if let content = Interpreter.importFromBundle(name: filename) {
                return strdup(content)
            }

            guard let content = Interpreter.onImport(filename) else {
                log.fault("Failed to load \(filename)")
                return nil
            }

            return strdup(content)
        }
        
        let builtins = py_getmodule("builtins")
        // Remove exit, maybe do a custom action instead later?
        py_deldict(builtins, py_name("exit"))
        
        execute("""
        from rlcompleter import Completer
        
        _text_to_complete = ''

        def _completions() -> list[str]:
            completer = Completer()

            completion_list = []
            state = 0
            
            # Get completions until no more are found
            while True:
                completion = completer.complete(_text_to_complete, state)
                if completion is None:
                    break
                completion_list.append(completion)
                state += 1
            
            return completion_list
        """)
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String, filename: String = "<string>", mode: py_CompileMode = EXEC_MODE, module: PyAPI.Reference? = nil) {
        let p0 = py_peek(0)
        
        let startTime = DispatchTime.now()

        if #available(macOS 12.0, iOS 15.0, *) {
            PerformanceMonitor.begin()
        }

        let isExecuted = py_exec(code, filename, mode, module)

        if #available(macOS 12.0, iOS 15.0, *) {
            PerformanceMonitor.end()
        }
        
        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        Interpreter.output.executionTime(nanoTime)

        if !isExecuted {
            Interpreter.isFailed = true
            py_printexc()
            py_clearexc(p0)
        }
    }

    static func importFromBundle(name: String) -> String? {
        for bundle in bundles {
            if let path = bundle.path(forResource: name, ofType: nil) {
                do {
                    let content = try String(contentsOfFile: path, encoding: .utf8)
                    log.trace("Imported \(name) from \(bundle.bundleURL.lastPathComponent)")
                    return content
                } catch {
                    log.error(error.localizedDescription)
                }
            }
        }
        
        return nil
    }

    public func repl(input: String) {
        for line in input.components(separatedBy: .newlines) {
            if line.isEmpty, !replLines.isEmpty {
                let joinedBuffer = replLines.joined(separator: "\n")
                execute(joinedBuffer, filename: "<stdin>", mode: SINGLE_MODE)
                replLines.removeAll()
            }

            guard let lastChar = line.last else {
                continue
            }

            if !replLines.isEmpty || ":({[".contains(lastChar) {
                replLines.append(line)
                continue
            }

            execute(line, filename: "<stdin>", mode: SINGLE_MODE)
        }
    }
}

public extension Interpreter {
    /// Runs a code in execution mode.
    ///
    /// Does not output the input to the console.
    /// - Parameter code: Code to execute.
    static func execute(_ code: String) {
        shared.execute(code)
    }

    /// Runs a code in execution mode.
    /// 
    /// Performs profiling and outputs the input to the console.
    /// - Parameter code: Code to execute.
    static func run(_ code: String) {
        output.input(code)
        shared.execute(code, filename: "<string>", mode: EXEC_MODE)
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
    static func evaluate(_ expression: String, module: PyAPI.Reference? = nil) -> PyAPI.Reference? {
        shared.execute(expression, mode: EVAL_MODE, module: module)

        let r0 = py_getreg(0)
        py_assign(r0, PyAPI.returnValue)
        return r0
    }

    /// Completes the text.
    ///
    /// - Parameter text: Text to complete.
    /// - Returns: Array of possible results.
    static func complete(_ text: String) -> [String] {
        main["_text_to_complete"]?.set(text)
        return [String](evaluate("_completions()")) ?? []
    }
}
