//
//  ScriptableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import Testing
import SwiftPy

@Scriptable("TestClass2", module: Interpreter.main)
class TestClassWithProperties: PythonBindable {
    let intProperty: Int? = 12
    var floatProperty: Float = 3.14
    var content: String = "content"
    
    init() {}
    
    func changeContent(value: String) { content = value }
    func getContent() -> String { content }
}

@MainActor
struct ScriptableTests {
    let main = Interpreter.main
    let type = TestClassWithProperties.pyType
    
    @Test func dtor() {
        Interpreter.run("import gc")
        
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc1"))
        #expect(testClass._pythonCache.reference != nil)
        
        Interpreter.run("del tc1")
        Interpreter.run("gc.collect()")
        #expect(testClass._pythonCache.reference == nil)
    }
    
    @Test func bindIntProperty() {
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc2"))
        
        #expect(Interpreter.evaluate("tc2.int_property") == 12)
    }
    
    @Test func bindFloatProperty() {
        let testClass = TestClassWithProperties()
        testClass.toPython(main.emplace("tc5"))
        
        #expect(Interpreter.evaluate("tc5.float_property") == Float(3.14))

        Interpreter.run("tc5.float_property = 1000.0")        
        #expect(testClass.floatProperty == 1000.0)
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
        Interpreter.run("tc4.change_content('changed')")
        
        #expect(Interpreter.evaluate("tc4.get_content()") == "changed")
    }
}
