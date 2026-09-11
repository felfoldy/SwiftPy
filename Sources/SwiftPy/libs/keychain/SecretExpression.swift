//
//  SecretExpression.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-11.
//

@Scriptable
@MainActor
public class SecretExpression {
    public let secret: Secret
    public let prefix: String?
    
    public init(secret: Secret, prefix: String?) {
        self.secret = secret
        self.prefix = prefix
    }
}
