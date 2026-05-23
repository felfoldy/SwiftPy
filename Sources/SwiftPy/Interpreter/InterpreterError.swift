//
//  InterpreterError.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-05-23.
//

import Foundation

public enum InterpreterError: LocalizedError {
    case runtimeFailure(String)
    case silencedError

    var description: String {
        switch self {
        case let .runtimeFailure(string):
            string
        case .silencedError:
            "Silenced error"
        }
    }
}
