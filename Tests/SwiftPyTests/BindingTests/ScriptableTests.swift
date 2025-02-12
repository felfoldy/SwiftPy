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
}
