//
//  PyBind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-07.
//

import pocketpy
import Foundation

extension Interpreter {
    /// Internal module binding.
    func bindModule(_ name: String, docs: String? = nil, block: @escaping (PyModule) -> Void) {
        moduleFactory[name] = { module in
            guard let module = PyModule(module) else { return }

            block(module)
            if let docs {
                module.__doc__ = docs
            }
        }
    }

    func bindModule(_ name: String, in bundle: Bundle, docs: String? = nil) {
        guard let path = bundle.path(forResource: name, ofType: "py"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            log.error("Could not find \(name).py in bundle \(bundle.bundlePath)")
            return
        }

        let filename = name + ".py"
        registeredSources[filename] = content
        registeredSourceDocs[filename] = docs
    }
}

@MainActor
public enum PyBind {
    /// Registers a native module that is configured in Swift when the module
    /// is first imported.
    ///
    /// Use the `block` to populate the module with functions, types, and
    /// other bindings.
    ///
    /// ```swift
    /// PyBind.module("module") { module in
    ///     // Bind classes.
    ///     module.class(MyClass.self)
    ///
    ///     // Bind functions.
    ///     module.def("add(a: float, b: float) -> float") { argc, argv in
    ///         PyBind.function(argc, argv, add)
    ///     }
    ///
    ///     // Bind attributes.
    ///     module.VERSION = "1.0.1"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name the module is imported under in Python.
    ///   - docs: Optional module documentation exposed as `module.__doc__`.
    ///   - block: A closure that configures the ``PyModule`` with its bindings.
    public static func module(_ name: String, docs: String? = nil, block: @escaping (PyModule) -> Void) {
        Interpreter.shared.bindModule(name, docs: docs, block: block)
    }

    /// Registers a source-only module whose body is loaded from `<name>.py`
    /// in the given bundle when the module is first imported.
    ///
    /// ```swift
    /// PyBind.module("module", in: .module)
    /// ```
    public static func module(_ name: String, in bundle: Bundle, docs: String? = nil) {
        Interpreter.shared.bindModule(name, in: bundle, docs: docs)
    }

    /// `() -> Void`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor () throws -> Void
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            try fn()
            return .none
        }
    }
    
    /// `() async -> Void`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor @escaping () async throws -> Void
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
    }

    /// `() -> Any`
    @inlinable
    public static func function(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor () throws -> (any PythonConvertible)
    ) -> Bool {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return try fn()
        }
    }

    /// `() async -> Any`
    @inlinable
    public static func function<Result: PythonConvertible>(
        _ argc: Int32,
        _ argv: @autoclosure () -> PyRef?,
        _ fn: @MainActor @escaping () async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            try checkArgCount(argc, expected: 0)
            return AsyncTask { try await fn() }
        }
    }

    /// `(...) -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor (repeat each Arg) throws -> Void
    ) -> Bool {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            try fn(repeat (each arguments))
            return .none
        }
    }

    /// `(...) async -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Void
    ) -> Bool {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return AsyncTask {
                try await fn(repeat (each arguments))
            }
        }
    }

    /// `(...) -> Any`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor (repeat each Arg) throws -> any PythonConvertible
    ) -> Bool {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return try fn(repeat (each arguments))
        }
    }
    
    /// `(...) async -> Any`
    @inlinable
    public static func function<
        each Arg: PythonConvertible,
        Result: PythonConvertible
    >(
        _ argc: Int32,
        _ argv: PyRef?,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Result
    ) -> Bool where Result: Sendable {
        PyAPI.return {
            let arguments = try castArgs(argc: argc, argv: argv) as (repeat (each Arg))
            return AsyncTask {
                try await fn(repeat (each arguments))
            }
        }
    }
}

// MARK: - Argument checkers.

extension PyBind {
    @usableFromInline
    static var overloadArgumentsMatched = true

    @inline(__always)
    public static func checkArgCount(_ got: Int32, expected: Int) throws(PythonError) {
        if expected != got {
            throw .argCountError(got, expected: expected)
        }
        overloadArgumentsMatched = true
    }
    
    /// Casts multiple generic ``PythonConvertible`` types without argument count checking,
    ///
    /// - Parameters:
    ///   - argv: Pointer to the first argument.
    ///   - offset: Initial index offset.
    /// - Returns: An array of casted arguments.
    @inlinable
    public static func castArgs<each Arg: PythonConvertible>(
        argv: PyRef?,
        from offset: Int = 0
    ) throws(PythonError) -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        var index: Int { defer { i += 1 }; return i }

        let arguments = try (repeat (each Arg).cast(argv, index))
        overloadArgumentsMatched = true
        return arguments
    }
    
    /// Casts multiple generic ``PythonConvertible`` types with argument count checking,
    ///
    /// - Parameters:
    ///   - argc: Argument count.
    ///   - argv: Pointer to the first argument.
    ///   - offset: Initial index offset.
    /// - Returns: An array of casted arguments.
    @inlinable
    public static func castArgs<each Arg: PythonConvertible>(
        argc: Int32,
        argv: PyRef?,
        from offset: Int = 0
    ) throws(PythonError) -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        func index() throws(PythonError) -> Int {
            defer { i += 1 }
            if i >= argc {
                throw .TypeError("Expected more arguments, got \(argc)")
            }
            return i
        }

        let result = try (repeat (each Arg).cast(argv, index()))
        try checkArgCount(argc, expected: i)
        return result
    }
}

@MainActor
extension PyRef {
    @inlinable
    public func bind(
        _ signature: String,
        docstring: String? = nil,
        overloads: Bool = false,
        function: PyAPI.CFunction
    ) {
        let functionObj = PyObject()
        let name = py.newfunction(functionObj.reference, signature: signature, docstring: docstring, function: function)

        if overloads,
           let existing = py.getdict(self, name: name) {
            // If already overloaded.
            if let overloads = py.getdict(existing, name: "_overloads") {
                py.list.append(overloads, value: functionObj.reference)
                return
            }

            // Create dispatcher function.
            let overload = PyObject()
            
            makeFunctionOverload(
                overload.reference,
                name: name,
                isInstance: signature.contains("(self")
            )
            
            let list = py.pushtmp()
            defer { py.pop() }
            py.newlist(list)
            py.list.append(list, value: existing)
            py.list.append(list, value: functionObj.reference)
            overload._overloads = list

            py.setdict(self, name: name, value: overload.reference)
        } else {
            py.setdict(self, name: name, value: functionObj.reference)
        }
    }

    @usableFromInline
    func makeFunctionOverload(_ out: PyRef, name: String, isInstance: Bool) {
        let signature = if isInstance {
            "\(name)(self, *args, **kwargs)"
        } else {
            "\(name)(*args, **kwargs)"
        }
        
        let function = if isInstance {
            PyBind.instanceOverloadDispatcher
        } else {
            PyBind.functionOverloadDispatcher
        }

        py.newfunction(
            out,
            signature: signature,
            docstring: nil,
            function: function
        )
    }
}

extension PyBind {
    @MainActor
    @usableFromInline
    static var instanceOverloadDispatcher: PyAPI.CFunction = { argc, argv in
        PyAPI.return {
            let function = py_inspect_currentfunction()!
            let overloads = py.getdict(function, name: "_overloads")!
            
            for i in 0..<py.list.len(overloads) {
                let overload = py.list.getitem(overloads, i: i)

                do {
                    let result = try PyAPI.convertRetval(silenceErrors: true) {
                        py.push(overload)
                        py.push(argv)

                        let argc = forwardArgs(argv?[1])
                        let kwargc = forwardKwargs(argv?[2])
                        
                        PyBind.overloadArgumentsMatched = false
                        
                        return py_vectorcall(UInt16(argc), UInt16(kwargc))
                    }

                    return result
                } catch {
                    if !PyBind.overloadArgumentsMatched {
                        continue
                    }

                    throw error
                }
            }

            throw PythonError.TypeError("no matching overload")
        }
    }
    
    @MainActor
    @usableFromInline
    static var functionOverloadDispatcher: PyAPI.CFunction = { argc, argv in
        PyAPI.return {
            let function = py_inspect_currentfunction()!
            let overloads = py.getdict(function, name: "_overloads")!

            for i in 0..<py.list.len(overloads) {
                do {
                    let result = try PyAPI.convertRetval {
                        let overload = py.list.getitem(overloads, i: i)

                        py.push(overload)
                        py.pushnil()

                        let argc = forwardArgs(argv?[0])
                        let kwargc = forwardKwargs(argv?[1])
                        
                        Interpreter.silenceErrors = true
                        PyBind.overloadArgumentsMatched = false
                        
                        return py_vectorcall(UInt16(argc), UInt16(kwargc))
                    }

                    Interpreter.silenceErrors = false
                    return result
                } catch {
                    if !PyBind.overloadArgumentsMatched {
                        continue
                    }

                    Interpreter.silenceErrors = false
                    throw error
                }
            }

            Interpreter.silenceErrors = false
            throw PythonError.TypeError("no matching overload")
        }
    }
    
    @usableFromInline
    static func forwardArgs(_ args: PyRef?) -> Int32 {
        let length = py.tuple.len(args)
        for i in 0..<length {
            py.push(py.tuple.getitem(args, i: i))
        }
        return length
    }
    
    @usableFromInline
    static func forwardKwargs(_ kwargs: PyRef?) -> Int32 {
        guard let kwargs else { return 0 }
        py_dict_apply(kwargs, { key, value, _ in
            let keyName = py_name(py_tostr(key))
            py.newint(py.pushtmp(), value: Int(bitPattern: keyName))
            py_push(value)
            return true
        }, nil)
        return py.dict.len(kwargs)
    }
}
