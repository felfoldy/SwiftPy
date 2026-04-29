//
//  IOStream.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-28.
//

@MainActor
public protocol IOStream {
    func input(_ str: String)
    func stdout(_ str: String)
    func stderr(_ str: String)
    func view(_ view: ViewRepresentation)
    func executionTime(_ time: UInt64)
}

public extension IOStream {
    func view(_ view: ViewRepresentation) {}
}

struct DefaultIOStream: IOStream {
    func input(_ str: String) {
        log.debug("\(str)")
    }

    func stdout(_ str: String) {
        log.info("\(str)")
    }

    func stderr(_ str: String) {
        log.critical("\(str)")
    }

    func executionTime(_ time: UInt64) {}
}
