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
        "var _pythonCache = PythonBindingCache()",
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
            
            if let accessors = binding.accessorBlock?.accessors {
                // { computed }
                if accessors.is(CodeBlockItemListSyntax.self) {
                    return "nil"
                }
            }
            
            return """
            { _, argv in
                ensureArguments(argv, \(annotation).self) { obj, value in
                    obj.\(identifier) = value
                }
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
        
        guard let parameters = extractParameters(context: context) else {
            return nil
        }
        
        // TODO: Make it work.
        if parameters.count > 1 {
            context.warning(self, "Multiple parameters not yet supported")
            return nil
        }
        
        let returnType: String = {
            if let returnType = signature.returnClause?.type {
                if let identifier = returnType.as(IdentifierTypeSyntax.self)?.name.text {
                    return identifier.pyType
                }
                context.warning(self, "unknown return type")
            }
            return "None"
        }()
        
        // Parameters.
        let paramsString = (["self"] + parameters.map { param in
            "\(param.name): \(param.type.pyType)"
        })
        .joined(separator: ", ")

        pySignature.append("(\(paramsString)) -> \(returnType)")

        if !parameters.isEmpty {
            return """
            type.function("\(pySignature)") { _, argv in
                ensureArguments(argv, \(parameters[0].type).self) { obj, value in
                    obj.\(identifier)(\(parameters[0].name): value)
                }
            }
            """
        }

        if returnType == "None" {
            return """
            type.function("\(pySignature)") { _, argv in
                \(className)(argv)?.\(identifier)()
                return PyAPI.return(.none) 
            }
            """
        }
        
        return """
        type.function("\(pySignature)") { _, argv in
            let result = \(className)(argv)?.\(identifier)()
            return PyAPI.return(result) 
        }
        """
    }
    
    // MARK: Extract function parameters
    
    struct ParameterDefinition {
        let name: String
        let type: String
    }
    
    func extractParameters(context: some MacroExpansionContext) -> [ParameterDefinition]? {
        var parameters: [ParameterDefinition] = []
        
        for parameter in signature.parameterClause.parameters {
            guard let type = parameter.type.as(IdentifierTypeSyntax.self)?.name.text else {
                context.warning(self, "Unable to read parameter type")
                return nil
            }
            
            // Python doesn't support named paramters so just go with the second name in this case.
            let name = parameter.secondName ?? parameter.firstName
            
            parameters.append(
                ParameterDefinition(
                    name: name.text,
                    type: type
                )
            )
        }

        return parameters
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

    var pyType: String {
        switch self {
        case "Int": "int"
        case "Double": "float"
        case "String": "str"
        case "Bool": "bool"
        default: self
        }
    }
}

extension MacroExpansionContext {
    func warning(_ node: any SyntaxProtocol, _ message: String) {
        let msg = MacroExpansionWarningMessage(message)
        diagnose(.init(node: node, message: msg))
    }
}
