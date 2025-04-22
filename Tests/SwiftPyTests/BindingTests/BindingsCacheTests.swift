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
        var number: Int

        class Binding: PythonValueBindable<BindableStruct> {
            var number: Int? {
                get { value?.number }
                set {
                    if let newValue {
                        value?.number = newValue
                    }
                }
            }

            static let pyType = PyType.make("BindableStruct") { type in
                type.property("value") {
                    _bind_getter(\.number, $1)
                } setter: { _bind_setter(\.number, $1) }
            }
        }
    }

    class TestClass: PythonBindable, HasSlots {
        enum Slot: Int32, CaseIterable {
            case base
        }
        
        var base: BindableStruct = .init(number: 1)
        
        var _pythonCache = PythonBindingCache()
        
        static let pyType = PyType.make("BindingsCacheTests_TestClass") { type in
            type.property("base") { _, argv in
                _bind_slot(.base, argv) { root in
                    BindableStruct.Binding(root, \.base)
                }
            } setter: { _, argv in
                _castSelfArgs(argv) { (root, binding: BindableStruct.Binding) in
                    PyAPI.returnNone {
                        if let value = binding.get() {
                            root.base = value
                        }
                    }
                }
            }
            type.object?.setAttribute("_interface",
                #"""
                class BindingsCacheTests_TestClass(builtins.object):
                    base: BindableStruct
                """#
                .toRegister(0)
            )
        }
    }
    
    let main = Interpreter.main
    let type = TestClass.pyType
    
    @Test func accessStruct() throws {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        obj.base = BindableStruct(number: 100)
        
        #expect(Interpreter.evaluate("obj.base.value") == 100)
    }
    
    @Test func setStruct() async throws {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        
        BindableStruct.Binding(.init(number: 2))
            .toPython(main.emplace("newbase"))
        #expect(Interpreter.evaluate("obj.base.value") == 1)
        
        Interpreter.input("obj.base = newbase")
        // Should return cached binding.
        #expect(Interpreter.evaluate("obj.base.value") == 2)
    }
    
    @Test func valueBindingSetter() async {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        
        Interpreter.run("obj.base.value = 2")
        #expect(obj.base.number == 2)
    }
    
    @Test func classAttribute() {
        let interface = Interpreter.evaluate("BindingsCacheTests_TestClass._interface")
        
        #expect(interface == """
        class BindingsCacheTests_TestClass(builtins.object):
            base: BindableStruct
        """)
    }
}
