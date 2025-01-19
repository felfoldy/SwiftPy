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
    public static var intFunctions: [String: @MainActor () -> Int] = [:]
}

public enum FunctionSignature {
    /// `() -> Void`
    case void

    /// `() -> int`
    case int
}

@MainActor
public struct FunctionRegistration {
    let id: String
    let name: String
    public let signature: FunctionSignature
    public let cFunction: PK.CFunction

    public let signatureString: String
    
    init(id: String, name: String, signature: FunctionSignature, cFunction: PK.CFunction) {
        self.id = id
        self.name = name
        self.signature = signature
        self.cFunction = cFunction

        signatureString = switch signature {
        case .void: "\(name)() -> None"
        case .int: "\(name)() -> int"
        }
        
        log.info("Register function: \(signatureString)")
    }
}
