//
//  ScriptableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-11.
//

import Testing
import SwiftPy

/// The TestClass.
@Scriptable("TestClass2", base: .object)
class TestClassWithProperties: PythonBindable {
    typealias TestClass2 = TestClassWithProperties
    
    /// Int constant.
    let intProperty: Int? = 12
    /// float of 3.14
    var floatProperty: Float = 3.14
    /// str content
    var content: String = "content"
    
    static let staticProperty: String = "static"
    
    init() {}
    
    func changeContent(value: String) { content = value }
    func getContent() -> String { content }
    func fetch(query: String = "0") async -> Int? { Int(query) }
    static func create() -> TestClass2 {
        TestClassWithProperties()
    }
    static func asyncCreate() async -> TestClass2 {
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
    
    subscript(text: String) -> String {
        text
    }
}

@MainActor
struct ScriptableTests {
    let main = PyModule.main
    let type = TestClassWithProperties.pyType
    
    @Test func dtor() {
        Interpreter.run("import gc")
        
        let testClass = TestClassWithProperties()
        main.tc1 = testClass
        #expect(testClass._pythonCache.reference != nil)
        
        Interpreter.run("del tc1")
        Interpreter.run("gc.collect()")
        #expect(testClass._pythonCache.reference == nil)
    }
    
    @Test func bindIntProperty() {
        let testClass = TestClassWithProperties()

        main.tc2 = testClass
        
        #expect(Interpreter.evaluate("tc2.int_property") == 12)
    }
    
    @Test func bindFloatProperty() {
        let testClass = TestClassWithProperties()
        main.tc5 = testClass
        
        #expect(Interpreter.evaluate("tc5.float_property") == Float(3.14))

        Interpreter.run("tc5.float_property = 1000.0")        
        #expect(testClass.floatProperty == 1000.0)
    }

    @Test func bindStringProperty() {
        let testClass = TestClassWithProperties()
        main.tc3 = testClass
        Interpreter.run("tc3.content = 'new content'")
        
        #expect(Interpreter.evaluate("tc3.content") == "new content")
    }
    
    @Test func functionCall() {
        let testClass = TestClassWithProperties()

        main.tc4 = testClass

        Interpreter.run("tc4.change_content('changed')")
        
        #expect(Interpreter.evaluate("tc4.get_content()") == "changed")
    }
    
    @Test func staticFuncTests() async throws {
        main.TestClass2 = TestClassWithProperties.pyType.object
        Interpreter.run("TestClass2.log('asd')")
        
        Interpreter.run("tc5 = TestClass2.create()")
        #expect(TestClassWithProperties(main.tc5) != nil)

        Interpreter.run("""
        tc6 = TestClass2.map('map')
        content = tc6.content
        """)
        
        #expect(main.content == "map")

        Interpreter.run("""
        tc6 = TestClass2.map(None)
        content = tc6.content
        """)
        
        #expect(main.content == "")
        
        await Interpreter.asyncRun("""
        tc7 = await TestClass2.async_create()
        """)
        
        #expect(TestClassWithProperties(main.tc7) != nil)
    }
    
    @Test func returningArgumentedFunction() async {
        let type = PyObject(TestClassWithProperties.pyType)
        Interpreter.main.setAttribute("TestClass2", type.reference)

        await Interpreter.asyncRun("""
        tc8 = TestClass2.create()
        number = await tc8.fetch('4')
        number2 = await tc8.fetch()
        """)
        
        #expect(main.number == 4)
        #expect(main.number2 == 0)
    }
    
    @Test func staticProperty() {
        let testClass = TestClassWithProperties()
        main.tc3 = testClass
        
        #expect(main.tc3?.static_property == TestClassWithProperties.staticProperty)
    }
}
