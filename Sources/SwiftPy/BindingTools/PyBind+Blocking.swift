//
//  PyBind+Blocking.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-21.
//

import Foundation

// Asynchronous Swift work behind an ordinary Python call: `name = input()`
// rather than `await input()`. With CPython the cell's thread parks until the
// work is done (see `PyWait`), cancelled by a stop like any awaited task;
// pocketpy runs Python on main, which cannot wait, so there the call returns
// the awaitable task as the `async` overloads do.
public extension PyBind {
    /// `() -> Void`, waiting for `fn`.
    @inlinable
    static func blocking(
        _ first: PyArguments.RawFirst,
        _ second: @autoclosure () -> PyArguments.RawSecond,
        _ fn: @MainActor @escaping () async throws -> Void
    ) -> PyReturn {
        PyAPI.return {
            try checkArgCount(PyArguments(function: first, second()).count, expected: 0)
            return try wait(for: AsyncTask { try await fn() })
        }
    }

    /// `() -> Any`, waiting for `fn`.
    @inlinable
    static func blocking<Result: PythonConvertible>(
        _ first: PyArguments.RawFirst,
        _ second: @autoclosure () -> PyArguments.RawSecond,
        _ fn: @MainActor @escaping () async throws -> Result
    ) -> PyReturn where Result: Sendable {
        PyAPI.return {
            try checkArgCount(PyArguments(function: first, second()).count, expected: 0)
            return try wait(for: AsyncTask { try await fn() })
        }
    }

    /// `(...) -> Void`, waiting for `fn`.
    @inlinable
    static func blocking<each Arg: PythonConvertible>(
        _ first: PyArguments.RawFirst,
        _ second: PyArguments.RawSecond,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Void
    ) -> PyReturn {
        PyAPI.return {
            let arguments = try castArgs(PyArguments(function: first, second)) as (repeat (each Arg))
            return try wait(for: AsyncTask { try await fn(repeat (each arguments)) })
        }
    }

    /// `(...) -> Any`, waiting for `fn`.
    @inlinable
    static func blocking<
        each Arg: PythonConvertible,
        Result: PythonConvertible
    >(
        _ first: PyArguments.RawFirst,
        _ second: PyArguments.RawSecond,
        _ fn: @MainActor @escaping (repeat each Arg) async throws -> Result
    ) -> PyReturn where Result: Sendable {
        PyAPI.return {
            let arguments = try castArgs(PyArguments(function: first, second)) as (repeat (each Arg))
            return try wait(for: AsyncTask { try await fn(repeat (each arguments)) })
        }
    }

    /// What the binding returns for `task`: with CPython, the marker that
    /// parks the calling thread until the task completes; with pocketpy, the
    /// task itself.
    @usableFromInline
    internal static func wait(for task: AsyncTask) throws(PythonError) -> Any? {
        #if cpython
        // Started while the caller's stack can still be read, so it marks the
        // line that waits, as `input()` does.
        task.resume()
        return try PyWait.result { complete in
            Task { @MainActor in
                do {
                    complete(.success(try await task.untilCompletes()))
                } catch let error as PythonError {
                    complete(.failure(error))
                } catch {
                    complete(.failure(.RuntimeError("\(error)")))
                }
            }
        }
        #else
        task
        #endif
    }
}
