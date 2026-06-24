//
//  LocalInterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 16..
//

import Foundation

struct CompiledCode: Sendable {
    let id: UInt64
    let code: PyObject
}

public actor LocalInterpreterConnection: InterpreterConnection {
    var currentContextId: UInt64 = 0
    var continuations: [UUID: AsyncStream<InterpreterEvent>.Continuation] = [:]
    var latestCompileId: UInt64 = 0
    var compiled: CompiledCode?

    private let _sendContinuation: AsyncStream<InterpreterEvent>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<InterpreterEvent>.makeStream()
        _sendContinuation = continuation
        Task { await self.processEvents(stream) }
    }

    private func processEvents(_ stream: AsyncStream<InterpreterEvent>) async {
        for await event in stream {
            for continuation in continuations.values {
                continuation.yield(event)
            }
        }
    }

    public func perform(_ command: ConsoleCommand) async {
        switch command {
        case .createContext:
            currentContextId += 1
            send(id: currentContextId, .contextCreated)

        case let .complete(id, lastComponent):
            await complete(id: id, lastComponent: lastComponent)

        case let .compile(id, source):
            await compile(id: id, source: source)

        case let .run(id):
            guard let compiled, compiled.id == id else { return }

            await Interpreter.execute(compiled.code, mode: .single)
        }
    }
    
    @usableFromInline
    nonisolated func send(id: UInt64, _ payload: InterpreterEvent.Payload) {
        _sendContinuation.yield(InterpreterEvent(id: id, payload: payload))
    }

    public var events: AsyncStream<InterpreterEvent> {
        let id = UUID()

        return AsyncStream { continuation in
            continuations[id] = continuation
        }
    }

    deinit {
        _sendContinuation.finish()
        for continuation in continuations.values {
            continuation.finish()
        }
    }
    
    private func complete(id: UInt64, lastComponent: String) async {
        let completions = await Interpreter.complete(lastComponent)

        // Drop the result if a newer context has been created in the meantime.
        guard currentContextId == id else { return }
        send(id: id, .completions(suggestions: completions))
    }

    private func compile(id: UInt64, source: String) async {
        log.trace("compile: \(id)")
        guard id > latestCompileId else { return }
        latestCompileId = id

        do {
            let code = try await MainActor.run {
                Interpreter.silenceErrors = true
                defer { Interpreter.silenceErrors = false }
                return try Interpreter.compile(source, filename: "<stdin>", mode: .single)
            }

            guard latestCompileId == id else { return }
            compiled = CompiledCode(id: id, code: code)
            send(id: id, .isExecutable(value: true))
        } catch {
            guard latestCompileId == id else { return }
            send(id: id, .isExecutable(value: false))
        }
    }
}

