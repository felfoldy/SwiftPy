//
//  RemoteInterpreterConnection.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-11.
//

import Foundation

/// An ``InterpreterConnection`` that forwards commands to a remote host via ``Peer``
/// and surfaces the host's events locally.
@MainActor
public final class RemoteInterpreterConnection: InterpreterConnection {
    private let peer: Peer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var continuations: [UUID: AsyncStream<InterpreterEvent>.Continuation] = [:]

    /// Connects to a host that is advertising under `target`.
    public init(target: String) {
        peer = Peer(name: "console")
        peer.messageReceived { [weak self] data in
            guard let self else { return }
            guard let event = try? self.decoder.decode(InterpreterEvent.self, from: data) else { return }
            for continuation in self.continuations.values {
                continuation.yield(event)
            }
        }
        peer.autoconnect(name: target)
    }

    public func perform(_ command: ConsoleCommand) async {
        guard let data = try? encoder.encode(command) else { return }
        try? peer.send(data: data)
    }

    public var events: AsyncStream<InterpreterEvent> {
        let id = UUID()
        return AsyncStream { [self] continuation in
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }
}
