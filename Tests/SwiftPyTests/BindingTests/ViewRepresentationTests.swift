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
    let representation = ViewRepresentation {
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
        let io = TestIOStream()
        Interpreter.output = io
        
        _ = CustomView.pyType
        
        let customView = CustomView()
        customView.toPython(.main.emplace("custom_view"))
        
        Interpreter.run("custom_view", mode: .single)
        
        #expect(io.view === customView.representation)
    }
}
