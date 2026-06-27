//
//  ViewRepresentationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-05.
//

import Testing
import SwiftPy
import SwiftUI

@Scriptable(base: .View)
class CustomView {
    func body() -> AnyView {
        AnyView(Text("content"))
    }
}

@MainActor
struct ViewRepresentationTests {
    @Test
    func customView() {
        let main = py.main

        var displayed: AnyView?
        Interpreter.onDisplay = { displayed = $0 }
        defer { Interpreter.onDisplay = { _ in } }

        _ = AnyView.pyType
        _ = CustomView.pyType

        let customView = CustomView()
        main.custom_view = customView

        Interpreter.run("custom_view", mode: .single)

        #expect(displayed != nil)
    }
}
