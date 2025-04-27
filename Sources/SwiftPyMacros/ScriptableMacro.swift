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
        let members = declaration.memberBlock.members.map(\.decl)
        
        var classMeta = node.classDefinitions(className: className)

        initDeclarationVisitor(members: members, metadata: &classMeta)
        propertyDeclarationVisitor(members: members, metadata: &classMeta, context: context)
        functionDeclarationVisitor(members: members, metadata: &classMeta, context: context)
        
        return try [
            ExtensionDeclSyntax("extension \(raw: className)\(raw: confirmance)") {
            """
            @MainActor static let pyType: PyType = .make(\(raw: classMeta.typeMakeArgs)) { type in
            \(raw: classMeta.bindings.joined(separator: "\n"))
            type.magic("__new__") { __new__($1) }
            type.magic("__repr__") { __repr__($1) }
            type.object?.setAttribute("_interface",
            \(raw: buildInterface(classMeta))
            .toRegister(0)
            )
            }
            """
            }
        ]
    }
}

struct ClassMetadata {
    var className: String
    var name: String
    var base: String
    var module: String
    
    var bindings: [String] = []
    
    var initSyntax: [String] = []
    var variableSyntax: [String] = []
    var functionSyntax: [String] = []

    var typeMakeArgs: String {
        "\"\(name)\", base: \(base), module: \(module)"
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
        guard let arguments = arguments?.as(LabeledExprListSyntax.self) else {
            return ClassMetadata(className: className, name: className, base: ".object", module: "Interpreter.main")
        }
        
        var name = className
        var base = ".object"
        var module = "Interpreter.main"
        
        for argument in arguments {
            if let clsName = argument.expression.as(StringLiteralExprSyntax.self)?.segments.description {
                name = clsName
            }
            
            if argument.label?.text == "base" {
                base = argument.expression.description
            }
            
            if argument.label?.text == "module" {
                module = argument.expression.description
            }
        }
        
        return ClassMetadata(className: className, name: name, base: base, module: module)
    }
}

// MARK: - init extraction

func initDeclarationVisitor(members: [DeclSyntax], metadata: inout ClassMetadata) {
    guard let initMembers = InitializerDeclSyntax.from(members) else {
        return
    }
    
    var bindingSyntax: [String] = []
    
    for initMember in initMembers {
        let paramters = initMember.signature.parameterClause.parameters
        
        metadata.initSyntax.append("@overload")
        
        if paramters.isEmpty {
            bindingSyntax.append("\(metadata.className).init")
            metadata.initSyntax.append("def __init__(self) -> None: ...")
            continue
        }

        let names = paramters
            .map { $0.firstName.text + ":" }
            .joined()
        
        bindingSyntax.append("\(metadata.className).init(\(names))")
        
        let argsSyntax = paramters.map { parameter in
            let name = parameter.secondName ?? parameter.firstName
            let type = parameter.type.description.pyType
            return ", \(name): \(type)"
        }.joined()

        metadata.initSyntax.append("def __init__(self\(argsSyntax)) -> None: ...")
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

// MARK: - Property

func propertyDeclarationVisitor(
    members: [DeclSyntax],
    metadata: inout ClassMetadata,
    context: some MacroExpansionContext
) {
    guard let propertyMembers = VariableDeclSyntax.from(members) else {
        return
    }
    
    for member in propertyMembers {
        // var or let
        let specifier = member.bindingSpecifier.text

        guard let binding = member.bindings.first else {
            context.warning(member, "Unable to read binding")
            continue
        }
        
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            context.warning(member, "Unable to read pattern")
            continue
        }
        
        let identifier = pattern.identifier.text
        
        let setter: String = {
            if specifier != "var" { return "nil" }
            
            // { computed }
            if let accessors = binding.accessorBlock?.accessors,
               accessors.is(CodeBlockItemListSyntax.self) {
                return "nil"
            }
            
            return "{ _bind_setter(\\.\(identifier), $1) }"
        }()
        
        if let annotation = binding.typeAnnotation?.type.description {
            metadata.variableSyntax.append("\(identifier.snakeCased): \(annotation.pyType)")
        }
        
        metadata.bindings.append(
        """
        type.property(
            "\(identifier.snakeCased)",
            getter: { _bind_getter(\\.\(identifier), $1) },
            setter: \(setter)
        )
        """
        )
    }
}

func functionDeclarationVisitor(
    members: [DeclSyntax],
    metadata: inout ClassMetadata,
    context: some MacroExpansionContext
) {
    guard let functionMembers = FunctionDeclSyntax.from(members) else {
        return
    }
    
    for function in functionMembers {
        let identifier = function.name.text
        
        let isStatic = function.modifiers
            .map(\.name.text)
            .contains("static")
        
        let signature = function.signature
        
        let paramsString: String = {
            var parameters: [String] = isStatic ? [] : ["self"]
            
            parameters += signature.parameterClause.parameters
                .map { param in
                let name = param.secondName ?? param.firstName
                let type = param.type.description.pyType
                return "\(name): \(type)"
            }
            
            return parameters.joined(separator: ", ")
        }()

        let returnType: String = {
            if let returnType = signature.returnClause?.type {
                return returnType.description.pyType
            }
            return "None"
        }()
        
        let pySignature = "\(identifier.snakeCased)(\(paramsString)) -> \(returnType)"
        
        if isStatic {
            metadata.functionSyntax.append("@staticmethod")
        }
        metadata.functionSyntax.append("def \(pySignature): ...")
        
        if isStatic {
            metadata.bindings.append(
            """
            type.staticFunction("\(identifier.snakeCased)") { argc, argv in
                _bind_staticFunction(argc, argv, \(identifier))
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
}

func buildInterface(_ metadata: ClassMetadata) -> String {
    let tab = "    " // 4 whitespaces

    var rows = ["#\"\"\"",
                metadata.interfaceHeader]
    
    for variableSyntax in metadata.variableSyntax {
        rows.append(tab + variableSyntax)
    }
    
    for initSyntax in metadata.initSyntax {
        rows.append(tab + initSyntax)
    }
    
    for funcSyntax in metadata.functionSyntax {
        rows.append(tab + funcSyntax)
    }
    
    if metadata.variableSyntax.isEmpty && metadata.initSyntax.isEmpty && metadata.functionSyntax.isEmpty {
        rows.append(tab + "...")
    }
    
    rows.append("\"\"\"#")
    
    return rows.joined(separator: "\n")
}

protocol Mappable: DeclSyntaxProtocol {
    var modifiers: DeclModifierListSyntax { get }
}

extension Mappable {
    static func from(_ members: [DeclSyntax]) -> [Self]? {
        let members = members
            .compactMap { $0.as(Self.self) }
            .filter(\.modifiers.isNotInternal)
        if members.isEmpty { return nil }
        return members
    }
}

extension InitializerDeclSyntax: Mappable {}
extension VariableDeclSyntax: Mappable {}
extension FunctionDeclSyntax: Mappable {}

// MARK: - Extensions

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
        case "Int": "int"
        case "Double", "Float": "float"
        case "String": "str"
        case "Bool": "bool"
        default: self
        }
    }
}

extension DeclModifierListSyntax {
    var isNotInternal: Bool {
        !map(\.name.text).contains {
            $0 == "internal" || $0 == "private"
        }
    }
}

extension MacroExpansionContext {
    func warning(_ node: any SyntaxProtocol, _ message: String) {
        let msg = MacroExpansionWarningMessage(message)
        diagnose(.init(node: node, message: msg))
    }
}
