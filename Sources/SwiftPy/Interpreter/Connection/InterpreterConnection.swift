//
//  InterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 16..
//

public protocol InterpreterConnection {
    func perform(_ command: ConsoleCommand) async
    var events: AsyncStream<InterpreterEvent> { get async }
}

public enum ConsoleCommand: Codable, Sendable {
    case createContext
    case compile(id: UInt64, source: String)
    case run(id: UInt64)
}

public struct InterpreterEvent: Codable, Sendable {
    let id: UInt64
    let payload: Payload

    public enum Payload: Codable, Sendable {
        case contextCreated
        case completions(suggestions: [String])
        case isExecutable(value: Bool)

        case isRunning(value: Bool)

        case stdout(text: String)
        case stderr(text: String)

        case attachment(items: [InputAttachment])
    }
}

public enum InputAttachment: Codable, Sendable {
    case image(name: String)
    case text(text: String)
}
