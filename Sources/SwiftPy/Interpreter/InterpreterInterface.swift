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

    /// Asks the user for an answer, for `input` and `interpreter.ainput`.
    public var requestInput: (InputRequest) async throws -> InputResponse

    public init(
        display: @escaping (AnyView) -> Void = { _ in },
        requestSecret: @escaping (String) async throws -> String = { key in
            throw PythonError.KeyError("No secret stored for '\(key)'.")
        },
        requestInput: @escaping (InputRequest) async throws -> InputResponse = { _ in
            throw PythonError.RuntimeError("Nothing here can ask for input.")
        }
    ) {
        self.display = display
        self.requestSecret = requestSecret
        self.requestInput = requestInput
    }
}

/// What `input` and `interpreter.ainput` ask the user for.
public struct InputRequest: Sendable, Equatable {
    public var prompt: String
    /// Whether the user can attach images to the answer.
    public var acceptsImages: Bool
    /// Whether the answer can run to several lines, rather than one that
    /// Return sends.
    public var isMultiline: Bool

    public init(prompt: String, acceptsImages: Bool = false, isMultiline: Bool = false) {
        self.prompt = prompt
        self.acceptsImages = acceptsImages
        self.isMultiline = isMultiline
    }
}

/// The user's answer: the text, and the images attached, as JPEG or PNG data.
public struct InputResponse: Sendable, Equatable {
    public var text: String
    public var images: [Data]

    public init(text: String, images: [Data] = []) {
        self.text = text
        self.images = images
    }
}
