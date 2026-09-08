//
//  PythonError.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import Foundation
import pocketpy

public struct PythonError: LocalizedError {
    /// The kind of exception that was raised.
    public let type: PyType

    /// The exception's value, usually the message string.
    public nonisolated(unsafe) let value: PythonConvertible

    /// The full formatted traceback captured from the interpreter, when available.
    public let traceback: String?

    public init(type: PyType, value: PythonConvertible, traceback: String? = nil) {
        self.type = type
        self.value = value
        self.traceback = traceback
    }

    public var errorDescription: String? {
        traceback ?? String(describing: value)
    }

    /// Returns a copy of this error carrying the given traceback.
    public func withTraceback(_ traceback: String?) -> PythonError {
        PythonError(type: type, value: value, traceback: traceback)
    }

    @MainActor
    static func argCountError(_ got: Int32, expected: Int) -> PythonError {
        .TypeError("expected \(expected) arguments, got \(got)")
    }

    @MainActor
    public static var pyType: PyType { .BaseException }
}

// MARK: - Exception constructors

public extension PythonError {
    static func SyntaxError(_ value: PythonConvertible) -> PythonError { .init(type: .SyntaxError, value: value) }
    static func RecursionError(_ value: PythonConvertible) -> PythonError { .init(type: .RecursionError, value: value) }
    static func OSError(_ value: PythonConvertible) -> PythonError { .init(type: .OSError, value: value) }
    static func NotImplementedError(_ value: PythonConvertible) -> PythonError { .init(type: .NotImplementedError, value: value) }
    static func TypeError(_ value: PythonConvertible) -> PythonError { .init(type: .TypeError, value: value) }
    static func IndexError(_ value: PythonConvertible) -> PythonError { .init(type: .IndexError, value: value) }
    static func ValueError(_ value: PythonConvertible) -> PythonError { .init(type: .ValueError, value: value) }
    static func RuntimeError(_ value: PythonConvertible) -> PythonError { .init(type: .RuntimeError, value: value) }
    static func ZeroDivisionError(_ value: PythonConvertible) -> PythonError { .init(type: .ZeroDivisionError, value: value) }
    static func NameError(_ value: PythonConvertible) -> PythonError { .init(type: .NameError, value: value) }
    static func UnboundLocalError(_ value: PythonConvertible) -> PythonError { .init(type: .UnboundLocalError, value: value) }
    static func AttributeError(_ value: PythonConvertible) -> PythonError { .init(type: .AttributeError, value: value) }
    static func ImportError(_ value: PythonConvertible) -> PythonError { .init(type: .ImportError, value: value) }
    static func AssertionError(_ value: PythonConvertible) -> PythonError { .init(type: .AssertionError, value: value) }
    static func KeyError(_ value: PythonConvertible) -> PythonError { .init(type: .KeyError, value: value) }
    static func StopIteration(_ value: PythonConvertible) -> PythonError { .init(type: .StopIteration, value: value) }
    static func BaseException(_ value: PythonConvertible) -> PythonError { .init(type: .BaseException, value: value) }
}

extension PythonError: PythonConvertible {
    public func toPython(_ reference: PyRef) {
        let error = try! py.call(py.tpobject(type)!, args: value)
        reference.assign(error)
    }
    
    public static func fromPython(_ reference: PyRef) -> PythonError {
        let type = py.typeof(reference)
        let args = try? py.getattr(reference, name: "args")

        var ref: PyRef? = py_None()
        if let args, py.tuple.len(args) > 0 {
            ref = py.tuple.getitem(args, i: 0)
        }

        let value: PythonConvertible = if let str = String(ref) {
            str
        } else {
            ref
        }

        return PythonError(type: type, value: value)
    }
}
