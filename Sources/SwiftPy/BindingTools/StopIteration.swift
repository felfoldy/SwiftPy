//
//  StopIteration.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-24.
//

@MainActor
public struct StopIteration: Error {
    public let value: PyAPI.Reference?
    
    public init(value: PyAPI.Reference?) {
        self.value = value
    }
}
