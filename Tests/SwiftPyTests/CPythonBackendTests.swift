//
//  CPythonBackendTests.swift
//  SwiftPy
//

#if cpython
import Testing
import Foundation
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct CPythonBackendTests {


    /// A whole cell, the way pocketpy's `.single` mode takes one: several
    /// statements, with each expression echoing its value.
    @Test func cellEchoesEveryExpression() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.compile(id: 1, source: "a = 1\na + 1\nprint('hi')\n2 + 2")
        await connection.run(id: 1)

        var text = ""
        for await event in stream {
            if case let .stdout(chunk) = event.payload { text += chunk }
            if case .attachment = event.payload { break }
        }
        #expect(text == "2\nhi\n4\n")
    }

    @Test func exceptionArrivesAsStderrWithTheFailureAttachment() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.compile(id: 1, source: "raise ValueError('nope')")
        await connection.run(id: 1)

        var text = ""
        var items: [InputAttachment] = []
        for await event in stream {
            if case let .stderr(chunk) = event.payload { text += chunk }
            if case let .attachment(attachments) = event.payload {
                items = attachments
                break
            }
        }
        // The traceback is colorized; compare it without the escape codes.
        let plain = text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
        #expect(plain.contains("ValueError: nope"))
        #expect(plain.contains("<script>/1"))
        #expect(items.contains(.image(name: "exclamationmark.triangle")))
    }

    /// The connection holds the compiled code, so a second compile releases the
    /// first on the actor's thread — where a decref has no thread state.
    @Test func releasingCodeOffTheMainThreadIsSafe() async {
        let connection = LocalInterpreterConnection()
        await connection.compile(id: 1, source: "import sys")
        await connection.run(id: 1)
        await connection.compile(id: 2, source: "import sys")
        await connection.run(id: 2)
    }

    @Test func syntaxErrorsAreReportedAtCompileTime() async {
        let connection = LocalInterpreterConnection()
        let stream = await connection.events

        await connection.compile(id: 1, source: "def f(")

        var text = ""
        var items: [InputAttachment] = []
        for await event in stream {
            if case let .stderr(chunk) = event.payload { text += chunk }
            if case let .attachment(attachments) = event.payload {
                items = attachments
                break
            }
        }
        #expect(text.contains("SyntaxError"))
        #expect(items.contains(.image(name: "xmark.square")))
    }
}
#endif
