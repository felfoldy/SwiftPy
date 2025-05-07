//
//  InterpreterError.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-07.
//

import Foundation

public enum InterpreterError: LocalizedError {
    case runtimeError(String)
    case notCallable(String)
    
    public var errorDescription: String? {
        switch self {
        case let .runtimeError(description):
            return description
        case let .notCallable(type):
            return "\(type) is not callable"
        }
    }
}
