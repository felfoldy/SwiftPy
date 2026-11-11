//
//  InterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 16..
//

import Foundation

public protocol InterpreterConnection: Sendable {
    var events: AsyncStream<InterpreterEvent> { get async }
    
    func perform(_ command: ConsoleCommand) async
}

public extension InterpreterConnection {
    func perform(_ commands: ConsoleCommand...) async {
        for command in commands {
            await perform(command)
        }
    }
}

public enum ConsoleCommand: Codable, Sendable {
    // Commands in lifecycle order: complete while typing, execute to run, stop to cancel.

    /// `token` uniquely identifies the requesting console so it can pick its own
    /// result out of the shared event bus (see the `completions` event).
    case complete(token: UUID, lastComponent: String)
    /// Compiles and runs a source in one step, assigning it a fresh context id.
    /// `token` correlates the request with the caller's input card via `started`.
    /// `name` is the filename tracebacks show, `<script>/<id>` without one.
    /// `namespace` runs it in globals of its own, as a notebook's, rather than `__main__`'s.
    case execute(token: UUID, source: String, name: String? = nil, namespace: String? = nil, mode: ExecutionMode = .cell)
    /// Cooperatively cancels the awaited work of a running execution.
    case stop(id: UInt64)
}

public enum ExecutionMode: Codable, Sendable, Hashable {
    /// A notebook cell: its last expression's value is shown.
    case cell
    /// Every line's value is reported as a `record`, after the `statements`.
    /// The run stops itself after `timeout` seconds.
    case playground(timeout: Double?)
}

public struct InterpreterEvent: Codable, Sendable {
    public let id: UInt64
    public let payload: Payload

    public enum Payload: Codable, Sendable {
        // Events in lifecycle order: completions feed typing; the rest track one
        // execution from `started` through its terminal `stopped`/`attachment`.

        /// Echoes the `token` from the originating `complete` command so only the
        /// requesting console applies the result.
        case completions(suggestions: [String], token: UUID)

        /// Reports the context id assigned to an `execute`, echoing its `token` so
        /// the caller can bind the id to the input card it already created.
        case started(token: UUID)
        /// A playground run's top-level statements, sent before it runs.
        case statements(items: [PlaygroundStatement])
        /// A value a playground run's line produced.
        case record(item: PlaygroundRecord)
        case stdout(text: String)
        case stderr(text: String)
        case feedback(item: ExecutionFeedback)
        /// Acknowledges that a running execution was stopped before completing.
        case stopped
        case attachment(items: [InputAttachment])
    }
}

/// A problem a type check found, in its source's lines and columns (1-based).
public struct Diagnostic: Codable, Sendable, Hashable {
    public enum Severity: String, Codable, Sendable {
        case error, warning, note
    }

    public let line: Int
    public let column: Int
    public let endLine: Int
    public let endColumn: Int
    public let severity: Severity
    public let message: String
    /// The checker's rule, such as `reportAssignmentType`.
    public let code: String?

    public init(line: Int, column: Int, endLine: Int, endColumn: Int, severity: Severity, message: String, code: String?) {
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
        self.severity = severity
        self.message = message
        self.code = code
    }
}

/// A top-level statement's lines, decorators included (1-based).
public struct PlaygroundStatement: Codable, Sendable, Hashable {
    public let firstLine: Int
    public let lastLine: Int

    public init(firstLine: Int, lastLine: Int) {
        self.firstLine = firstLine
        self.lastLine = lastLine
    }
}

/// A value a line produced: an expression's, or a name it assigned.
public struct PlaygroundRecord: Codable, Sendable, Hashable {
    public let line: Int
    /// What was assigned, such as `x` or `self.speed`; nil for an expression.
    public let name: String?
    /// Its `repr`, cut short.
    public let text: String
    public let typeName: String
    /// How many times the line has produced it so far.
    public let count: Int
    /// A view to take from ``PlaygroundViews``, for an expression that is one.
    public let view: Int?

    public init(line: Int, name: String?, text: String, typeName: String, count: Int, view: Int?) {
        self.line = line
        self.name = name
        self.text = text
        self.typeName = typeName
        self.count = count
        self.view = view
    }
}

public struct ExecutionFeedback: Codable, Sendable, Hashable, Identifiable {
    public enum FeedbackType: Codable, Sendable, Hashable {
        case task(progress: Double?)
        /// The line that raised the currently reported error.
        case error
        /// The line that just produced output; a transient flash, not persistent.
        case output
        /// The line a run is on, as sampled.
        case running
    }

    public let lineNumber: Int
    public let type: FeedbackType?

    public var id: Self { self }

    public init(lineNumber: Int, type: FeedbackType?) {
        self.lineNumber = lineNumber
        self.type = type
    }
}

public enum InputAttachment: Codable, Sendable, Hashable, Identifiable {
    case image(name: String)
    case text(text: String)
    case stopwatch

    public var id: Self { self }
}
