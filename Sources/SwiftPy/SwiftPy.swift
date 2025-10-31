// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation
import LogTools

let log = Logger(subsystem: "com.felfoldy.SwiftPy", category: "Interpreter")

@attached(member, names: named(_pythonCache))
@attached(extension, conformances: PythonBindable, names: named(pyType))
public macro Scriptable(_ name: String? = nil, base: PyType? = nil, convertsToSnakeCase: Bool = true) = #externalMacro(module: "SwiftPyMacros", type: "ScriptableMacro")
