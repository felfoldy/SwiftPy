//
//  AsyncCallbackTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-18.
//

import SwiftPy
import Testing
import pocketpy

class AsyncTask: PythonBindable {
    init(_ continuation: @MainActor @escaping () async -> Void) {
        Task {
            await continuation()

            if let resume = _pythonCache.reference?["resume"] {
                _ = Interpreter.call(resume)
            }
        }
    }
    
    init(_ continuation: @MainActor @escaping () async -> PythonConvertible?) {
        Task {
            let result = await continuation()

            if let resume = _pythonCache.reference?["resume"] {
                let val = py_None()
                result?.toPython(val)
                _ = Interpreter.call(resume, val)
            }
        }
    }
    
    var _pythonCache = PythonBindingCache()
    
    static var pyType: PyType = .make("AsyncTask") { ud in
        deinitFromPython(ud)
    } bind: { type in }

    func toPython(_ reference: PyAPI.Reference) {
        if let cached = _pythonCache.reference {
            py_assign(reference, cached)
            return
        }
        
        let ud = py_newobject(reference, Self.pyType, -1, PyAPI.pointerSize)
        ud?.storeBytes(of: nil, as: UnsafeRawPointer?.self)
        storeInPython(reference, userdata: ud)
    }
}

@MainActor
@Suite("AsyncTask concept")
struct AsyncTaskTests {
    let main = Interpreter.main
    
    @Test func asyncCallback() async throws {
        let result = await withUnsafeContinuation { continuation in
            main.bind(#def("callback(result) -> None") { args in
                continuation.resume(returning: String(args[0]))
            })
            
            main.bind(#def("async_func() -> AsyncTask") {
                AsyncTask {
                    try? await Task.sleep(for: .seconds(0))
                    print("result")
                    return "Hi!"
                }
            })

            Interpreter.run("""
            async_func().resume = callback
            """)
        }
        
        #expect(result == "Hi!")
    }
    
    @Test func asyncCallbackVoid() async throws {
        await withUnsafeContinuation { continuation in
            Interpreter.main.bind(#def("async_func() -> AsyncTask") {
                AsyncTask { () async -> Void in
                    try? await Task.sleep(nanoseconds: 0)
                    continuation.resume()
                }
            })

            Interpreter.run("""
            def callback(result):
                print(f'Callback: {result}')
            async_func().resume = callback
            """)
        }
    }
}


