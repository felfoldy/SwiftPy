//
//  ClassMetadata.swift
//  SwiftPy
//

import SwiftSyntax

/// What the macro learns about a class as it reads it, and what the expansion
/// is written from.
struct ClassMetadata {
    var convertsToSnakeCase: Bool = true

    var visibility: String = ""
    var className: String
    var name: String
    var base: String
    var classDoc: String?

    var bindings: [String] = []

    var initSyntax: [String] = []
    var variableSyntax: [String] = []
    var functionSyntax: [String] = []

    var variableDocs: [String] = []

    var typeMakeArgs: String {
        "\"\(name)\", base: \(base)"
    }

    var interfaceHeader: String {
        if base == ".object" {
            return "class \(name):"
        }

        if base.starts(with: ".") {
            return "class \(name)(\(base.dropFirst())):"
        }

        return "class \(name)(\(base)):"
    }

    func identifier(_ attribute: String) -> String {
        guard convertsToSnakeCase else {
            return attribute
        }

        // Converts to snake_case.
        var text = attribute
        var result = [String(text.removeFirst().lowercased())]

        for character in text {
            if character.isUppercase {
                result.append("_")
            }

            result.append(character.lowercased())
        }

        return result.joined()
    }
}

extension AttributeSyntax {
    func classDefinitions(className: String, documentation: String? = nil) -> ClassMetadata {
        let docstring = documentation ?? description.docstring

        guard let arguments = arguments?.as(LabeledExprListSyntax.self) else {
            return ClassMetadata(
                className: className,
                name: className,
                base: ".object",
                classDoc: docstring
            )
        }

        var name = className
        var base = ".object"
        var convertsToSnakeCase = true

        for argument in arguments {
            if let clsName = argument.expression.as(StringLiteralExprSyntax.self)?.segments.description {
                name = clsName
            }

            if argument.label?.text == "base" {
                base = argument.expression.description
            }

            if argument.label?.text == "convertsToSnakeCase" {
                convertsToSnakeCase = argument.expression.description != "false"
            }
        }

        return ClassMetadata(
            convertsToSnakeCase: convertsToSnakeCase,
            className: className,
            name: name,
            base: base,
            classDoc: docstring
        )
    }
}
