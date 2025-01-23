//
//  RegisterFunctionMacro.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-21.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation
import RegexBuilder

public enum RegisterFunctionMacro: ExpressionMacro {
    enum ReturnType: String {
        case void, int
    }
    
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        let arg0SignatureRegex = Regex {
            "\""
            Capture { OneOrMore(.any) }
            "() -> "
            Capture { OneOrMore(.word) }
            "\""
        }
        
        let id = UUID().uuidString

        let signature = node.arguments.first!.expression.description
        let block = node.trailingClosure?.description
        
        guard let block, block.starts(with: "{") else {
            throw MacroExpansionErrorMessage("Set the trailing closure")
        }
        
        let ignoreInputBlock = "{ _ in" + block.dropFirst()

        guard let match = signature.wholeMatch(of: arg0SignatureRegex) else {
            return createNoneFunction(id: id, name: signature, block: ignoreInputBlock)
        }

        let (_, name, returnType) = match.output

        switch returnType {
        case "None":
            return createNoneFunction(id: id, name: "\"\(name)\"", block: ignoreInputBlock)
            
        case "int":
            return ExprSyntax("""
            FunctionRegistration(
                id: "\(raw: id)",
                signature: \(raw: signature)
            ) \(raw: ignoreInputBlock)
            cFunction: { _, _ in
                let result = FunctionStore.intFunctions["\(raw: id)"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
            """)

        case "str":
            return ExprSyntax("""
            FunctionRegistration(
                id: "\(raw: id)",
                signature: \(raw: signature)
            ) \(raw: ignoreInputBlock)
            cFunction: { _, _ in
                let result = FunctionStore.stringFunctions["\(raw: id)"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
            """)

        case "bool":
            return ExprSyntax("""
            FunctionRegistration(
                id: "\(raw: id)",
                signature: \(raw: signature)
            ) \(raw: ignoreInputBlock)
            cFunction: { _, _ in
                let result = FunctionStore.boolFunctions["\(raw: id)"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
            """)

        case "float":
            return ExprSyntax("""
            FunctionRegistration(
                id: "\(raw: id)",
                signature: \(raw: signature)
            ) \(raw: ignoreInputBlock)
            cFunction: { _, _ in
                let result = FunctionStore.floatFunctions["\(raw: id)"]?(.none)
                PyAPI.returnValue.set(result)
                return true
            }
            """)

        default:
            throw MacroExpansionErrorMessage(
                "Unsupported return type: \(returnType)"
            )
        }
    }

    static func createNoneFunction(id: String, name: String, block: String) -> ExprSyntax {
        ExprSyntax("""
        FunctionRegistration(
            id: "\(raw: id)",
            name: \(raw: name)
        ) \(raw: block)
        cFunction: { _, _ in
            FunctionStore.voidFunctions["\(raw: id)"]?(.none)
            PyAPI.returnValue.setNone()
            return true
        }
        """)
    }
}
