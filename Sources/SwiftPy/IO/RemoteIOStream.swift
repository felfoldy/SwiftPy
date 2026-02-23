//
//  RemoteIOStream.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-02-23.
//

import Foundation

public final class RemoteIOStream: IOStream {
    let peer: Peer

    public init(name: String) {
        peer = Peer(name: name)
        peer.advertise()
        peer.messageReceived { data in
            guard let str = String(data: data, encoding: .utf8) else {
                return
            }

            if str.starts(with: "[RUN]") {
                Task {
                    let code = String(str.dropFirst(5))
                    await Interpreter.asyncRun(code, filename: "<stdin>", mode: .single)
                }
            }
        }
    }

    public func input(_ str: String) {
        try? peer.send(data: Data("[STDIN]\(str)".utf8))
    }

    public func stdout(_ str: String) {
        try? peer.send(data: Data("[STDOUT]\(str)".utf8))
    }

    public func stderr(_ str: String) {
        try? peer.send(data: Data("[STDERR]\(str)".utf8))
    }

    public func executionTime(_ time: UInt64) {
        try? peer.send(data: Data("[TIME]\(time)".utf8))
    }
}
