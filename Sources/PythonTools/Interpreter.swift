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
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String) {
        let isExecuted = py_exec(code, "<string>", EXEC_MODE, nil)
        if !isExecuted {
            Interpreter.isFailed = true
            py_printexc()
        }
    }
}

public extension Interpreter {
    static func execute(_ code: String) {
        shared.execute(code)
    }
}

public enum SetPython {
    @inlinable public static func returnNone() {
        py_newnone(py_retval())
    }
}
