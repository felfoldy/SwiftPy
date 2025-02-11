//
//  SwiftPyMacros.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-17.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PythonToolsPlugin: CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        RegisterFunctionMacro.self,
        ScriptableMacro.self,
    ]
}
