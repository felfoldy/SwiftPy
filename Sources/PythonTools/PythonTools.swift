// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation
import LogTools

let log = Logger(subsystem: "com.felfoldy.PythonTools", category: "Interpreter")

public extension Interpreter {
    func createFunction<Result>(_ id: String, name: String, signature: FunctionSignature, block: @MainActor @escaping () -> Result, callback: PK.CFunction) -> FunctionRegistration {
        switch signature {
        case .void:
            FunctionStore.voidFunctions[id] = block as? VoidFunction
        case .int:
            FunctionStore.intFunctions[id] = block as? @MainActor () -> Int
        }
        
        return FunctionRegistration(
            id: id,
            name: name,
            signature: signature,
            cFunction: callback
        )
    }
}

@freestanding(expression)
public macro pythonFunction(
    _ name: String,
    block: @MainActor @escaping () -> Void
) -> FunctionRegistration = #externalMacro(
    module: "PythonToolsMacros",
    type: "GlobalFunctionMacro"
)

@freestanding(expression)
public macro pythonFunction<Result>(
    _ name: String,
    signature: FunctionSignature,
    block: @MainActor @escaping () -> Result
) -> FunctionRegistration = #externalMacro(
    module: "PythonToolsMacros",
    type: "GlobalFunctionMacro"
)
