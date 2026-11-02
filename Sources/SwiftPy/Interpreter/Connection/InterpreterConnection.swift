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
    case execute(token: UUID, source: String, name: String? = nil)
    /// Cooperatively cancels the awaited work of a running execution.
    case stop(id: UInt64)
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

public struct ExecutionFeedback: Codable, Sendable, Hashable, Identifiable {
    public enum FeedbackType: Codable, Sendable, Hashable {
        case task(progress: Double?)
        /// The line that raised the currently reported error.
        case error
        /// The line that just produced output; a transient flash, not persistent.
        case output
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
