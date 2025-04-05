//
//  AsyncCallbackTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-18.
//

import SwiftPy
import Testing

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
    
//    @Test func asyncCallbackVoid() async throws {
//        await withUnsafeContinuation { continuation in
//            Interpreter.main.bind(#def("async_func() -> AsyncTask") {
//                AsyncTask { () async -> Void in
//                    try? await Task.sleep(nanoseconds: 0)
//                    continuation.resume()
//                }
//            })
//
//            Interpreter.run("""
//            def callback(result):
//                print(f'Callback: {result}')
//            testtask = async_func()
//            testtask.resume = callback
//            """)
//        }
//    }
}


