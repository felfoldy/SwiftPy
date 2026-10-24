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

    /// Asks for a secret's value, for ``Secret``.
    public var requestSecret: (SecretRequest) async throws -> String

    /// Asks the user for an answer, for `input` and `interpreter.ainput`.
    public var requestInput: (InputRequest) async throws -> InputResponse

    public init(
        display: @escaping (AnyView) -> Void = { _ in },
        requestSecret: @escaping (SecretRequest) async throws -> String = { request in
            throw PythonError.KeyError("No secret stored for '\(request.name)'.")
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

/// What `keychain.secret` asks for when no value is stored.
public struct SecretRequest: Sendable, Equatable {
    /// The name the value is stored under.
    public var name: String
    /// Markdown to ask with, such as where to get the key; nil for the host's own.
    public var prompt: String?

    public init(name: String, prompt: String? = nil) {
        self.name = name
        self.prompt = prompt
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
