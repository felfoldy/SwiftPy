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

        var classMeta = node.classDefinitions(
            className: className,
            documentation: classDecl.documentationComment
        )
        classMeta.visibility = classDecl.modifiers.publicVisibility

        let extractors: [MemberExtractor] = [
            InitializerExtractor(),
            VariableExtractor(context: context),
            FunctionExtractor(context: context)
        ]

        for extractor in extractors {
            extractor.extract(from: members, metadata: &classMeta)
        }

        let pythonInterface = PythonInterfaceFormatStyle().format(classMeta)
        
        return try [
            ExtensionDeclSyntax("extension \(raw: className)\(raw: conformance)") {
            """
            @MainActor \(raw: classMeta.visibility)static let pyType: PyType = .make(\(raw: classMeta.typeMakeArgs)) { type in
            \(raw: classMeta.bindings.joined(separator: "\n"))
            type.function("__new__(cls, *args, **kwargs)") {
                __new__(PyArguments(method: $0, $1))
            }
            type.magic("__repr__") {
                __repr__(PyArguments(method: $0, $1))
            }
            PyObject(type)._interface = \(raw: pythonInterface)\(raw: classMeta.docAssignment)
            }
            """
            }
        ]
    }
}
