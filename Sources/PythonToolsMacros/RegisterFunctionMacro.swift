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
        let block = node.trailingClosure!

        guard let match = signature.wholeMatch(of: arg0SignatureRegex) else {
            return createNoneFunction(id: id, name: signature, block: block)
        }

        let (_, name, returnType) = match.output

        if returnType == "None" {
            return createNoneFunction(id: id, name: "\"\(name)\"", block: block)
        }
        
        if returnType == "int" {
            return ExprSyntax(
            """
            FunctionRegistration(
                id: "\(raw: id)",
                signature: \(raw: signature)
            ) \(block)
            cFunction: { _, _ in
                let result = FunctionStore.intFunctions["\(raw: id)"]?()
                PK.returnInt(result)
                return true
            }
            """
            )
        }

        throw MachError(MachErrorCode.invalidArgument)
    }
    
    static func createNoneFunction(id: String, name: String, block: ClosureExprSyntax) -> ExprSyntax {
        ExprSyntax("""
        FunctionRegistration(
            id: "\(raw: id)",
            name: \(raw: name)
        ) \(block)
        cFunction: { _, _ in
            FunctionStore.voidFunctions["\(raw: id)"]?()
            PK.returnNone()
            return true
        }
        """)
    }
}
