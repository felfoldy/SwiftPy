//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import pocketpy

typealias TaskResult = PythonConvertible & Sendable

extension Interpreter {
    func asyncExecute(_ code: String, filename: String = "<string>", mode: py_CompileMode = EXEC_MODE) async {
        await withCheckedContinuation { continuation in            
            let decoder = AsyncContext(code, filename: filename) {
                continuation.resume()
            }
            AsyncContext.current = decoder
            defer { AsyncContext.current = nil }
            
            do {
                try Interpreter.shared.execute(decoder.code, filename: filename, mode: mode)

                if !decoder.didMatch {
                    continuation.resume()
                }
            } catch {
                continuation.resume()
                return
            }
        }
    }
}

public class AsyncTask: PythonBindable {
    public init(_ task: @escaping () async -> Void) {
        let context = AsyncContext.current
        
        Task {
            await task()
            
            guard let context else { return }

            if let continuation = context.continuationCode {
                await Interpreter.shared.asyncExecute(continuation, filename: context.filename)
            }
            context.completion()
        }
    }
    
    public init<T: PythonConvertible>(_ task: @escaping () async -> T?) where T: Sendable {
        let context = AsyncContext.current

        Task {
            let result = await task()

            guard let context else { return }

            if let resultName = context.resultName {
                result?.toPython(
                    .main.emplace(resultName)
                )
            }

            if let continuation = context.continuationCode {
                await Interpreter.shared.asyncExecute(continuation, filename: context.filename)
            }
            context.completion()
        }
    }
    
    public var _pythonCache = PythonBindingCache()
    
    public static var pyType: PyType = .make("AsyncTask") { _ in }
}
