//
//  FunctionRegistration.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy

@MainActor
public struct FunctionArguments {
    let argc: Int32
    let argv: PyAPI.Reference?

    public static let none = FunctionArguments(argc: 0, argv: nil)
    
    public subscript(index: UInt32) -> PyAPI.Reference? {
        // TODO: Index arguments.
        argv
    }

    public init(argc: Int32, argv: PyAPI.Reference?) {
        self.argc = argc
        self.argv = argv
    }
}

public typealias VoidFunction = @MainActor (FunctionArguments) -> Void
public typealias ReturningFunction = @MainActor (FunctionArguments) -> PythonConvertible?

@MainActor
public enum FunctionStore {
    public static var voidFunctions: [String: VoidFunction] = [:]
    public static var returningFunctions: [String: ReturningFunction] = [:]
}

@MainActor
public struct FunctionRegistration {
    public let id: String
    public let cFunction: PyAPI.CFunction
    public let signature: String

    public init(
        id: String,
        signature: String,
        block: @escaping VoidFunction,
        cFunction: PyAPI.CFunction
    ) {
        FunctionStore.voidFunctions[id] = block
        
        self.id = id
        self.cFunction = cFunction
        self.signature = signature
        
        log.info("Register function: \(signature)")
    }

    public init(
        id: String,
        signature: String,
        block: @escaping ReturningFunction,
        cFunction: PyAPI.CFunction
    ) {
        FunctionStore.returningFunctions[id] = block

        self.id = id
        self.cFunction = cFunction
        self.signature = signature

        log.info("Register function: \(signature)")
    }
}
