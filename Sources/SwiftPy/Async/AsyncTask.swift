//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import pocketpy

extension Interpreter {
    func asyncExecute(_ code: String, filename: String = "<string>", mode: py_CompileMode = EXEC_MODE) async {
        await withUnsafeContinuation { continuation in
            let main = Interpreter.main
            
            let decoder = AsyncDecoder(code)
            
            if decoder.continuationCode != nil {
                AsyncTask.completion = {
                    continuation.resume()
                }
            }
            
            do {
                try Interpreter.shared.execute(decoder.code, filename: filename, mode: mode)

                guard let task = main["task"] else {
                    continuation.resume()
                    return
                }

                decoder.resultName?
                    .toPython(task.emplace("result"))

                decoder.continuationCode?
                    .toPython(task.emplace("continuation_code"))
            } catch {
                continuation.resume()
                return
            }
        }
    }
}

public class AsyncTask: PythonBindable {
    static var completion: (() -> Void)?
    
    public init(_ task: @escaping () async -> Void) {
        Task {
            await task()
            AsyncTask.completion?()

            guard let reference = _pythonCache.reference else {
                
                return
            }

            if let continuation = reference["continuation_code"],
               let code = String(continuation) {
                await Interpreter.shared.asyncExecute(code, filename: "<async_continuation>")
            }
        }
    }
    
    public init<T: PythonConvertible>(_ task: @escaping () async -> T?) where T: Sendable {
        Task {
            let result = await task()
            AsyncTask.completion?()

            guard let reference = _pythonCache.reference else {
                return
            }

            if let resultName = String(reference["result"]) {
                result?.toPython(
                    Interpreter.main.emplace(resultName)
                )
            }

            if let continuation = reference["continuation_code"],
               let code = String(continuation) {
                await Interpreter.shared.asyncExecute(code, filename: "<async_continuation>")
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
