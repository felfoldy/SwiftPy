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

    init() {
        py_initialize()
    }

    deinit {
        py_finalize()
    }
    
    func execute(_ code: String) {
        let isExecuted = py_exec(code, "<string>", EXEC_MODE, nil)
        if !isExecuted {
            py_printexc()
        }
    }
}

public extension Interpreter {
    static func execute(_ code: String) {
        shared.execute(code)
    }
}
