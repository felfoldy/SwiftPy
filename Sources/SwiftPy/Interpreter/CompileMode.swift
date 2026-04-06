//
//  ExecutionMode.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-09-06.
//

import pocketpy

public enum CompileMode {
    case execution, evaluation, single

    @usableFromInline
    internal var pyMode: PyAPI.pyCompileMode {
        switch self {
        case .execution: return EXEC_MODE
        case .evaluation: return EVAL_MODE
        case .single: return SINGLE_MODE
        }
    }
}
