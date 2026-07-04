//
//  Keychain.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-04.
//

import Foundation
import Security

@MainActor
private func getPassword(service: String, username: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: username,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}

@MainActor
private func setPassword(service: String, username: String, password: String) throws(PythonError) {
    let data = Data(password.utf8)
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: username,
    ]
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

@MainActor
private func deletePassword(service: String, username: String) throws(PythonError) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: username,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
        throw .RuntimeError("Keychain error: \(status)")
    }
}

extension Interpreter {
    func bindKeyring() {
        bindModule("keyring") { module in
            module.def(
                "get_password(service: str, username: str) -> str | None",
                docstring: "Return the password for the given service and username, or None if not found."
            ) { argc, argv in
                PyBind.function(argc, argv, getPassword)
            }

            module.def(
                "set_password(service: str, username: str, password: str) -> None",
                docstring: "Store a password in the keychain for the given service and username."
            ) { argc, argv in
                PyBind.function(argc, argv, setPassword)
            }

            module.def(
                "delete_password(service: str, username: str) -> None",
                docstring: "Delete the password for the given service and username from the keychain."
            ) { argc, argv in
                PyBind.function(argc, argv, deletePassword)
            }
        }
    }
}
