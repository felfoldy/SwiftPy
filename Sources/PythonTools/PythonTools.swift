// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation
import LogTools

let log = Logger(subsystem: "com.felfoldy.PythonTools", category: "Interpreter")

public typealias _CFunction = pocketpy.py_CFunction

@MainActor
public struct FunctionReference {
    public static var references: [String: @MainActor () -> Void] = [:]

    let id: String
    let signature: String
    let cFunction: _CFunction
}

public extension Interpreter {
    func createFunction(_ id: String, name: String, block: @MainActor @escaping () -> Void, callback: _CFunction) -> FunctionReference {
        FunctionReference.references[id] = block
        return FunctionReference(
            id: id,
            signature: "\(name)() -> None",
            cFunction: callback
        )
    }
    
    static func setGlobal(_ function: FunctionReference) {
        let r0 = py_getreg(0)
        let name = py_newfunction(r0, function.signature, function.cFunction, "", 0)
        py_setglobal(name, r0)
    }
    
    static func setToMain(_ function: FunctionReference) {
        let module = py_getmodule("__main__")
        py_bind(module, function.signature, function.cFunction)
    }
}

@freestanding(expression)
public macro pythonFunction(
    _ name: String,
    block: @MainActor @escaping () -> Void
) -> FunctionReference = #externalMacro(
    module: "PythonToolsMacros",
    type: "GlobalFunctionMacro"
)
