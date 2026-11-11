//
//  Playground.swift
//  SwiftPy
//

import SwiftUI

/// Views playground runs produced, until whoever shows them takes them.
@MainActor
public enum PlaygroundViews {
    private static var views: [Int: AnyView] = [:]
    private static var next = 0

    static func store(_ view: AnyView) -> Int {
        next += 1
        views[next] = view
        return next
    }

    public static func take(_ token: Int) -> AnyView? {
        views.removeValue(forKey: token)
    }
}

extension Interpreter {
    /// Compiles a file so that every line reports its value.
    func compilePlayground(_ source: String, filename: String) throws(PythonError) -> (code: CompiledCode, statements: [PlaygroundStatement]) {
        #if cpython
        let module = py.module("interpreter.playground")
        guard let error: String = try? module?._compile?(source, filename) else {
            throw PythonError.ImportError("interpreter.playground")
        }
        guard error.isEmpty else {
            throw PythonError.SyntaxError(error).withTraceback(error)
        }
        guard let code: InterpreterObject = try? module?._take?("code"),
              let lines: [Int] = try? module?._take?("lines") else {
            throw PythonError.RuntimeError("The playground didn't compile")
        }
        let statements = stride(from: 0, to: lines.count - 1, by: 2).map {
            PlaygroundStatement(firstLine: lines[$0], lastLine: lines[$0 + 1])
        }
        return (CompiledCode(code, mode: .execution), statements)
        #else
        throw PythonError.RuntimeError("Playgrounds need CPython")
        #endif
    }

    /// The line of the last playground compile's syntax error.
    func playgroundErrorLine() -> Int? {
        #if cpython
        let line: Int? = try? py.module("interpreter.playground")?._take?("error_line")
        return line.flatMap { $0 > 0 ? $0 : nil }
        #else
        return nil
        #endif
    }
}

extension Interpreter {
    /// Sends what a playground line produced to the run that's executing.
    @MainActor
    static func record(line: Int, name: String?, value: PyObject?, count: Int) {
        #if cpython
        guard let record = InterpreterExecutionContext.current.record, let value else { return }
        let reference = value.reference
        // Only an expression shows as a view: an assigned one reads as its type.
        let view = name == nil ? reference.view.map(PlaygroundViews.store) : nil
        let text = (try? py.repr(reference)) ?? "?"
        record(PlaygroundRecord(
            line: line,
            name: name,
            text: text.count > 300 ? String(text.prefix(300)) + "…" : text,
            typeName: value.typeName,
            count: count,
            view: view
        ))
        #endif
    }
}
