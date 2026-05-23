//
//  ScriptableMacro.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-09.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import Foundation

public struct ScriptableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let classDecl = declaration.as(ClassDeclSyntax.self)
        let visibility = classDecl?.modifiers.publicVisibility ?? ""

        return [
            // Add cache.
            "\(raw: visibility)var _pythonCache = PythonBindingCache()",
        ]
    }
}

extension ScriptableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("'@Scriptable' can only be applied to a 'class'")
        }

        let conformance = classDecl.inherits(from: "PythonBindable")
            ? ""
            : ": PythonBindable"

        let className = classDecl.name.text
        let members = declaration.memberBlock.members.map(\.decl)

        var classMeta = node.classDefinitions(className: className)
        classMeta.visibility = classDecl.modifiers.publicVisibility

        let extractors: [MemberExtractor] = [
            InitializerExtractor(),
            VariableExtractor(context: context),
            FunctionExtractor(context: context)
        ]

        for extractor in extractors {
            extractor.extract(from: members, metadata: &classMeta)
        }

        return try [
            ExtensionDeclSyntax("extension \(raw: className)\(raw: conformance)") {
            """
            @MainActor \(raw: classMeta.visibility)static let pyType: PyType = .make(\(raw: classMeta.typeMakeArgs)) { type in
            \(raw: classMeta.bindings.joined(separator: "\n"))
            type.magic("__new__") { __new__($1) }
            type.magic("__repr__") { __repr__($1) }
            type.property("__view__") { __view__($1) }
            PyObject(type)._interface = \(raw: buildInterface(classMeta))
            }
            """
            }
        ]
    }
}

// MARK: - Metadata

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
}

extension AttributeSyntax {
    func classDefinitions(className: String) -> ClassMetadata {
        let docstring = description.docstring

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

// MARK: - Member Extractors

protocol MemberExtractor {
    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata)
}

struct InitializerExtractor: MemberExtractor {
    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata) {
        let initializers = members
            .compactMap { $0.as(InitializerDeclSyntax.self) }
            .filter(\.modifiers.isVisibleForPython)

        guard !initializers.isEmpty else {
            return
        }

        var bindingSyntax: [String] = []

        for initializer in initializers {
            let parameters = initializer.signature.parameterClause.parameters

            let names = parameters
                .map { $0.firstName.text + ":" }
                .joined()

            bindingSyntax.append(
                "\(metadata.className).init(\(names))"
                    .replacingOccurrences(of: "()", with: "")
            )

            let argsSyntax = parameters.map { parameter in
                let name = parameter.secondName ?? parameter.firstName
                let type = parameter.type.description.pyType
                return ", \(name): \(type)"
            }
            .joined()

            metadata.initSyntax.append("@overload")

            let initSyntax = "def __init__(self\(argsSyntax)) -> None:"

            if let docstring = initializer.description.docstring {
                metadata.initSyntax.append(initSyntax)
                metadata.initSyntax.append(.tab + docstring.inPythonTrippleQuotes)
                metadata.initSyntax.append("")
            } else {
                metadata.initSyntax.append(initSyntax + " ...")
            }
        }

        let bindings = bindingSyntax.map {
            "__init__(argc, argv, \($0)) ||"
        }
        .joined(separator: "\n")

        metadata.bindings.append(
        """
        type.magic("__init__") { argc, argv in
        \(bindings)
        PyAPI.throw(.TypeError, "Invalid arguments")
        }
        """
        )
    }
}

struct VariableExtractor: MemberExtractor {
    let context: any MacroExpansionContext

    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata) {
        let variables = members
            .compactMap { $0.as(VariableDeclSyntax.self) }
            .filter(\.modifiers.isVisibleForPython)

        for variable in variables {
            extract(variable, metadata: &metadata)
        }
    }

    private func extract(
        _ variable: VariableDeclSyntax,
        metadata: inout ClassMetadata
    ) {
        let specifier = variable.bindingSpecifier.text

        guard let binding = variable.bindings.first else {
            context.warning(variable, "Unable to read binding")
            return
        }

        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            context.warning(variable, "Unable to read pattern")
            return
        }

        let identifier = pattern.identifier.text

        // Ignore ViewRepresentable.view.
        if identifier == "view" {
            return
        }

        let pythonIdentifier = metadata.identifier(identifier)

        if let docstring = variable.description.docstring {
            metadata.variableDocs.append("\(pythonIdentifier): \(docstring)")
        }

        if let annotation = binding.typeAnnotation?.type.description {
            metadata.variableSyntax.append("\(pythonIdentifier): \(annotation.pyType)")
        }

        // Bind static property.
        if variable.modifiers.isStatic {
            metadata.bindings.append(
                "PyObject(type).\(pythonIdentifier) = \(identifier)"
            )
            return
        }

        let setter: String = {
            if specifier != "var" {
                return "nil"
            }

            // { computed }
            if let accessors = binding.accessorBlock?.accessors,
               accessors.is(CodeBlockItemListSyntax.self) {
                return "nil"
            }

            return "{ _bind_setter(\\.\(identifier), $1) }"
        }()

        metadata.bindings.append(
        """
        type.property(
            "\(pythonIdentifier)",
            getter: { _bind_getter(\\.\(identifier), $1) },
            setter: \(setter)
        )
        """
        )
    }
}

struct FunctionExtractor: MemberExtractor {
    let context: any MacroExpansionContext

    func extract(from members: [DeclSyntax], metadata: inout ClassMetadata) {
        let functions = members
            .compactMap { $0.as(FunctionDeclSyntax.self) }
            .filter(\.modifiers.isVisibleForPython)

        for function in functions {
            extract(function, metadata: &metadata)
        }
    }

    private func extract(
        _ function: FunctionDeclSyntax,
        metadata: inout ClassMetadata
    ) {
        let identifier = function.name.text
        let isStatic = function.modifiers.isStatic
        let signature = function.signature

        let paramsString = makeParameterList(
            from: signature,
            isStatic: isStatic
        )

        let returnType = signature.returnClause?.type.description.pyType ?? "None"
        let pythonIdentifier = metadata.identifier(identifier)
        let pySignature = "\(pythonIdentifier)(\(paramsString)) -> \(returnType)"

        if isStatic {
            metadata.functionSyntax.append("@staticmethod")
        }

        let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
        let functionSyntax = isAsync
            ? "async def \(pySignature):"
            : "def \(pySignature):"

        if let docstring = function.description.docstring {
            metadata.functionSyntax.append(functionSyntax)
            metadata.functionSyntax.append(.tab + docstring.inPythonTrippleQuotes)
            metadata.functionSyntax.append("")
        } else {
            metadata.functionSyntax.append(functionSyntax + " ...")
        }

        if isStatic {
            metadata.bindings.append(
            """
            type.staticmethod("\(pySignature)") { argc, argv in
                PyBind.function(argc, argv, \(identifier))
            }
            """
            )
        } else {
            metadata.bindings.append(
            """
            type.function("\(pySignature)") {
                _bind_function($1, \(identifier))
            }
            """
            )
        }
    }

    private func makeParameterList(
        from signature: FunctionSignatureSyntax,
        isStatic: Bool
    ) -> String {
        var parameters: [String] = isStatic ? [] : ["self"]

        parameters += signature.parameterClause.parameters.map { parameter in
            let name = parameter.secondName ?? parameter.firstName
            let type = parameter.type.description.pyType
            let defaultExpression = parameter.defaultValue?.description.pyLiteralExpression ?? ""

            return "\(name): \(type)\(defaultExpression)"
        }

        return parameters.joined(separator: ", ")
    }
}

// MARK: - Interface

func buildInterface(_ metadata: ClassMetadata) -> String {
    var rows = [
        "#\"\"\"",
        metadata.interfaceHeader
    ]

    if let classDoc = metadata.classDoc {
        var docRows = [classDoc]

        if !metadata.variableDocs.isEmpty {
            docRows.append("")
            docRows.append(.tab + "Attributes:")

            for variableDoc in metadata.variableDocs {
                docRows.append(.tab + .tab + variableDoc)
            }
        }

        let docstring = .tab + docRows
            .joined(separator: "\n")
            .inPythonTrippleQuotes

        rows.append(docstring)
        rows.append("")
    }

    if !metadata.variableSyntax.isEmpty {
        for variableSyntax in metadata.variableSyntax {
            rows.append(.tab + variableSyntax)
        }

        rows.append("")
    }

    if !metadata.initSyntax.isEmpty {
        for initSyntax in metadata.initSyntax {
            rows.append(.tab + initSyntax)
        }

        rows.append("")
    }

    if !metadata.functionSyntax.isEmpty {
        for functionSyntax in metadata.functionSyntax {
            rows.append(.tab + functionSyntax)
        }

        rows.append("")
    }

    if rows.count == 2 {
        rows.append(.tab + "...")
    }

    let content = rows.joined(separator: "\n").trim
    return content + "\n\"\"\"#"
}

// MARK: - ClassMetadata Helpers

extension ClassMetadata {
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

// MARK: - Syntax Helpers

extension ClassDeclSyntax {
    func inherits(from typeName: String) -> Bool {
        inheritanceClause?.inheritedTypes
            .compactMap { $0.type.as(IdentifierTypeSyntax.self) }
            .map(\.name.text)
            .contains(typeName) ?? false
    }
}

extension DeclModifierListSyntax {
    var isVisibleForPython: Bool {
        !contains {
            $0.name.text == "internal" || $0.name.text == "private"
        }
    }

    var isStatic: Bool {
        contains {
            $0.name.text == "static"
        }
    }

    var publicVisibility: String {
        map(\.name.text)
            .map { $0 + " " }
            .first { $0.contains("public") } ?? ""
    }
}

// MARK: - String Helpers

extension String {
    var trim: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
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
            return String(trimmed.dropLast()).pyType + " | None"
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
        default:
            trimmed
        }
    }

    /// From "= nil" to " = None"
    var pyLiteralExpression: String {
        " " + trim
            .replacingOccurrences(of: "nil", with: "None")
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "true", with: "True")
            .replacingOccurrences(of: "false", with: "False")
    }

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

    var inPythonTrippleQuotes: String {
        if components(separatedBy: .newlines).count > 1 {
            return .trippleQuotes + self + "\n" + .tab + .trippleQuotes
        }

        return .trippleQuotes + self + .trippleQuotes
    }

    static let tab = "    "
    static let trippleQuotes = "\"\"\""
}

// MARK: - Diagnostics

extension MacroExpansionContext {
    func warning(_ node: any SyntaxProtocol, _ message: String) {
        let msg = MacroExpansionWarningMessage(message)
        diagnose(.init(node: node, message: msg))
    }
}
