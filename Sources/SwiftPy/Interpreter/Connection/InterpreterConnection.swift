//
//  InterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 16..
//

public protocol InterpreterConnection: Sendable {
    var events: AsyncStream<InterpreterEvent> { get async }
    
    func perform(_ command: ConsoleCommand) async
}

public enum ConsoleCommand: Codable, Sendable {
    case createContext
    case compile(id: UInt64, source: String)
    case run(id: UInt64)
}

public struct InterpreterEvent: Codable, Sendable {
    public let id: UInt64
    public let payload: Payload

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
