//
//  ViewContainerTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-05-16.
//

@testable import SwiftPy
import Testing

@MainActor
struct ViewContainerTests {
    @Test
    func example() throws {
        Interpreter.run("""
        from views import VStack, Text
        
        stack = VStack(
            Text('text1'),
            Text('text2'),
        )
        
        print(stack)
        print(stack.__dict__.items())
        """)
        
        let stack = try PythonView.cast(.main["stack"])
        
        print(try stack.model())
    }
}
