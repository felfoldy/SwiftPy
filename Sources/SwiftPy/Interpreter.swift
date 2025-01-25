//
//  Interpreter.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import pocketpy
import Foundation

@MainActor
public final class Interpreter {
    public static let shared = Interpreter()
    static var isFailed = false

    public var replLines = [String]()

    public static var onImport: (String) -> String? = { module in
        log.fault("Tried to import \(module), but  Interpreter.onImport is not set")
        return nil
    }

    init() {
        py_initialize()
        
        py_callbacks().pointee.print = { cString in
            guard let cString else { return }
            let str = String(cString: cString)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if str.isEmpty { return }
            
            if Interpreter.isFailed {
                log.critical(str)
                Interpreter.isFailed = false
            } else {
                log.info(str)
            }
        }
        
        py_callbacks().pointee.importfile = { cFilename in
            guard let cFilename else { return nil }
            
            let filename = String(cString: cFilename)
            if let content = Interpreter.importFromBundle(name: filename) {
                log.info("imported \(filename) from bundle")
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

        def _completions(code: str) -> list[str]:
            completer = Completer()

            completion_list = []
            state = 0
            
            # Get completions until no more are found
            while True:
                completion = completer.complete(code, state)
                if completion is None:
                    break
                completion_list.append(completion)
                state += 1
            
            return completion_list
        """)

        log.info("PocketPython [\(PK_VERSION)] initialized")
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String, filename: String = "<string>", mode: py_CompileMode = EXEC_MODE) {
        let p0 = py_peek(0)
        let isExecuted = py_exec(code, filename, mode, nil)
        if !isExecuted {
            Interpreter.isFailed = true
            py_printexc()
            py_clearexc(p0)
        }
    }

    static func importFromBundle(name: String) -> String? {
        if let path = Bundle.module.path(forResource: name, ofType: nil) {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return content
            } catch {
                log.error(error.localizedDescription)
            }
        }
        
        return nil
    }

    public func repl(input: String) -> String {
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

        return replLines.joined(separator: "\n")
    }
}

public extension Interpreter {
    static func execute(_ code: String) {
        shared.execute(code)
    }

    /// Interactive interpreter input.
    ///
    /// - Parameter input: Input to run.
    /// - Returns: The current buffer if the input was not executed.
    @discardableResult
    static func input(_ input: String) -> String {
        shared.repl(input: input)
    }
    
    static func evaluate(_ expression: String) -> PyAPI.Reference? {
        shared.execute(expression, mode: EVAL_MODE)

        let r0 = py_getreg(0)
        py_assign(r0, PyAPI.returnValue)
        return r0
    }
    
    static func complete(_ text: String) -> [String] {
        [String](evaluate("_completions('\(text)')")) ?? []
    }
}
