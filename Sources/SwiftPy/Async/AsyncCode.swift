//
//  AsyncCode.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Foundation

/// A compiled unit of async-aware Python: the code to run now plus the
/// continuation to run once it completes.
@MainActor
public final class AsyncCode: @unchecked Sendable {
    @TaskLocal static var current: AsyncCode?

    /// The compiled Python code object, ready to run.
    let compiledCode: PyObject

    /// Whether this is an awaited call and what it binds its result to.
    let call: AsyncCall

    /// The deferred code after the awaited call, already compiled and ready to
    /// run once this code completes.
    let nextCode: CompiledCode?

    var completion: (() -> Void)?

    init(
        compiledCode: PyObject,
        continuation: CompiledCode?,
        call: AsyncCall,
    ) {
        self.compiledCode = compiledCode
        self.nextCode = continuation
        self.call = call
    }

    func complete(result: PyObject?) async {
        if case .awaiting(let resultName?) = call {
            py.main[dynamicMember: resultName] = result
        }

        if let nextCode {
            _ = try? await Interpreter.execute(nextCode)
        }

        completion?()
    }
}

extension Interpreter {
    func compile(
        _ source: String,
        filename: String = "<string>",
        mode: CompileMode = .execution
    ) throws(PythonError) -> CompiledCode {
        let parsed = AsyncParser(source)
        
        let compiledCode = PyObject(try py.compile(source: parsed.code, filename: filename, mode: mode))

        guard parsed.call.isAwaiting else {
            return .plain(compiledCode, mode: mode)
        }

        let continuation: CompiledCode?
        if let continuationCode = parsed.continuationCode {
            continuation = try compile(continuationCode, filename: filename, mode: mode)
        } else {
            continuation = nil
        }

        return .async(AsyncCode(
            compiledCode: compiledCode,
            continuation: continuation,
            call: parsed.call,
        ))
    }
    
    func execute(_ code: AsyncCode) async throws(PythonError) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, PythonError>) in
            code.completion = { continuation.resume() }

            do {
                try AsyncCode.$current.withValue(code) {
                    try Interpreter.shared.execute(code.compiledCode)
                }
            } catch let error as PythonError {
                continuation.resume(throwing: error)
            } catch {
                // Shouldn't happen, but necessary for the compiler.
            }
        }
    }
}
