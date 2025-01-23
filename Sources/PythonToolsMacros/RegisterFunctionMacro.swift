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
        let signatureRegex = Regex {
            "\""
            OneOrMore(.any)
            "("
            Capture { ZeroOrMore(.any) }
            ") -> "
            Capture { OneOrMore(.word) }
            "\""
        }
        
        let id = UUID().uuidString

        var signature = node.arguments.first!.expression.description
        let block = node.trailingClosure?.description
        
        guard let block, block.starts(with: "{") else {
            throw MacroExpansionErrorMessage("Set the trailing closure")
        }
        
        let ignoreInputBlock = "{ _ in" + block.dropFirst()

        var returnType = "None"
        
        if let match = signature.wholeMatch(of: signatureRegex) {
            let (_, _, returnTypeMatch) = match.output

            returnType = String(returnTypeMatch)
        } else {
            let trimmed = signature.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            signature = "\"\(trimmed)() -> None\""
        }

        let functions = returnType == "None" ? "voidFunctions" :  "returningFunctions"
        let returnSetter = returnType == "None" ? "setNone()" : "set(result)"

        return ExprSyntax("""
        FunctionRegistration(
            id: "\(raw: id)",
            signature: \(raw: signature)
        ) \(raw: ignoreInputBlock)
        cFunction: { argc, argv in
            let result = FunctionStore.\(raw: functions)["\(raw: id)"]?(.none)
            PyAPI.returnValue.\(raw: returnSetter)
            return true
        }
        """)
    }
}
