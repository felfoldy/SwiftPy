//
//  OutputStream.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-01-28.
//

@MainActor
public protocol OutputStream {
    mutating func input(_ str: String)
    mutating func stdout(_ str: String)
    mutating func stderr(_ str: String)
}

struct DefaultOutputStream: OutputStream {
    func input(_ str: String) {
        log.debug(str)
    }

    func stdout(_ str: String) {
        log.info(str)
    }

    func stderr(_ str: String) {
        log.critical(str)
    }
}
