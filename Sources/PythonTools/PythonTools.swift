// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation

public typealias _CFunction = pocketpy.py_CFunction

@MainActor
public struct FunctionReference {
    public static var references: [String: @MainActor () -> Void] = [:]

    let id: String
    let callback: _CFunction
}

public extension Interpreter {
    func createFunction(_ id: String, block: @MainActor @escaping () -> Void, callback: _CFunction) -> FunctionReference {
        FunctionReference.references[id] = block
        return FunctionReference(id: id, callback: callback)
    }
    
    static func setGlobal(_ name: String, _ function: FunctionReference) {
        let r0 = py_getreg(0)
        py_newnativefunc(r0, function.callback)
        py_setglobal(py_name(name), r0)
    }
}

@freestanding(expression)
public macro pythonFunction(
    block: @MainActor @escaping () -> Void
) -> FunctionReference = #externalMacro(
    module: "PythonToolsMacros",
    type: "GlobalFunctionMacro"
)
