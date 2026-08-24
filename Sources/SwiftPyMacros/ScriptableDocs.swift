//
//  ScriptableDocs.swift
//  SwiftPy
//

import SwiftSyntax
import Foundation

// MARK: - Reading documentation from source

extension SyntaxProtocol {
    /// The documentation comment written above a declaration.
    ///
    /// swift-syntax exposes no documentation API, so it is read from the
    /// leading trivia, which is where `///` and `/** */` land. Reading the
    /// declaration rather than the attribute is what finds the comment when
    /// another attribute is written above `@Scriptable`.
    var documentationComment: String? {
        var lines: [String] = []

        for piece in leadingTrivia {
            switch piece {
            case let .docLineComment(text):
                lines.append(String(text.dropFirst(3)).trim)
            case let .docBlockComment(text):
                lines += text.docBlockLines
            default:
                continue
            }
        }

        while let first = lines.first, first.isEmpty {
            lines.removeFirst()
        }
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

extension String {
    /// The body of a `/** */` comment, without its delimiters or leading stars.
    var docBlockLines: [String] {
        var body = trim
        if body.hasPrefix("/**") { body = String(body.dropFirst(3)) }
        if body.hasSuffix("*/") { body = String(body.dropLast(2)) }

        return body.components(separatedBy: .newlines).map { line in
            var line = line.trim
            if line.hasPrefix("*") { line = String(line.dropFirst()).trim }
            return line
        }
    }

    /// The `///` lines a declaration's source starts with.
    ///
    /// Used where only the printed syntax is at hand; ``documentationComment``
    /// reads the trivia instead and finds more.
    var docstring: String? {
        var doclines: [String] = []

        for var line in trim.components(separatedBy: .newlines) {
            if line.isEmpty {
                continue
            }

            line = line.trim

            guard line.hasPrefix("///") else {
                if doclines.isEmpty {
                    return nil
                }

                return doclines.joined(separator: "\n")
            }

            doclines.append(String(line.dropFirst(3)).trim)
        }

        if doclines.isEmpty {
            return nil
        }

        return doclines.joined(separator: "\n")
    }
}

// MARK: - Writing documentation into Python

extension String {
    var inPythonTrippleQuotes: String {
        if components(separatedBy: .newlines).count > 1 {
            return .trippleQuotes + self + "\n" + .tab + .trippleQuotes
        }

        return .trippleQuotes + self + .trippleQuotes
    }

    static let trippleQuotes = "\"\"\""
}

extension String {
    /// Documentation as a Swift literal, raw so that quotes and backslashes in
    /// the comment stay as written.
    var asSwiftLiteral: String {
        contains("\n")
            ? "#\"\"\"\n\(self)\n\"\"\"#"
            : "#\"\(self)\"#"
    }
}

extension ClassMetadata {
    /// The class documentation as `__doc__`, which is what `help()` reads for a
    /// summary. Only the class's own comment, not the attribute documentation
    /// the interface carries.
    ///
    /// Carries its own leading newline so that a class without documentation
    /// leaves the expansion exactly as it was.
    var docAssignment: String {
        guard let classDoc else { return "" }

        // Raw, so quotes and backslashes in the comment stay as written.
        return "\nPyObject(type).__doc__ = #\"\"\"\n\(classDoc)\n\"\"\"#"
    }

    /// The docstring the interface stub opens with: the class comment, and the
    /// property comments under an `Attributes:` heading.
    var interfaceDocstring: String? {
        guard let classDoc else { return nil }

        var rows = [classDoc]

        if !variableDocs.isEmpty {
            rows.append("")
            rows.append(.tab + "Attributes:")

            for variableDoc in variableDocs {
                rows.append(.tab + .tab + variableDoc)
            }
        }

        return .tab + rows
            .joined(separator: "\n")
            .inPythonTrippleQuotes
    }
}
