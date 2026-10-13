//
//  ClipboardTests.swift
//  SwiftPy
//

import Testing
@testable import SwiftPy

@MainActor
final class InMemoryClipboard: ClipboardStorage {
    var string: String?
}

@Suite("Clipboard", .serialized)
@MainActor
struct ClipboardTests {
    private let main = py.main
    private let clipboard = InMemoryClipboard()

    init() async {
        Clipboard.storage = clipboard
        await Interpreter.run("import clipboard")
    }

    @Test func copiesAndPastes() async {
        defer { Clipboard.storage = SystemClipboard() }

        await Interpreter.run("""
        _empty = clipboard.paste()
        clipboard.copy("#1A334C")
        _pasted = clipboard.paste()
        """)

        #expect(main._empty == nil)
        #expect(clipboard.string == "#1A334C")
        #expect(main._pasted == "#1A334C")
    }
}
