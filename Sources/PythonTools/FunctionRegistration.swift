//
//  FunctionRegistration.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2025-01-18.
//


public typealias VoidFunction = @MainActor () -> Void

@MainActor
public enum FunctionStore {
    public static var voidFunctions: [String: VoidFunction] = [:]
}

@MainActor
public struct FunctionRegistration {
    let id: String
    let name: String
    public let signature: String
    public let cFunction: PK.CFunction
}
