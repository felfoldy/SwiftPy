//
//  FunctionRegistration.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy

@MainActor
public struct FunctionArguments {
    public let argc: Int32
    public let argv: PyAPI.Reference?

    public init(argc: Int32, argv: PyAPI.Reference?) {
        self.argc = argc
        self.argv = argv
    }

    @inlinable public subscript(index: Int) -> PyAPI.Reference? {
        argv?[index]
    }
    
    @inlinable public subscript<T: PythonConvertible>(index: Int) -> T? {
        T(self[index])
    }

    public static let none = FunctionArguments(argc: 0, argv: nil)
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
        cFunction: PyAPI.CFunction
    ) {
        self.id = id
        self.cFunction = cFunction
        self.signature = signature
    }
    
    public static func void(
        id: String,
        signature: String,
        block: @escaping VoidFunction,
        cFunction: PyAPI.CFunction
    ) -> FunctionRegistration {
        FunctionStore.voidFunctions[id] = block
        return FunctionRegistration(id: id, signature: signature, cFunction: cFunction)
    }
    
    public static func returning(
        id: String,
        signature: String,
        block: @escaping ReturningFunction,
        cFunction: PyAPI.CFunction
    ) -> FunctionRegistration {
        FunctionStore.returningFunctions[id] = block
        return FunctionRegistration(id: id, signature: signature, cFunction: cFunction)
    }
}
