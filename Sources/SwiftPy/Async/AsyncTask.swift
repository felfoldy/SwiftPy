//
//  AsyncTask.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-25.
//

import pocketpy
import Foundation

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

@MainActor
@Scriptable
public class AsyncTask {
    internal let task: Task<Void, Never>
    
    internal static var tasks = [UUID: AsyncTask]()
    
    private init(task: @escaping () async -> Void) {
        let id = UUID()
        
        self.task = Task {
            await task()
            AsyncTask.tasks[id] = nil
        }

        AsyncTask.tasks[id] = self
    }

    deinit {
        task.cancel()
    }

    public func cancel() {
        task.cancel()
    }
}

extension AsyncTask {
    public convenience init(_ task: @escaping () async throws -> Void) {
        let context = AsyncContext.current
        
        self.init {
            do {
                try await task()
            } catch {
                log.critical(error.localizedDescription)
                context?.completion()
            }

            guard let context else { return }

            if let continuation = context.continuationCode {
                await Interpreter.shared.asyncExecute(continuation, filename: context.filename)
            }
            context.completion()
        }
    }
    
    public convenience init<T: PythonConvertible>(_ task: @escaping () async throws -> T) where T: Sendable {
        let context = AsyncContext.current

        self.init {
            do {
                let result = try await task()

                guard let context else { return }

                if let resultName = context.resultName {
                    result.toPython(
                        .main.emplace(resultName)
                    )
                }

                if let continuation = context.continuationCode {
                    await Interpreter.shared.asyncExecute(continuation, filename: context.filename)
                }
                context.completion()
            } catch {
                log.critical(error.localizedDescription)
                context?.completion()
            }
        }
    }
}
