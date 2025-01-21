//
//  FunctionRegistration.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//

import pocketpy

public typealias VoidFunction = @MainActor () -> Void
public typealias IntFunction = @MainActor () -> Int?
public typealias StringFunction = @MainActor () -> String?
public typealias BoolFunction = @MainActor () -> Bool?

@MainActor
public enum FunctionStore {
    public static var voidFunctions: [String: VoidFunction] = [:]
    public static var intFunctions: [String: IntFunction] = [:]
    public static var stringFunctions: [String: StringFunction] = [:]
    public static var boolFunctions: [String: BoolFunction] = [:]
}

@MainActor
public struct FunctionRegistration {
    public let id: String
    public let cFunction: PK.CFunction
    public let signature: String

    public init(
        id: String,
        name: String,
        block: @escaping VoidFunction,
        cFunction: PK.CFunction
    ) {
        FunctionStore.voidFunctions[id] = block
        
        self.id = id
        self.cFunction = cFunction
        signature = "\(name)() -> None"
        
        log.info("Register function: \(signature)")
    }
    
    public init<Out>(
        id: String,
        signature: String,
        block: @escaping @MainActor () -> Out?,
        cFunction: PK.CFunction
    ) {
        if let intBlock = block as? IntFunction {
            FunctionStore.intFunctions[id] = intBlock
        } else if let stringBlock = block as? StringFunction {
            FunctionStore.stringFunctions[id] = stringBlock
        } else if let boolBlock = block as? BoolFunction {
            FunctionStore.boolFunctions[id] = boolBlock
        }

        self.id = id
        self.cFunction = cFunction
        self.signature = signature

        log.info("Register function: \(signature)")
    }
}
