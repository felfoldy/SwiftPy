//
//  PythonFormatting.swift
//  SwiftPy
//

import SwiftSyntax
import Foundation

struct PythonSignatureFormatStyle: FormatStyle {
    var hasSelf: Bool
    /// Parameters are keyword arguments, so they are named the way the members
    /// around them are.
    var convertsToSnakeCase: Bool = true

    func format(_ signature: FunctionSignatureSyntax) -> String {
        var parameters: [String] = hasSelf ? ["self"] : []

        parameters += signature.parameterClause.parameters.map { parameter in
            let swiftName = (parameter.secondName ?? parameter.firstName).text
            let name = convertsToSnakeCase ? swiftName.snakeCased : swiftName
            let type = parameter.type.description.singleLine.pyType
            let defaultExpression = parameter.defaultValue?.value.description.singleLine.pyLiteralExpression ?? ""

            if type == "Unpack" {
                return "*\(name)"
            }
            return "\(name): \(type)\(defaultExpression)"
        }

        return parameters.joined(separator: ", ")
    }
}

/// The Python stub a bound class is described by, which `help()` reads where a
/// type has no source of its own.
struct PythonInterfaceFormatStyle: FormatStyle {
    func format(_ value: ClassMetadata) -> String {
        var rows = [
            "#\"\"\"",
            value.interfaceHeader
        ]

        if let docstring = value.interfaceDocstring {
            rows.append(docstring)
            rows.append("")
        }

        if !value.variableSyntax.isEmpty {
            for variableSyntax in value.variableSyntax {
                rows.append(.tab + variableSyntax)
            }

            rows.append("")
        }

        if !value.initSyntax.isEmpty {
            for initSyntax in value.initSyntax {
                rows.append(.tab + initSyntax)
            }

            rows.append("")
        }

        let functionSyntax = filteredFunctionSyntax(from: value)

        if !functionSyntax.isEmpty {
            for syntax in functionSyntax {
                rows.append(.tab + syntax)
            }

            rows.append("")
        }

        if rows.count == 2 {
            rows.append(.tab + "...")
        }

        let content = rows.joined(separator: "\n").trim
        return content + "\n\"\"\"#"
    }

    /// A view's `body` is how it renders, not something a script calls.
    private func filteredFunctionSyntax(from metadata: ClassMetadata) -> [String] {
        guard metadata.base == ".View" else {
            return metadata.functionSyntax
        }

        return metadata.functionSyntax.filter { syntax in
            !syntax.starts(with: "def body(self)")
                && !syntax.starts(with: "async def body(self)")
        }
    }
}

// MARK: - Swift text as Python text

extension String {
    var trim: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts something like this:
    /// ```swift
    /// func test(
    ///    a: Int,
    ///    b: Int
    /// )
    /// ```
    ///
    /// Into this:
    /// ```swift
    /// func test(a: Int, b: Int)
    /// ```
    var singleLine: String {
        var result = ""
        var index = startIndex

        while index < endIndex {
            let character = self[index]
            if character.isNewline {
                let previous = result.last
                index = self.index(after: index)
                while index < endIndex, self[index].isWhitespace, !self[index].isNewline {
                    index = self.index(after: index)
                }
                if previous == "," {
                    result.append(" ")
                }
                continue
            }
            result.append(character)
            index = self.index(after: index)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var pyType: String {
        let trimmed = trim

        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let withoutBrackets = String(trimmed.dropFirst().dropLast())

            if withoutBrackets.contains(":") {
                let components = withoutBrackets.components(separatedBy: ":")
                let part1 = components[0].trim.pyType
                let part2 = components[1].trim.pyType
                return "dict[\(part1), \(part2)]"
            }

            return "list[\(withoutBrackets.pyType)]"
        }

        if trimmed.hasSuffix("?") {
            let wrapped = String(trimmed.dropLast()).pyType
            return wrapped == "Any" ? wrapped : wrapped + " | None"
        }

        return switch trimmed {
        case "Int":
            "int"
        case "Double", "Float":
            "float"
        case "String":
            "str"
        case "Bool":
            "bool"
        case "Data":
            "bytes"
        case "PyObject":
            "Any"
        default:
            trimmed
        }
    }

    /// From Swift literals to Python default argument syntax.
    /// Examples:
    /// nil     -> " = None"
    /// "text"  -> " = 'text'"
    /// true    -> " = True"
    var pyLiteralExpression: String {
        " = " + singleLine
            .replacingOccurrences(of: "nil", with: "None")
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "true", with: "True")
            .replacingOccurrences(of: "false", with: "False")
    }

    /// camelCase as the snake_case Python names it.
    var snakeCased: String {
        var text = self
        guard !text.isEmpty else { return text }

        var result = [String(text.removeFirst().lowercased())]

        for character in text {
            if character.isUppercase {
                result.append("_")
            }

            result.append(character.lowercased())
        }

        return result.joined()
    }

    static let tab = "    "
}
