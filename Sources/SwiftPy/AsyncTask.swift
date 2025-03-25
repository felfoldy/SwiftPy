//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import pocketpy

public class AsyncTask: PythonBindable {
    public init(_ continuation: @escaping () async -> Void) {
        Task {
            await continuation()

            if let resume = _pythonCache.reference?["resume"] {
                _ = Interpreter.call(resume)
            }
        }
    }
    
    public init<T: PythonConvertible>(_ continuation: @escaping () async -> T?) where T: Sendable {
        Task {
            let result = await continuation()

            if let resume = _pythonCache.reference?["resume"] {
                let val = py_None()
                result?.toPython(val)
                _ = Interpreter.call(resume, val)
            }
        }
    }
    
    public var _pythonCache = PythonBindingCache()
    
    public static var pyType: PyType = .make("AsyncTask") { ud in
        deinitFromPython(ud)
    } bind: { type in }

    public func toPython(_ reference: PyAPI.Reference) {
        if let cached = _pythonCache.reference {
            py_assign(reference, cached)
            return
        }
        let ud = Self.newPythonObject(reference, hasDictionary: true)
        storeInPython(reference, userdata: ud)
    }
}
