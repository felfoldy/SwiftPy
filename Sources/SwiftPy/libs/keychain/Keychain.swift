//
//  Keychain.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

import Foundation
import Security

@MainActor
protocol SecretStorage {
    func value(for key: String) -> String?
    func set(_ value: String, for key: String) throws(PythonError)
    func remove(_ key: String) throws(PythonError)
}

@MainActor
public enum Keychain {
    /// Swapped for an in-memory store in tests, which have no entitlement for
    /// the synchronizable keychain.
    static var storage: any SecretStorage = KeychainStorage()
    
    public static func value(_ object: PyObject) -> String? {
        if let string = String(object) {
            return string
        }
        if let secret = Secret(object) {
            return secret.value
        }
        if let expression = SecretExpression(object) {
            return expression.value
        }
        return nil
    }
}

/// Generic-password items, one per name, synchronized through iCloud Keychain.
@MainActor
final class KeychainStorage: SecretStorage {
    // No access group: unspecified means the first group in the app's
    // entitlement, which the App Clip - having none - could not name.
    private let service = "com.felfoldy.swiftpy.secrets"

    /// An App Clip is refused iCloud Keychain with `errSecRestrictedAPI`, so
    /// the first refusal drops this storage to device-local items for good.
    private var synchronizes = true

    func value(for key: String) -> String? {
        var result: CFTypeRef?
        let status = perform(for: key) { query in
            var query = query
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            return SecItemCopyMatching(query as CFDictionary, &result)
        }

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: String) throws(PythonError) {
        let data = Data(value.utf8)

        try check(perform(for: key) { query in
            if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
                let update = [kSecValueData as String: data]
                return SecItemUpdate(query as CFDictionary, update as CFDictionary)
            }

            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(item as CFDictionary, nil)
        })
    }

    func remove(_ key: String) throws(PythonError) {
        let status = perform(for: key) { query in
            SecItemDelete(query as CFDictionary)
        }
        guard status != errSecItemNotFound else { return }
        try check(status)
    }

    /// Runs a keychain operation, repeating it device-locally the one time
    /// iCloud Keychain turns out to be unavailable.
    private func perform(
        for key: String,
        _ operation: ([String: Any]) -> OSStatus
    ) -> OSStatus {
        let status = operation(query(for: key, synchronizable: synchronizes))
        guard status == errSecRestrictedAPI, synchronizes else { return status }

        synchronizes = false
        return operation(query(for: key, synchronizable: false))
    }

    private func query(for key: String, synchronizable: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue!
        }
        return query
    }

    private func check(_ status: OSStatus) throws(PythonError) {
        guard status != errSecSuccess else { return }
        throw .RuntimeError("Keychain error: \(status)")
    }
}

extension Interpreter {
    func bindKeychain() {
        bindModule("keychain", docs: """
        Named secrets kept in the system keychain.

        A secret is referred to by name; its value never reaches Python, so it
        cannot be printed or saved with a notebook. Pass the secret itself as a
        ``requests`` header value, or ``keychain.Secret/bearer()`` for an
        `Authorization` header, and the value is filled in as the request is
        sent. Secrets follow you to your other devices through iCloud Keychain.

        ```python
        import keychain, requests

        key = keychain.secret("OPENAI_API_KEY")
        print(key)  # <Secret name="OPENAI_API_KEY">
        response = requests.get(url, headers={"Authorization": key.bearer()})
        keychain.delete(key)
        ```
        """) { module in
            module.class(Secret.self)

            module.def(
                "secret(key: str) -> Secret",
                docstring: """
                Returns the secret stored under a name, asking for its value when \
                the keychain has none.

                key: The name the secret is stored under.

                The value is written to the keychain and never returned to Python:
                pass the secret, or its ``keychain.Secret/bearer()``, as a header
                value to ``requests`` instead.

                ```python
                import keychain, requests

                key = keychain.secret("GITLAB_TOKEN")
                response = requests.get(url, headers={"PRIVATE-TOKEN": key})
                ```
                """
            ) { argc, argv in
                PyBind.blocking(argc, argv) { (key: String) in
                    try await Keychain.secret(named: key)
                }
            }

            module.def(
                "set(key: str, value: str) -> None",
                docstring: """
                Stores a secret under a name, replacing any value already there.

                key: The name to store the secret under.
                value: The secret to store.
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (key: String, value: String) in
                    try Keychain.storage.set(value, for: key)
                }
            }

            module.def(
                "delete(secret: Secret) -> None",
                docstring: """
                Removes a secret from the keychain. A secret that is not stored is \
                left alone.

                secret: The secret to remove.
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (secret: Secret) in
                    try Keychain.storage.remove(secret.name)
                }
            }
        }
    }
}

private extension Keychain {
    static func secret(named key: String) async throws -> Secret {
        if storage.value(for: key) != nil {
            return Secret(name: key)
        }

        let value = try await Interpreter.interface.requestSecret(key)
        guard !value.isEmpty else {
            throw PythonError.ValueError("No value entered for '\(key)'.")
        }

        try storage.set(value, for: key)
        return Secret(name: key)
    }
}
