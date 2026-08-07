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
    case createContext
    /// `token` uniquely identifies the requesting console so it can pick its own
    /// result out of the shared event bus (see the `completions` event).
    case complete(id: UInt64, lastComponent: String, token: UUID)
    case compile(id: UInt64, source: String)
    case run(id: UInt64)
    /// Compiles and runs a source in one step, assigning it a fresh context id.
    case execute(source: String)
}

public struct InterpreterEvent: Codable, Sendable {
    public let id: UInt64
    public let payload: Payload

    public enum Payload: Codable, Sendable {
        case contextCreated
        case inputSource(text: String)
        /// Echoes the `token` from the originating `complete` command so only the
        /// requesting console applies the result.
        case completions(suggestions: [String], token: UUID)
        case isExecutable(value: Bool)

        case isRunning(value: Bool)

        case stdout(text: String)
        case stderr(text: String)

        case attachment(items: [InputAttachment])
    }
}

public enum InputAttachment: Codable, Sendable, Hashable, Identifiable {
    case image(name: String)
    case text(text: String)
    case stopwatch
    case task(lineNumber: Int, progress: Double?)
    case play

    public var id: Self { self }
}
