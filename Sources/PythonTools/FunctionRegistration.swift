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
}

public typealias VoidFunction = @MainActor (FunctionArguments) -> Void
public typealias IntFunction = @MainActor (FunctionArguments) -> Int?
public typealias StringFunction = @MainActor (FunctionArguments) -> String?
public typealias BoolFunction = @MainActor (FunctionArguments) -> Bool?
public typealias FloatFunction = @MainActor (FunctionArguments) -> Double?

@MainActor
public enum FunctionStore {
    public static var voidFunctions: [String: VoidFunction] = [:]
    public static var intFunctions: [String: IntFunction] = [:]
    public static var stringFunctions: [String: StringFunction] = [:]
    public static var boolFunctions: [String: BoolFunction] = [:]
    public static var floatFunctions: [String: FloatFunction] = [:]
}

@MainActor
public struct FunctionRegistration {
    public let id: String
    public let cFunction: PyAPI.CFunction
    public let signature: String

    public init(
        id: String,
        name: String,
        block: @escaping VoidFunction,
        cFunction: PyAPI.CFunction
    ) {
        FunctionStore.voidFunctions[id] = block
        
        self.id = id
        self.cFunction = cFunction
        signature = "\(name)() -> None"
        
        log.info("Register function: \(signature)")
    }
    
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
    
    public init<Out>(
        id: String,
        signature: String,
        block: @escaping @MainActor (FunctionArguments) -> Out?,
        cFunction: PyAPI.CFunction
    ) {
        if let intBlock = block as? IntFunction {
            FunctionStore.intFunctions[id] = intBlock
        } else if let stringBlock = block as? StringFunction {
            FunctionStore.stringFunctions[id] = stringBlock
        } else if let boolBlock = block as? BoolFunction {
            FunctionStore.boolFunctions[id] = boolBlock
        } else if let floatBlock = block as? FloatFunction {
            FunctionStore.floatFunctions[id] = floatBlock
        }

        self.id = id
        self.cFunction = cFunction
        self.signature = signature

        log.info("Register function: \(signature)")
    }
}
