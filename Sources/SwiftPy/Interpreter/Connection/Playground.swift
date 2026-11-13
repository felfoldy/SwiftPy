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

/// A value a playground run produced, kept to look into until its run is let go.
@MainActor
public enum PlaygroundObjects {
    private static var objects: [Int: (run: UInt64, object: PyObject)] = [:]
    private static var next = 0

    static func store(_ object: PyObject, run: UInt64) -> Int {
        next += 1
        objects[next] = (run, object)
        return next
    }

    /// Lets go of what `run` produced, and everything looked into below it.
    public static func release(run: UInt64) {
        objects = objects.filter { $0.value.run != run }
    }

    /// What it holds, one level down: a container's items, or an object's
    /// properties, each kept to look into in turn.
    public static func children(of token: Int) -> [PlaygroundChild] {
        #if cpython
        guard let (run, object) = objects[token],
              let module = py.module("interpreter.playground") else { return [] }
        let parts: [PyObject] = (try? module._items_flat?(object)) ?? []
        return stride(from: 0, to: parts.count - 1, by: 2).map { index in
            let item = parts[index + 1]
            let holds: Bool = (try? module._has_items?(item)) ?? false
            let view = item.reference.view
            let short: String? = try? module._short?(item)
            return PlaygroundChild(
                id: store(item, run: run),
                name: String.fromPython(parts[index].reference),
                text: view != nil ? item.typeName : short ?? item.typeName,
                typeName: item.typeName,
                view: view,
                holdsItems: holds
            )
        }
        #else
        return []
        #endif
    }
}

/// An item or property of a playground value.
public struct PlaygroundChild: Identifiable {
    /// Its token in ``PlaygroundObjects``, to look into it.
    public let id: Int
    public let name: String
    public let text: String
    public let typeName: String
    public let view: AnyView?
    public let holdsItems: Bool
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
        let view = reference.view.map(PlaygroundViews.store)
        // A view reads as its type: its repr is Swift's name for it.
        let short: String? = try? py.module("interpreter.playground")?._short?(value)
        let text = view != nil ? value.typeName : short ?? (try? py.repr(reference)) ?? "?"
        let holds: Bool = (try? py.module("interpreter.playground")?._has_items?(value)) ?? false
        let object = holds ? PlaygroundObjects.store(value, run: Interpreter.currentExecutionId) : nil
        record(PlaygroundRecord(
            line: line,
            name: name,
            text: text.count > 300 ? String(text.prefix(300)) + "…" : text,
            typeName: value.typeName,
            count: count,
            view: view,
            object: object
        ))
        #endif
    }
}
