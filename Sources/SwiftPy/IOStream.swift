//
//  IOStream.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-28.
//

@MainActor
public protocol IOStream {
    mutating func input(_ str: String)
    mutating func stdout(_ str: String)
    mutating func stderr(_ str: String)
    mutating func executionTime(_ time: UInt64)
}

struct DefaultIOStream: IOStream {
    func input(_ str: String) {
        log.debug(str)
    }

    func stdout(_ str: String) {
        log.info(str)
    }

    func stderr(_ str: String) {
        log.critical(str)
    }

    func executionTime(_ time: UInt64) {}
}
