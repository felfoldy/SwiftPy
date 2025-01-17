//
//  GlobalFunctionMacro.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public enum GlobalFunctionMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        let id = UUID().uuidString

        let block = node.trailingClosure!

        // Python callback.
        let callback = ExprSyntax("""
        { _, _ in
            FunctionReference.references["\(raw: id)"]?()
            Interpreter.returnNone()
            return true
        }
        """)
        
        return ExprSyntax("""
        Interpreter.shared.createFunction(
            "\(raw: id)",
            block: \(block),
            callback: \(callback)
        ) 
        """)
    }
}

@main
struct PythonToolsPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        GlobalFunctionMacro.self
    ]
}
