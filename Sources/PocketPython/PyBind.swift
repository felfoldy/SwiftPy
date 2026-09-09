//
//  PyBind.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-07.
//

import pocketpy
import Foundation

@MainActor
public enum PyBind {
    /// `() -> Void`
    @inlinable
    public static func function(
        _ first: PyArguments.RawFirst,
        _ second: @autoclosure () -> PyArguments.RawSecond,
        _ fn: @MainActor () throws -> Void
    ) -> PyReturn {
        PyAPI.return {
            try checkArgCount(PyArguments(first, second()).count, expected: 0)
            try fn()
            return .none
        }
    }

    /// `() -> Any`
    @inlinable
    public static func function(
        _ first: PyArguments.RawFirst,
        _ second: @autoclosure () -> PyArguments.RawSecond,
        _ fn: @MainActor () throws -> (any PythonConvertible)
    ) -> PyReturn {
        PyAPI.return {
            try checkArgCount(PyArguments(first, second()).count, expected: 0)
            return try fn()
        }
    }

    /// `(...) -> Void`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ first: PyArguments.RawFirst,
        _ second: PyArguments.RawSecond,
        _ fn: @MainActor (repeat each Arg) throws -> Void
    ) -> PyReturn {
        PyAPI.return {
            let arguments = try castArgs(PyArguments(first, second)) as (repeat (each Arg))
            try fn(repeat (each arguments))
            return .none
        }
    }

    /// `(...) -> Any`
    @inlinable
    public static func function<each Arg: PythonConvertible>(
        _ first: PyArguments.RawFirst,
        _ second: PyArguments.RawSecond,
        _ fn: @MainActor (repeat each Arg) throws -> any PythonConvertible
    ) -> PyReturn {
        PyAPI.return {
            let arguments = try castArgs(PyArguments(first, second)) as (repeat (each Arg))
            return try fn(repeat (each arguments))
        }
    }

}

// MARK: - Argument checkers.

extension PyBind {
    public static var overloadArgumentsMatched = true

    @inline(__always)
    public static func checkArgCount(_ got: Int, expected: Int) throws(PythonError) {
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
    /// Reads a call's arguments into a typed tuple. Backend-agnostic: it only
    /// goes through ``PyArguments``.
    @inlinable
    public static func castArgs<each Arg: PythonConvertible>(
        _ arguments: PyArguments,
        from offset: Int = 0
    ) throws(PythonError) -> (repeat each Arg) {
        var i: Int = offset

        @inline(__always)
        func index() throws(PythonError) -> Int {
            defer { i += 1 }
            if i >= arguments.count {
                throw .TypeError("Expected more arguments, got \(arguments.count)")
            }
            return i
        }

        let result = try (repeat (each Arg).cast(arguments, index()))
        try checkArgCount(arguments.count, expected: i)
        return result
    }

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
        try checkArgCount(Int(argc), expected: i)
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
        isAsync: Bool = false,
        function: PyAPI.CFunction
    ) {
        var name = ""
        let functionObj = PyObject {
            name = py.newfunction($0, signature: signature, docstring: docstring, function: function)
        }

        // Mark awaitable bindings so introspection (e.g. `help`) can render
        // them as `async def`. Mirrors Python detecting coroutines via a flag
        // rather than the signature text.
        if isAsync {
            let flag = py.pushtmp()
            py.newbool(flag, value: true)
            py.setdict(functionObj.reference, name: "_is_async", value: flag)
            py.pop()
        }

        if overloads,
           let existing = py.getdict(self, name: name) {
            // If already overloaded.
            if let overloads = py.getdict(existing, name: "_overloads") {
                py.list.append(overloads, value: functionObj.reference)
                return
            }

            // Create dispatcher function.
            let overload = PyObject {
                makeFunctionOverload(
                    $0,
                    name: name,
                    isInstance: signature.contains("(self")
                )
            }
            
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
                    let result = try PyAPI.convertRetval {
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
    
    public static func forwardArgs(_ args: PyRef?) -> Int32 {
        let length = py.tuple.len(args)
        for i in 0..<length {
            py.push(py.tuple.getitem(args, i: i))
        }
        return length
    }
    
    public static func forwardKwargs(_ kwargs: PyRef?) -> Int32 {
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
