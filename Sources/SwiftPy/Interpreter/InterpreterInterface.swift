//
//  InterpreterInterface.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

import SwiftUI

/// What the interpreter asks its host to do. The console assigns these at start
/// up; left unset, each one does the harmless thing.
@MainActor
public struct InterpreterInterface {
    /// Presents a SwiftUI view in the local console, one view at a time.
    public var display: (AnyView) -> Void

    /// Asks for a secret's value by name, for ``Secret``.
    public var requestSecret: (String) async throws -> String

    /// Asks the user for a line of text, for `input` and `interpreter.ainput`.
    public var requestInput: (String) async throws -> String

    public init(
        display: @escaping (AnyView) -> Void = { _ in },
        requestSecret: @escaping (String) async throws -> String = { key in
            throw PythonError.KeyError("No secret stored for '\(key)'.")
        },
        requestInput: @escaping (String) async throws -> String = { _ in
            throw PythonError.RuntimeError("Nothing here can ask for input.")
        }
    ) {
        self.display = display
        self.requestSecret = requestSecret
        self.requestInput = requestInput
    }
}
