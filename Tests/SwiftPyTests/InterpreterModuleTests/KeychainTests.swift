//
//  KeychainTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-08.
//

import Testing
@testable import SwiftPy

/// The synchronizable keychain needs an entitlement the test binary has no way
/// to carry, so the tests run against an in-memory store.
@MainActor
final class InMemorySecretStorage: SecretStorage {
    var values: [String: String] = [:]

    func value(for key: String) -> String? { values[key] }

    func set(_ value: String, for key: String) throws(PythonError) {
        values[key] = value
    }

    func remove(_ key: String) throws(PythonError) {
        values[key] = nil
    }
}

@Suite("Keychain", .serialized)
@MainActor
struct KeychainTests {
    private let main = py.main
    private let storage = InMemorySecretStorage()

    init() async {
        Keychain.storage = storage
        await Interpreter.run("import keychain")
    }

    private func restore() {
        Keychain.storage = KeychainStorage()
        // Only the field this suite owns: `Interpreter.interface` is global and
        // replacing it wholesale wipes what a suite running beside us installed.
        Interpreter.interface.requestSecret = InterpreterInterface().requestSecret
    }

    /// `PyBind.blocking` parks the cell on CPython but hands pocketpy the task,
    /// so the call site differs by backend. See `PyBind+Blocking.swift`.
    private func secret(_ key: String) -> String {
        #if cpython
        "keychain.secret('\(key)')"
        #else
        "await keychain.secret('\(key)')"
        #endif
    }

    @Test func storedSecretResolvesWithoutAsking() async {
        defer { restore() }
        storage.values["STORED_KEY"] = "stored value"

        var asked = false
        Interpreter.interface.requestSecret = { _ in
            asked = true
            return "asked value"
        }

        await Interpreter.run("stored = \(secret("STORED_KEY"))")

        #expect(!asked)
        #expect(main.stored?.name == "STORED_KEY")
        #expect(storage.values["STORED_KEY"] == "stored value")
    }

    @Test func missingSecretIsAskedForAndStored() async {
        defer { restore() }

        var askedFor: [String] = []
        Interpreter.interface.requestSecret = { key in
            askedFor.append(key)
            return "sk-entered"
        }

        await Interpreter.run("entered = \(secret("OPENAI_API_KEY"))")

        #expect(askedFor == ["OPENAI_API_KEY"])
        #expect(main.entered?.name == "OPENAI_API_KEY")
        #expect(storage.values["OPENAI_API_KEY"] == "sk-entered")
    }

    @Test func emptyResponseRaisesAndStoresNothing() async {
        defer { restore() }
        Interpreter.interface.requestSecret = { _ in "" }

        await Interpreter.run("""
        try:
            \(secret("EMPTY_KEY"))
            raised = False
        except ValueError:
            raised = True
        """)

        #expect(main.raised == true)
        #expect(storage.values["EMPTY_KEY"] == nil)
    }

    @Test func withoutAHostAMissingSecretRaises() async {
        defer { restore() }

        await Interpreter.run("""
        try:
            \(secret("NO_HOST_KEY"))
            unhandled = False
        except KeyError:
            unhandled = True
        """)

        #expect(main.unhandled == true)
    }

    @Test func setThenDeleteRoundTrips() async {
        defer { restore() }

        var asked = 0
        Interpreter.interface.requestSecret = { _ in
            asked += 1
            return "asked value"
        }

        await Interpreter.run("keychain.set('ROUND_TRIP', 'first')")
        #expect(storage.values["ROUND_TRIP"] == "first")

        await Interpreter.run("keychain.set('ROUND_TRIP', 'second')")
        #expect(storage.values["ROUND_TRIP"] == "second")

        await Interpreter.run("""
        round_trip = \(secret("ROUND_TRIP"))
        keychain.delete(round_trip)
        """)

        #expect(asked == 0)
        #expect(storage.values["ROUND_TRIP"] == nil)

        // Deleting a secret that is not stored is not an error.
        await Interpreter.run("keychain.delete(round_trip)")

        await Interpreter.run("round_trip = \(secret("ROUND_TRIP"))")
        #expect(asked == 1)
        #expect(storage.values["ROUND_TRIP"] == "asked value")
    }

    @Test func secretShowsItsNameAndNotItsValue() async throws {
        defer { restore() }
        storage.values["OPENAI_API_KEY"] = "sk-hidden"

        await Interpreter.run("shown = \(secret("OPENAI_API_KEY"))")

        let secret = try #require(main.shown)
        #expect(try py.repr(secret.reference) == "<Secret name=\"OPENAI_API_KEY\">")

        // The value has no Python attribute of its own.
        #expect(Interpreter.evaluate("hasattr(shown, 'value')") == false)
        #expect((main.shown as Secret?)?.value == "sk-hidden")
    }
}
