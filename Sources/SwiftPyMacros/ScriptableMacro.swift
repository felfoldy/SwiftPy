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
        
        let confirmance: String = {
            let hasConfirmance = classDecl.inheritanceClause?.inheritedTypes
                .compactMap { $0.type.as(IdentifierTypeSyntax.self) }
                .map(\.name.text)
                .contains("PythonBindable") ?? false
            
            if hasConfirmance {
                return ""
            }
            
            return ": PythonBindable"
        }()
        
        let className = classDecl.name.text
        let members = declaration.memberBlock.members
        
        let initializerBindings = members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            .binding(className: className)
    
        let propertyBindings = members
            // Properties
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            // Bindings.
            .compactMap { property in
            property.propertyBinding(context: context)
            }.joined(separator: "\n")
        
        let functionBindings = members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
            .compactMap { function in
                function.binding(context: context)
            }.joined(separator: "\n")
        
        let bindings = [initializerBindings, propertyBindings, functionBindings]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        let makeArgs = {
            guard let args = node.arguments?.description else {
                return "\"\(className)\""
            }
            
            if args.starts(with: "\"") {
                return args
            }

            return "\"\(className)\", \(args)"
        }()
        
        return try [
            ExtensionDeclSyntax("extension \(raw: className)\(raw: confirmance)") {
            """
            @MainActor static let pyType: PyType = .make(\(raw: makeArgs)) { type in
            \(raw: bindings)
            type.magic("__new__") { __new__($1) }
            type.magic("__repr__") { __repr__($1) }
            }
            """
            }
        ]
    }
}

// MARK: - init extraction

extension [InitializerDeclSyntax] {
    func binding(className: String) -> String {
        if isEmpty { return "" }
        
        let bindings = map(\.signature)
            .map { signature in
                let parameters = signature.parameterClause.parameters
                    .map { "\($0.firstName.text):" }
                    .joined()
                
                if parameters.isEmpty {
                    return "\(className).init"
                }
                
                return "\(className).init(\(parameters))"
            }
            .map {
                "__init__(argc, argv, \($0)) ||"
            }
            .joined(separator: "\n")
        
        return """
        type.magic("__init__") { argc, argv in
        \(bindings)
        PyAPI.throw(.TypeError, "Invalid arguments")
        }
        """
    }
}

// MARK: - Property

extension VariableDeclSyntax {
    func propertyBinding(context: some MacroExpansionContext) -> String? {
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
            
            return "{ _bind_setter(\\.\(identifier), $1) }"
        }()
        
        return """
        type.property(
            "\(identifier.snakeCased)",
            getter: { _bind_getter(\\.\(identifier), $1) },
            setter: \(setter)
        )
        """
    }
}

// MARK: - Function

extension FunctionDeclSyntax {
    func binding(context: some MacroExpansionContext) -> String? {
        let identifier = name.text
        var pySignature = identifier.snakeCased
        
        guard let parameters = extractParameters(context: context) else {
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
        
        return """
        type.function("\(pySignature)") {
            _bind_function($1, \(identifier))
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
