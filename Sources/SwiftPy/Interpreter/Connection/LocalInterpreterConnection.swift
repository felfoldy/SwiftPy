//
//  LocalInterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 06. 16..
//

import Foundation
import SwiftUI

struct CompileResult: Sendable {
    let id: UInt64
    let code: CompiledCode
}

public actor LocalInterpreterConnection: InterpreterConnection {
    var currentContextId: UInt64 = 0
    var continuations: [UUID: AsyncStream<InterpreterEvent>.Continuation] = [:]
    /// Compiled runs waiting to start; several can be, as notebooks run side by side.
    var compiled: [UInt64: CompileResult] = [:]
    private var namespaces: [UInt64: String] = [:]
    private var modes: [UInt64: ExecutionMode] = [:]
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
            // `.stopped` follows once the run has actually ended.
            guard let cancellation = running[id] else { return }
            await cancellation.cancel()
            #if cpython
            await Interpreter.interrupt(contextId: id)
            #endif

        case let .execute(token, source, name, namespace, mode):
            // Allocate a fresh context id and return after reporting it. The
            // execution task keeps event delivery responsive while plain Python
            // code runs synchronously.
            currentContextId += 1
            let id = currentContextId
            send(id: id, .started(token: token))
            if let namespace { namespaces[id] = namespace }
            modes[id] = mode
            Task {
                await compile(id: id, source: source, name: name, mode: mode)
                await run(id: id)
            }
        }
    }

    /// Executes the code compiled for `id`.
    func run(id: UInt64) async {
        let mode = modes.removeValue(forKey: id) ?? .cell
        guard let code = compiled.removeValue(forKey: id)?.code else { return }
        let namespace = namespaces.removeValue(forKey: id)
        let cancellation = RunCancellation()
        running[id] = cancellation
        await Interpreter.beginLineSampling()
        defer { Interpreter.endLineSampling() }
        var display: InterpreterExecutionContext.Display?
        var record: (@Sendable (PlaygroundRecord) -> Void)?
        var timeout: Task<Void, Never>?
        if case let .playground(seconds) = mode {
            display = { [weak self] view in self?.recordDisplayed(view, run: id) }
            record = { [weak self] item in self?.send(id: id, .record(item: item)) }
            if let seconds {
                timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(seconds))
                    guard !Task.isCancelled else { return }
                    await self?.perform(.stop(id: id))
                }
            }
        }
        await time(id: id, cancellation: cancellation, display: display, record: record) {
            try await Interpreter.execute(code, namespace: namespace)
        }
        timeout?.cancel()
        running[id] = nil
    }

    /// A view a playground run displays itself, as a record of the line it's on.
    @MainActor
    private func recordDisplayed(_ view: AnyView, run id: UInt64) {
        let line = ScriptRuns.currentLine(tracer: nil, run: id)?.line ?? 0
        send(id: id, .record(item: PlaygroundRecord(
            line: line, name: nil, text: "", typeName: "View", count: 1, view: PlaygroundViews.store(view)
        )))
    }
    
    @MainActor
    func display(viewObject: PyRef?) {
        if let view = viewObject?.displayView {
            Interpreter.display(view)
            return
        }
        if let repr = try? py.repr(viewObject) {
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

    private func time(
        id: UInt64,
        cancellation: RunCancellation? = nil,
        display: InterpreterExecutionContext.Display? = nil,
        record: (@Sendable (PlaygroundRecord) -> Void)? = nil,
        _ call: @Sendable () async throws -> Void
    ) async {
        let time = DispatchTime.now().uptimeNanoseconds
        let tracer = LineTracer()

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
            try await InterpreterExecutionContext.withOutput(tracer, cancellation: cancellation, contextId: id, display: display, record: record) {
                try await call()
            } stdout: { text in
                // Flash the line the output came from. Skip past library frames to
                // the last line that belongs to a script context, so output that
                // originates in a lib still flashes the user's call site. A
                // playground, which groups by statement, takes the top-level line
                // that called in: a function's print goes under its call.
                if let (lineId, line) = ScriptRuns.currentLine(tracer: tracer, outermost: record != nil) {
                    self.send(id: lineId, .feedback(item: ExecutionFeedback(lineNumber: line, type: .output)))
                }
                self.send(id: id, .stdout(text: text))
            }

            // A stopped run reports that alone, not success or the unwinding
            // error too.
            if await cancellation?.isCancelled == true {
                send(id: id, .stopped)
                return
            }
            send(id: id, .attachment(items: [.image(name: "checkmark.circle"), .text(text: executionTime())]))
        } catch {
            if await cancellation?.isCancelled == true {
                send(id: id, .stopped)
                return
            }
            let traceback = (error as? PythonError)?.traceback
            if let traceback {
                send(id: id, .stderr(text: traceback))
            }
            // The run's last line in the traceback raised, or called what did.
            if let line = traceback.flatMap({ ScriptRuns.raisingLine(in: $0, run: id) })
                ?? tracer.lastLine(forContext: id) {
                send(id: id, .feedback(item: ExecutionFeedback(lineNumber: line, type: .error)))
            }
            send(id: id, .attachment(items: [.image(name: "exclamationmark.triangle"), .text(text: executionTime())]))
        }
    }
    
    private func sourceLocation(for id: UInt64, name: String?) -> String {
        name ?? "<script>/\(id)"
    }

    private func complete(lastComponent: String, token: UUID) async {
        let completions = await Interpreter.complete(lastComponent)
        // The requesting console dedupes by `token`; no context id is needed.
        send(id: 0, .completions(suggestions: completions, token: token))
    }

    func compile(id: UInt64, source: String, name: String? = nil, mode: ExecutionMode = .cell) async {
        log.trace("compile: \(id)")
        let filename = sourceLocation(for: id, name: name)
        do {
            let code: CompiledCode
            if case .playground = mode {
                let result = try await Interpreter.shared.compilePlayground(source, filename: filename)
                send(id: id, .statements(items: result.statements))
                code = result.code
            } else {
                code = try await Interpreter.shared.compile(source, filename: filename, mode: .single)
            }

            if let name { ScriptRuns.record(name, run: id) }
            compiled[id] = CompileResult(id: id, code: code)
        } catch {
            if let traceback = error.traceback {
                send(id: id, .stderr(text: traceback))
            }
            if case .playground = mode, let line = await Interpreter.shared.playgroundErrorLine() {
                send(id: id, .feedback(item: ExecutionFeedback(lineNumber: line, type: .error)))
            }
            send(id: id, .attachment(items: [.image(name: "xmark.square")]))
        }
    }
}
