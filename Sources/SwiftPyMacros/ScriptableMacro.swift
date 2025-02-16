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
        [
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
    
        let propertyBindings = members
            // Properties
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            // Bindings.
            .compactMap { property in
            property.propertyBinding(className: className, context: context)
            }.joined(separator: "\n")
        
        let functionBindings = members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
            .compactMap { function in
                function.binding(className: className, context: context)
            }.joined(separator: "\n")
        
        let bindings = [propertyBindings, functionBindings]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return try [
            ExtensionDeclSyntax("extension \(raw: className): PythonBindable") {
            """
            static let pyType: PyType = .make("\(raw: className)") { userdata in
                deinitFromPython(userdata)
            } bind: { type in
            \(raw: bindings)
            }
            """
            }
        ]
    }
}

extension VariableDeclSyntax {
    func propertyBinding(className: String, context: some MacroExpansionContext) -> String? {
        let specifier = bindingSpecifier.text
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
        
        let setter: String = {
            if specifier != "var" {
                return "nil"
            }
            
            if let accessors = binding.accessorBlock?.as(AccessorBlockSyntax.self)?.accessors {
                // { computed }
                if accessors.is(CodeBlockItemListSyntax.self) {
                    return "nil"
                }
            }
            
            return """
            { _, argv in
                guard let value = \(annotation)(argv?[1]) else {
                    return PyAPI.throw(.TypeError, "Expected \(annotation) at position 1")
                }
                \(className)(argv)?.\(identifier) = value
                return PyAPI.return(.none)
            }
            """
        }()
        
        return """
        type.property(
            "\(identifier.snakeCased)",
            getter: { _, argv in
                return PyAPI.return(\(className)(argv)?.\(identifier))
            },
            setter: \(setter)
        )
        """
    }
}

extension FunctionDeclSyntax {
    func binding(className: String, context: some MacroExpansionContext) -> String? {
        let identifier = name.text
        var pySignature = identifier.snakeCased
        
        let parameters = signature.parameterClause.parameters
        
        if parameters.isEmpty {
            pySignature.append("(self) -> None")
        } else {
            context.warning(self, "parameters are not supported yet")
            return nil
        }
        
        return """
        type.function("\(pySignature)") { _, argv in
            \(className)(argv)?.\(identifier)()
            return PyAPI.return(.none) 
        }
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
