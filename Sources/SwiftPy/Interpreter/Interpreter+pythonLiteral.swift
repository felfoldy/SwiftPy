//
//  Interpreter+pythonLiteral.swift
//  SwiftPy
//

import Foundation

extension Interpreter {
    /// A Python string literal: JSON's is one, once `/` isn't escaped.
    nonisolated static func pythonLiteral(_ text: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = (try? encoder.encode(text)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
