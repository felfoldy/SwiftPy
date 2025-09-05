//
//  ExecutionMode.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-09-06.
//

import pocketpy

public enum CompileMode {
    case execution, evaluation, single

    internal var pyMode: py_CompileMode {
        switch self {
        case .execution: return EXEC_MODE
        case .evaluation: return EVAL_MODE
        case .single: return SINGLE_MODE
        }
    }
}
