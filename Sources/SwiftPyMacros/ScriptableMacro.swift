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
        
        return [
        // Add cache.
        "var _cachedPythonReference: PyAPI.Reference?",
        ]
    }
}

extension ScriptableMacro: ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("'@Scriptable' can only be applied to a 'class'")
        }
        
        let className = classDecl.name.text
        let members = declaration.memberBlock.members

        let properties = members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
        
        let propertyBindings = properties.compactMap { property in
            property.pythonBinding(className: className, context: context)
        }.joined(separator: "\n")

        return try [
            ExtensionDeclSyntax("extension \(raw: className): PythonBindable") {
            """
            static let pyType: PyType = .make("\(raw: className)") { userdata in
                deinitFromPython(userdata)
            } bind: { type in
            \(raw: propertyBindings)
            }
            """
            }
        ]
    }
}

extension VariableDeclSyntax {
    func pythonBinding(className: String, context: some MacroExpansionContext) -> String? {
        guard let binding = bindings.first else {
            context.warning(self, "Unable to read binding")
            return nil
        }
        
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            context.warning(self, "Unable to read pattern")
            return nil
        }
        
        let identifier = pattern.identifier.text
        
        guard let typeAnnotation = binding.typeAnnotation,
              let type = typeAnnotation.type.as(IdentifierTypeSyntax.self) else {
            context.warning(self, "Use type annotation")
            return nil
        }
        
        let annotation = type.name.text
        
        return """
        type.property(
            "\(identifier.snakeCased)",
            getter: { _, argv in
                PyAPI.return(\(className)(argv)?.\(identifier))
                return true
            },
            setter: nil
        )
        """
    }
}

extension String {
    var snakeCased: String {
        var text = self
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

extension MacroExpansionContext {
    func warning(_ node: any SyntaxProtocol, _ message: String) {
        let msg = MacroExpansionWarningMessage(message)
        diagnose(.init(node: node, message: msg))
    }
}
