//
//  BindingsCacheTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-02-21.
//

import Testing
import SwiftPy

@MainActor
struct BindingsCacheTests {
    struct BindableStruct {
        var value: Int

        class Binding: PythonValueBindable<BindableStruct> {
            static let pyType = PyType.make("BindableStruct") { userdata in
                deinitFromPython(userdata)
            } bind: { type in
                type.property("value") { _, argv in
                    PyAPI.return(Binding(argv)?.get()?.value)
                } setter: { _, argv in
                    let binding = Binding(argv)
                    binding?.value?.value = Int(argv?[1])!
                    return PyAPI.return(.none)
                }
            }
        }
    }

    class TestClass: PythonBindable {
        var base: BindableStruct = .init(value: 1)
        
        var _pythonCache = PythonBindingCache()
        
        static let pyType = PyType.make("BindingsCacheTests_TestClass") { userdata in
            deinitFromPython(userdata)
        } bind: { type in
            type.property("base") { _, argv in
                guard let obj = TestClass(argv) else {
                    return PyAPI.return(.none)
                }
                return obj._cached("base") {
                    BindableStruct.Binding(obj, \.base)
                }
            } setter: { _, argv in
                guard let arg1 = BindableStruct.Binding(argv?[1])?.get() else {
                    return PyAPI.throw(.TypeError, "Invalid argument")
                }
                TestClass(argv)?.base = arg1
                return PyAPI.return(.none)
            }
        }
    }
    
    let main = Interpreter.main
    let type = TestClass.pyType
    
    @Test func accessStruct() throws {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        obj.base = BindableStruct(value: 100)
        
        #expect(Interpreter.evaluate("obj.base.value") == 100)
    }
    
    @Test func setStruct() throws {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        
        BindableStruct.Binding(.init(value: 2)).toPython(main.emplace("newbase"))
        #expect(Interpreter.evaluate("obj.base.value") == 1)
        
        Interpreter.input("obj.base = newbase")
        // Should return cached binding.
        #expect(Interpreter.evaluate("obj.base.value") == 2)
    }
    
    @Test func valueBindingSetter() {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        
        Interpreter.run("obj.base.value = 2")
        #expect(obj.base.value == 2)
    }
}
