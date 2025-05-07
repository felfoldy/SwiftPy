// The Swift Programming Language
// https://docs.swift.org/swift-book
//

import pocketpy
import Foundation
import LogTools

let log = Logger(subsystem: "com.felfoldy.PythonTools", category: "Interpreter")

@attached(member, names: named(_pythonCache))
@attached(extension, conformances: PythonBindable, names: named(pyType))
public macro Scriptable(_ name: String? = nil, base: py_Type? = nil) = #externalMacro(module: "SwiftPyMacros", type: "ScriptableMacro")

@attached(member, names: named(_pythonCache))
@attached(extension, conformances: PythonBindable, names: named(pyType))
@available(*, deprecated, renamed: "Scriptable(_:base:)")
public macro Scriptable(_ name: String? = nil, base: py_Type? = nil, module: py_Ref) = #externalMacro(module: "SwiftPyMacros", type: "ScriptableMacro")
