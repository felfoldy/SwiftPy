//
//  KeyringTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-04.
//

import Testing
@testable import SwiftPy

@MainActor
struct KeyringTests {
    private let service = "com.swiftpy.keyring.test"

    @Test func getPassword_whenNotFound_returnsNone() {
        Interpreter.run("import keyring")

        let result: Bool? = Interpreter.evaluate(
            "keyring.get_password('\(service)', 'no_such_user') is None"
        )
        #expect(result == true)
    }

    @Test func getPassword_afterSet_returnsPassword() {
        Interpreter.run("import keyring")
        defer { Interpreter.run("keyring.delete_password('\(service)', 'user_get')") }

        Interpreter.run("keyring.set_password('\(service)', 'user_get', 'secret')")
        let result: String? = Interpreter.evaluate(
            "keyring.get_password('\(service)', 'user_get')"
        )
        #expect(result == "secret")
    }

    @Test func setPassword_whenExists_updatesValue() {
        Interpreter.run("import keyring")
        defer { Interpreter.run("keyring.delete_password('\(service)', 'user_update')") }

        Interpreter.run("keyring.set_password('\(service)', 'user_update', 'old')")
        Interpreter.run("keyring.set_password('\(service)', 'user_update', 'new')")
        let result: String? = Interpreter.evaluate(
            "keyring.get_password('\(service)', 'user_update')"
        )
        #expect(result == "new")
    }

    @Test func getPassword_afterDelete_returnsNone() {
        Interpreter.run("import keyring")
        Interpreter.run("keyring.set_password('\(service)', 'user_delete', 'temp')")
        Interpreter.run("keyring.delete_password('\(service)', 'user_delete')")

        let result: Bool? = Interpreter.evaluate(
            "keyring.get_password('\(service)', 'user_delete') is None"
        )
        #expect(result == true)
    }

    @Test func deletePassword_whenNotFound_doesNotThrow() {
        Interpreter.run("""
        import keyring
        try:
            keyring.delete_password('\(service)', 'user_nonexistent')
            result = True
        except:
            result = False
        """)
        #expect(Interpreter.evaluate("result") == true)
    }
}
