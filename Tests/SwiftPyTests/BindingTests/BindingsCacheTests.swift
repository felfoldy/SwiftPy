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
            static let pyType = PyType.make("BindableStruct") { type in
                type.property("value") { _, argv in
                    PyAPI.return(Binding(argv)?.get()?.value)
                } setter: { _, argv in
                    ensureArguments(argv, Int.self) { binding, newValue in
                        binding.value?.value = newValue
                    }
                }
            }
        }
    }

    class TestClass: PythonBindable, HasSlots {
        enum Slot: Int32, CaseIterable {
            case base
        }
        
        var base: BindableStruct = .init(value: 1)
        
        var _pythonCache = PythonBindingCache()
        
        static let pyType = PyType.make("BindingsCacheTests_TestClass") { type in
            type.property("base") { _, argv in
                _bind_slot(.base, argv) { root in
                    BindableStruct.Binding(root, \.base)
                }
            } setter: { _, argv in
                ensureArguments(argv, BindableStruct.Binding.self) { root, binding in
                    if let value = binding.get() {
                        root.base = value
                    }
                }
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
    
    @Test func setStruct() async throws {
        let obj = TestClass()
        obj.toPython(main.emplace("obj"))
        
        BindableStruct.Binding(.init(value: 2))
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
        #expect(obj.base.value == 2)
    }
}
