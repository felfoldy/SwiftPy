//
//  Secret.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

import Foundation

/// A secret stored in the system keychain, referred to by name.
///
/// Python holds the name only; the value never leaves Swift, so there is no
/// attribute to read it from. Get one with ``keychain.secret``, which asks
/// for the value when the keychain has none, and pass it where the value is
/// needed: a ``requests`` header takes a secret, or ``bearer()`` for an
/// `Authorization` header, and fills the value in as the request is sent.
///
/// ```python
/// import keychain, requests
///
/// key = await keychain.secret("OPENAI_API_KEY")
/// print(key)  # <Secret name="OPENAI_API_KEY">
/// response = await requests.get(url, headers={"Authorization": key.bearer()})
/// ```
@Scriptable
@MainActor
public final class Secret {
    /// The name the secret is stored under.
    public let name: String

    /// Refers to the secret stored under a name, whether or not one is stored
    /// yet. Prefer ``keychain.secret``, which stores a value when there is none.
    ///
    /// name: The name the secret is stored under.
    public init(name: String) {
        self.name = name
    }

    /// Returns a protected expression with text prepended to the secret value.
    /// 
    /// prefix: The text to prepend.
    public func prefixed(_ prefix: String) -> SecretExpression {
        SecretExpression(secret: self, prefix: prefix)
    }

    /// Returns a protected expression for an HTTP Bearer authorization value.
    public func bearer() -> SecretExpression {
        prefixed("Bearer ")
    }
}

extension Secret {
    /// The stored value, read from the keychain on each access.
    public var value: String? {
        Keychain.storage.value(for: name)
    }
}

extension Secret: CustomStringConvertible {
    public nonisolated var description: String {
        "<Secret name=\"\(name)\">"
    }
}
