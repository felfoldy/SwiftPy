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
    module: "PythonToolsMacros",
    type: "RegisterFunctionMacro"
)

@freestanding(expression)
public macro def<Out>(
    _ signature: String,
    block: @MainActor @escaping (FunctionArguments) -> Out
) -> FunctionRegistration = #externalMacro(
    module: "PythonToolsMacros",
    type: "RegisterFunctionMacro"
)
