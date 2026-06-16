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

actor LocalInterpreterConnection: InterpreterConnection {
    var currentContextId: UInt64 = 0
    var continuations: [UUID: AsyncStream<InterpreterEvent>.Continuation] = [:]
    var latestCompileId: UInt64 = 0
    var compiled: CompiledCode?

    func perform(_ command: ConsoleCommand) async {
        switch command {
        case .createContext:
            currentContextId += 1
            send(id: currentContextId, .contextCreated)

        case let .compile(id, source):
            guard id > latestCompileId else { return }
            latestCompileId = id

            let completions = await Interpreter.complete(source)

            guard latestCompileId == id else { return }
            send(id: id, .completions(suggestions: completions))

            do {
                let code = try await Interpreter.compile(source, filename: "<stdin>", mode: .single)

                guard latestCompileId == id else { return }
                compiled = CompiledCode(id: id, code: code)
                send(id: id, .isExecutable(value: true))
            } catch {
                guard latestCompileId == id else { return }
                send(id: id, .isExecutable(value: false))
            }

        case let .run(id):
            guard let compiled, compiled.id == id else {
                return
            }
            
            // TODO: run
        }
    }
    
    func send(id: UInt64, _ payload: InterpreterEvent.Payload) {
        let event = InterpreterEvent(id: id, payload: payload)

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    var events: AsyncStream<InterpreterEvent> {
        let id = UUID()

        return AsyncStream { continuation in
            continuations[id] = continuation
        }
    }

    deinit {
        for continuation in continuations.values {
            continuation.finish()
        }
    }
}

