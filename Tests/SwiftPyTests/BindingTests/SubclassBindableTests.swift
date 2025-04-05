//
//  SubclassBindableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-28.
//

import Testing
import SwiftPy
import pocketpy

@MainActor
struct SubclassBindableTests {
    class Base: PythonBindable {
        var _pythonCache = PythonBindingCache()
        var startCalled = false
        
        static var pyType: PyType = .make("Base") { type in
            type.magic("__init__") { _, argv in
                Base().storeInPython(argv)
                return PyAPI.return(.none)
            }
            type.function("start(self) -> None") { _, argv in
                Base(argv)?.startCalled = true
                return PyAPI.return(.none)
            }
        }
    }
    
    let main = Interpreter.main
    let type = Base.pyType
    
    init() {
        Interpreter.run("""
        class Subclass(Base):
            def __init__(self):
                super().__init__()
                self.val = 'val'

        test = Subclass()
        """)
    }
    
    @Test func startCalled() {
        let base = Base(main["test"])
        Interpreter.run("test.start()")
        
        #expect(base?.startCalled == true)
    }
    
    @Test func removeCache() {
        Interpreter.run("""
        test2 = Base()
        """)
        
        let base = Base(main["test2"])
        Interpreter.run("""
        import gc
        
        del test2
        gc.collect()
        """)
        
        #expect(main["test2"] == nil)
        withKnownIssue("Its like dtor callback not working?") {
            #expect(base?._pythonCache.reference == nil)
        }
    }
}
