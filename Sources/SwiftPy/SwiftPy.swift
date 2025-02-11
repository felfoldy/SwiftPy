// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation
import LogTools

let log = Logger(subsystem: "com.felfoldy.PythonTools", category: "Interpreter")

@freestanding(expression)
public macro def<Out>(
    _ signature: String,
    block: @MainActor @escaping () -> Out
) -> FunctionRegistration = #externalMacro(
    module: "SwiftPyMacros",
    type: "RegisterFunctionMacro"
)

@freestanding(expression)
public macro def<Out>(
    _ signature: String,
    block: @MainActor @escaping (FunctionArguments) -> Out
) -> FunctionRegistration = #externalMacro(
    module: "SwiftPyMacros",
    type: "RegisterFunctionMacro"
)

@attached(member, names: named(pyType), named(_cachedPythonReference))
@attached(extension, conformances: PythonConvertible)
public macro Scriptable() = #externalMacro(module: "SwiftPyMacros", type: "ScriptableMacro")
