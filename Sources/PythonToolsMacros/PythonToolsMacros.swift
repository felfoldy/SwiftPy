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

        let name = node.arguments.first!.expression
        
        let signature: String = {
            guard node.arguments.count > 1,
                  let argument = node.arguments.last?.expression else {
                return ".void"
            }

            return argument.description
        }()
        
        let block = node.trailingClosure!

        // Python callback.
        let callback = ExprSyntax("""
        { _, _ in
            FunctionStore.voidFunctions["\(raw: id)"]?()
            PK.returnInt(42)
            return true
        }
        """)
        
        return ExprSyntax("""
        Interpreter.shared.createFunction(
            "\(raw: id)",
            name: \(name),
            signature: \(raw: signature),
            block: \(block),
            callback: \(callback)
        ) 
        """)
    }
    
    static func createPythonCallback(id: String, signature: String) -> String {
        switch signature {
        case ".int":
            """
            { _, _ in
                let result = FunctionStore.intFunction["\(id)"]?()
                PK.returnInt(result)
                return true
            }
            """
        default:
            """
            { _, _ in
                FunctionStore.voidFunctions["\(id)"]?()
                PK.returnNone()
                return true
            }
            """
        }
    }
    
    static func createNoneFunction(id: String) -> String {
        """
        { _, _ in
            FunctionStore.voidFunctions["\(id)"]?()
            PK.returnNone(42)
            return true
        }
        """
    }
}

@main
struct PythonToolsPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        GlobalFunctionMacro.self
    ]
}
