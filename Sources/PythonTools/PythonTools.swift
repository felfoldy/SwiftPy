// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation
import LogTools

let log = Logger(subsystem: "com.felfoldy.PythonTools", category: "Interpreter")

public extension Interpreter {
    func createFunction(_ id: String, name: String, block: @MainActor @escaping () -> Void, callback: PK.CFunction) -> FunctionRegistration {
        let signature = "\(name)() -> None"
        log.info("Register function: \(signature)")

        FunctionStore.voidFunctions[id] = block
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
