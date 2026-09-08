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

    public init(
        display: @escaping (AnyView) -> Void = { _ in },
        requestSecret: @escaping (String) async throws -> String = { key in
            throw PythonError.KeyError("No secret stored for '\(key)'.")
        }
    ) {
        self.display = display
        self.requestSecret = requestSecret
    }
}
