//
//  Embedding.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-02.
//

import Foundation

/// A sentence embedding vector, tagged with the language space it belongs to.
@Scriptable
public final class Embedding {
    /// The embedding vector.
    public let vector: [Double]

    /// The language the vector was computed for, as a BCP-47 tag.
    public let language: String

    /// Creates an embedding from a previously stored vector.
    public init(vector: [Double], language: String) {
        self.vector = vector
        self.language = language
    }
}

extension Embedding: CustomStringConvertible {
    public var description: String {
        "Embedding('\(language)', \(vector.count) dimensions)"
    }
}
