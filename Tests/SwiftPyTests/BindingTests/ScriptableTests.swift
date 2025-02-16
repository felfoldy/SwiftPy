//
//  ScriptableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import Testing
import SwiftPy

@Scriptable
class TestClassWithProperties {
    let intProperty: Int = 12
    var content: String = "content"
    
    func testFunction() {
        content = "changed"
    }
}

@MainActor
struct ScriptableTests {
    let main = Interpreter.main
    let type = TestClassWithProperties.pyType
    
    @Test func dtor() {
        Interpreter.run("import gc")
        
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc1"))
        #expect(testClass._cachedPythonReference != nil)
        
        Interpreter.run("del tc1")
        Interpreter.run("gc.collect()")
        #expect(testClass._cachedPythonReference == nil)
    }
    
    @Test func bindIntProperty() {
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc2"))
        
        #expect(Interpreter.evaluate("tc2.int_property") == 12)
    }

    @Test func bindStringProperty() {
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc3"))
        Interpreter.run("tc3.content = 'new content'")
        
        #expect(Interpreter.evaluate("tc3.content") == "new content")
    }
    
    @Test func functionCall() {
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc4"))
        Interpreter.run("tc4.test_function()")
        
        #expect(testClass.content == "changed")
    }
}
