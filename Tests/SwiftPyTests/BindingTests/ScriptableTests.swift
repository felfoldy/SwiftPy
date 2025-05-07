//
//  ScriptableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import Testing
import SwiftPy

/// The TestClass.
@Scriptable("TestClass2")
class TestClassWithProperties: PythonBindable {
    typealias TestClass2 = TestClassWithProperties
    
    /// Int constant.
    let intProperty: Int? = 12
    /// float of 3.14
    var floatProperty: Float = 3.14
    /// str content
    var content: String = "content"
    
    init() {}
    
    func changeContent(value: String) { content = value }
    func getContent() -> String { content }
    func fetch(query: String = "0") -> Int? { Int(query) }
    static func create() -> TestClass2 {
        TestClassWithProperties()
    }
    static func map(content: String?) -> TestClass2 {
        let tc = TestClassWithProperties()
        tc.content = content ?? ""
        return tc
    }
    static func log(message: String) throws {
        throw PythonError.NotImplementedError(message)
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
    
    @Test func staticFuncTests() {
        Interpreter.run("TestClass2.log('asd')")
        
        Interpreter.run("tc5 = TestClass2.create()")
        #expect(main["tc5"]?.isType(TestClassWithProperties.self) == true)

        Interpreter.run("""
        tc6 = TestClass2.map('map')
        content = tc6.content
        """)
        
        #expect(main["content"] == "map")

        Interpreter.run("""
        tc6 = TestClass2.map(None)
        content = tc6.content
        """)
        
        #expect(main["content"] == "")
    }
    
    @Test func returningArgumentedFunction() {
        Interpreter.run("""
        tc7 = TestClass2.create()
        number = tc7.fetch('4')
        number2 = tc7.fetch()
        """)
        
        #expect(main["number"] == 4)
        #expect(main["number2"] == 0)
    }
}
