//
//  Keychain.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-04.
//

import Foundation
import Security

@MainActor
public final class Keyring {
    public static let shared = Keyring()

    var synchronizable = false
    var accessGroup: String? = nil

    public func configure(synchronizable: Bool = false, accessGroup: String? = nil) {
        self.synchronizable = synchronizable
        self.accessGroup = accessGroup
    }

    func makeQuery(service: String, username: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: username,
        ]
        if synchronizable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue!
        }
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    func getPassword(service: String, username: String) -> String? {
        var query = makeQuery(service: service, username: username)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setPassword(service: String, username: String, password: String) throws(PythonError) {
        let data = Data(password.utf8)
        let query = makeQuery(service: service, username: username)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            if status != errSecSuccess {
                throw .RuntimeError("Keychain error: \(status)")
            }
        } else {
            var item = query
            item[kSecValueData as String] = data
            let status = SecItemAdd(item as CFDictionary, nil)
            if status != errSecSuccess {
                throw .RuntimeError("Keychain error: \(status)")
            }
        }
    }

    func deletePassword(service: String, username: String) throws(PythonError) {
        let query = makeQuery(service: service, username: username)
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw .RuntimeError("Keychain error: \(status)")
        }
    }
}

extension Interpreter {
    func bindKeyring() {
        bindModule("keyring") { module in
            module.def(
                "get_password(service: str, username: str) -> str | None",
                docstring: "Return the password for the given service and username, or None if not found."
            ) { argc, argv in
                PyBind.function(argc, argv, Keyring.shared.getPassword)
            }

            module.def(
                "set_password(service: str, username: str, password: str) -> None",
                docstring: "Store a password in the keychain for the given service and username."
            ) { argc, argv in
                PyBind.function(argc, argv, Keyring.shared.setPassword)
            }

            module.def(
                "delete_password(service: str, username: str) -> None",
                docstring: "Delete the password for the given service and username from the keychain."
            ) { argc, argv in
                PyBind.function(argc, argv, Keyring.shared.deletePassword)
            }
        }
    }
}
