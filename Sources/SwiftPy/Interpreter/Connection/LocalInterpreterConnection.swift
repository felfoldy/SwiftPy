//
//  LocalInterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 16..
//

import Foundation

struct CompileResult: Sendable {
    let id: UInt64
    let code: CompiledCode
}

public actor LocalInterpreterConnection: InterpreterConnection {
    var currentContextId: UInt64 = 0
    var continuations: [UUID: AsyncStream<InterpreterEvent>.Continuation] = [:]
    var latestCompileId: UInt64 = 0
    var compiled: CompileResult?

    private let _sendContinuation: AsyncStream<InterpreterEvent>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<InterpreterEvent>.makeStream()
        _sendContinuation = continuation
        Task { await processEvents(stream) }
    }

    public func perform(_ command: ConsoleCommand) async {
        switch command {
        case .createContext:
            currentContextId += 1
            send(id: currentContextId, .contextCreated)

        case let .complete(id, lastComponent, token):
            await complete(id: id, lastComponent: lastComponent, token: token)

        case let .compile(id, source):
            await compile(id: id, source: source)

        case let .run(id):
            guard let compiled, compiled.id == id else { return }
            await time(id: id) {
                try await Interpreter.execute(compiled.code)
            }

        case let .execute(source):
            // Reuse the standard flow: allocate a fresh context, then compile and run it.
            await perform(.createContext)
            let id = currentContextId
            await compile(id: id, source: source)
            await perform(.run(id: id))
        }
    }
    
    @MainActor
    func display(viewObject: PyRef?) {
        if let view = viewObject?.view {
            Interpreter.onDisplay(view)
        } else if let repr = try? py.repr(viewObject) {
            print(repr)
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

    private func processEvents(_ stream: AsyncStream<InterpreterEvent>) async {
        for await event in stream {
            for continuation in continuations.values {
                continuation.yield(event)
            }
        }
    }

    private func time(id: UInt64, _ call: @Sendable () async throws -> Void) async {
        do {
            let time = DispatchTime.now().uptimeNanoseconds
            
            try await InterpreterExecutionContext.withOutput({ text in
                self.send(id: id, .stdout(text: text))
            }) {
                try await call()
            }
            
            let delta = DispatchTime.now().uptimeNanoseconds - time
            let executionTime = Duration.nanoseconds(delta)
                .formatted(
                    .units(
                        allowed: [.milliseconds, .seconds],
                        fractionalPart: .show(length: 2, rounded: .up)
                    )
                )
            
            send(id: id, .attachment(items: [.image(name: "checkmark.circle"), .text(text: executionTime)]))
        } catch {
            if let error = error as? PythonError, let traceback = error.traceback {
                send(id: id, .stderr(text: traceback))
            }
            send(id: id, .attachment(items: [.image(name: "xmark.app")]))
        }
    }
    
    private func complete(id: UInt64, lastComponent: String, token: UUID) async {
        let completions = await Interpreter.complete(lastComponent)

        // Drop the result if a newer context has been created in the meantime.
        guard currentContextId == id else { return }
        send(id: id, .completions(suggestions: completions, token: token))
    }

    private func compile(id: UInt64, source: String) async {
        log.trace("compile: \(id)")
        guard id > latestCompileId else { return }
        latestCompileId = id

        send(id: id, .inputSource(text: source))

        do {
            let code = try await Interpreter.shared.compile(source, filename: "<stdin>", mode: .single)

            guard latestCompileId == id else { return }
            compiled = CompileResult(id: id, code: code)
            send(id: id, .isExecutable(value: true))
        } catch {
            guard latestCompileId == id else { return }
            if let traceback = error.traceback {
                send(id: id, .stderr(text: traceback))
            }
            send(id: id, .isExecutable(value: false))
            send(id: id, .attachment(items: [.image(name: "xmark.square")]))
        }
    }
}

