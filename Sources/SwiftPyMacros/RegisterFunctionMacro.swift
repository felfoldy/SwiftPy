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
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        if #available(macOS 13.0, iOS 16.0, *) {
            let signatureRegex = Regex {
                "\""
                OneOrMore(.any)
                "("
                Capture { ZeroOrMore(.any) }
                ") -> "
                Capture { OneOrMore(.word) }
                "\""
            }
            
            let id = context.makeUniqueName("function")
            
            var signature = node.arguments.first!.expression.description
            let block = node.trailingClosure?.description
            
            guard var block, block.starts(with: "{") else {
                throw MacroExpansionErrorMessage("Set the trailing closure")
            }
            
            var returnType = "None"
            var createArguments = ".none"
            
            if let match = signature.wholeMatch(of: signatureRegex) {
                let (_, parameters, returnTypeMatch) = match.output
                
                returnType = String(returnTypeMatch)
                
                // Take parameter labels.
                let labels = parameters
                    .components(separatedBy: ",")
                    .map { argument in
                        argument
                            .components(separatedBy: ":")[0]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
                
                if labels.isEmpty {
                    block = "{ _ in" + block.dropFirst()
                } else {
                    createArguments = "FunctionArguments(argc: argc, argv: argv)"
                }
            } else {
                let trimmed = signature.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                signature = "\"\(trimmed)() -> None\""
                block = "{ _ in" + block.dropFirst()
            }
            
            if returnType == "None" {
                return ExprSyntax("""
                FunctionRegistration.void(
                    id: "\(id)",
                    signature: \(raw: signature),
                    block: \(raw: block),
                    cFunction: { argc, argv in
                        FunctionStore.voidFunctions["\(id)"]?(\(raw: createArguments))
                        PyAPI.returnValue.setNone()
                        return true
                    }
                )
                """)
            }
            
            return ExprSyntax("""
            FunctionRegistration.returning(
                id: "\(id)",
                signature: \(raw: signature),
                block: \(raw: block),
                cFunction: { argc, argv in
                    let result = FunctionStore.returningFunctions["\(id)"]?(\(raw: createArguments))
                    PyAPI.returnValue.set(result)
                    return true
                }
            )
            """)
        }
        
        throw MacroExpansionErrorMessage("Macro is not available in this context.")
    }
}
