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
                try PyAPI.call(resume)
            }
        }
    }
    
    public init<T: PythonConvertible>(_ continuation: @escaping () async -> T?) where T: Sendable {
        Task {
            let result = await continuation()

            if let resume = _pythonCache.reference?["resume"] {
                try PyAPI.call(resume, result?.toRegister(0))
            }
        }
    }
    
    public var _pythonCache = PythonBindingCache()
    
    public static var pyType: PyType = .make("AsyncTask") { _ in }

    public func toPython(_ reference: PyAPI.Reference) {
        if let cached = _pythonCache.reference {
            reference.assign(cached)
            return
        }
        let ud = Self.newPythonObject(reference, hasDictionary: true)
        storeInPython(reference, userdata: ud)
    }
}
