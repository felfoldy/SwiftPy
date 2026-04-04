//
//  ViewRepresentationTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-05.
//

import Testing
import SwiftPy
import SwiftUI

@Scriptable
class CustomView: ViewRepresentable {
    var view: some View {
        Text("content")
    }
}

@MainActor
struct ViewRepresentationTests {
    class TestIOStream: IOStream {
        var view: ViewRepresentation?
        
        func input(_ str: String) {}
        func stdout(_ str: String) {}
        func stderr(_ str: String) {}
        func executionTime(_ time: UInt64) {}
        
        func view(_ view: ViewRepresentation) {
            self.view = view
        }
    }
    
    @Test
    func customView() {
        let main = PyModule.main
        let io = TestIOStream()
        Interpreter.output = io
        
        _ = ViewRepresentation.pyType
        _ = CustomView.pyType
        
        let customView = CustomView()
        main.custom_view = customView

        Interpreter.run("custom_view", mode: .single)

        #expect(io.view != nil)
    }
}
