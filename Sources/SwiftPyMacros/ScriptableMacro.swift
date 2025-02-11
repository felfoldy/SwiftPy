//
//  ScriptableMacro.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-09.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct ScriptableMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("'@Scriptable' can only be applied to a 'class'")
        }
        
        let variables = classDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
        
        let name = classDecl.name.text
        
        return [
        // Add cache.
        "private(set) var _cachedPythonReference: PyAPI.Reference?",
        ]
    }
}

extension ScriptableMacro: ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("'@Scriptable' can only be applied to a 'class'")
        }
        
        let name = classDecl.name.text
        
        return try [
            ExtensionDeclSyntax("extension \(raw: name): PythonConvertible") {
            """
            static let pyType: PyType = .make("\(raw: name)") { userdata in
            
            }
            """
            }
        ]
    }
}
