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
    /// Cancellation tokens for executions currently in flight, keyed by context id.
    private var running: [UInt64: RunCancellation] = [:]

    private let _sendContinuation: AsyncStream<InterpreterEvent>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream<InterpreterEvent>.makeStream()
        _sendContinuation = continuation
        Task { await processEvents(stream) }
    }

    public func perform(_ command: ConsoleCommand) async {
        switch command {
        case let .complete(token, lastComponent):
            await complete(lastComponent: lastComponent, token: token)

        case let .stop(id):
            // Reentrancy: this runs while `.run` is suspended awaiting execution.
            guard let cancellation = running.removeValue(forKey: id) else { return }
            await cancellation.cancel()
            send(id: id, .stopped)

        case let .execute(token, source):
            // Allocate a fresh context id and return after reporting it. The
            // execution task keeps event delivery responsive while plain Python
            // code runs synchronously.
            currentContextId += 1
            let id = currentContextId
            send(id: id, .started(token: token))
            Task {
                await compile(id: id, source: source)
                await run(id: id)
            }
        }
    }

    /// Executes the code compiled for `id`, provided it is still the latest compile.
    func run(id: UInt64) async {
        guard let compiled, compiled.id == id else { return }
        let code = compiled.code
        let cancellation = RunCancellation()
        running[id] = cancellation
        await time(id: id, cancellation: cancellation) {
            try await Interpreter.execute(code)
        }
        running[id] = nil
    }
    
    @MainActor
    func display(viewObject: PyRef?) {
        if let view = viewObject?.displayView {
            Interpreter.interface.display(view)
        } else if let repr = try? py.repr(viewObject) {
            if let output = InterpreterExecutionContext.current.output {
                output(repr + "\n")
            } else {
                print(repr)
            }
            
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

    private func time(id: UInt64, cancellation: RunCancellation? = nil, _ call: @Sendable () async throws -> Void) async {
        let time = DispatchTime.now().uptimeNanoseconds
        let tracer = await LineTracer()

        func executionTime() -> String {
            let delta = DispatchTime.now().uptimeNanoseconds - time
            return Duration.nanoseconds(delta)
                .formatted(
                    .units(
                        allowed: [.milliseconds, .seconds],
                        fractionalPart: .show(length: 2, rounded: .up)
                    )
                )
        }

        do {
            try await InterpreterExecutionContext.withOutput(tracer, cancellation: cancellation, contextId: id) {
                try await call()
            } stdout: { text in
                // Flash the line the output came from. Skip past library frames to
                // the last line that belongs to a script context, so output that
                // originates in a lib still flashes the user's call site.
                if let entry = tracer.entries.last(where: { $0.contextId != nil }),
                   let lineId = entry.contextId {
                    self.send(id: lineId, .feedback(item: ExecutionFeedback(lineNumber: entry.lineNumber, type: .output)))
                }
                self.send(id: id, .stdout(text: text))
            }

            // A stop request already acknowledged with `.stopped`; don't also
            // report success for the unwound execution.
            if await cancellation?.isCancelled == true { return }
            send(id: id, .attachment(items: [.image(name: "checkmark.circle"), .text(text: executionTime())]))
        } catch {
            if await cancellation?.isCancelled == true { return }
            if let error = error as? PythonError, let traceback = error.traceback {
                send(id: id, .stderr(text: traceback))
            }
            // Flag the last line executed in this context as the one that raised.
            if let line = await tracer.lastLine(forContext: id) {
                send(id: id, .feedback(item: ExecutionFeedback(lineNumber: line, type: .error)))
            }
            send(id: id, .attachment(items: [.image(name: "exclamationmark.triangle"), .text(text: executionTime())]))
        }
    }
    
    private func sourceLocation(for id: UInt64) -> String {
        "<script>/\(id)"
    }

    private func complete(lastComponent: String, token: UUID) async {
        let completions = await Interpreter.complete(lastComponent)
        // The requesting console dedupes by `token`; no context id is needed.
        send(id: 0, .completions(suggestions: completions, token: token))
    }

    func compile(id: UInt64, source: String) async {
        log.trace("compile: \(id)")
        guard id > latestCompileId else { return }
        latestCompileId = id

        do {
            let code = try await Interpreter.shared.compile(
                source,
                filename: sourceLocation(for: id),
                mode: .single
            )

            guard latestCompileId == id else { return }
            compiled = CompileResult(id: id, code: code)
        } catch {
            guard latestCompileId == id else { return }
            if let traceback = error.traceback {
                send(id: id, .stderr(text: traceback))
            }
            send(id: id, .attachment(items: [.image(name: "xmark.square")]))
        }
    }
}
