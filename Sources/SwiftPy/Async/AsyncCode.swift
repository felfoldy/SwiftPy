//
//  AsyncCode.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-04-05.
//

import Foundation

/// A compiled unit of async-aware Python: the code to run now plus the
/// continuation to run once it completes. Produced by ``AsyncCompiler``.
@MainActor
final class AsyncCode: @unchecked Sendable {
    @TaskLocal static var current: AsyncCode?

    /// The compiled Python code object, ready to run.
    let compiledCode: PyObject

    /// Whether this is an awaited call and what it binds its result to.
    let call: AsyncCall

    /// The deferred code after the awaited call, already compiled and ready to
    /// run once this code completes.
    let continuation: AsyncCode?

    var completion: (() -> Void)?

    init(
        compiledCode: PyObject,
        continuation: AsyncCode?,
        call: AsyncCall,
    ) {
        self.compiledCode = compiledCode
        self.continuation = continuation
        self.call = call
    }

    func complete(result: PyObject?) async {
        if case .awaiting(let resultName?) = call {
            py.main[dynamicMember: resultName] = result
        }

        if let continuation {
            await Interpreter.shared.asyncExecute(continuation)
        }

        completion?()
    }
}
