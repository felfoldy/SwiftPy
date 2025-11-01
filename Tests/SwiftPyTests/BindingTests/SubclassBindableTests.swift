//
//  SubclassBindableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-28.
//

import Testing
import SwiftPy
import pocketpy

@Scriptable
private class Base: PythonBindable {
    var startCalled = false
    
    init() {}
    
    func start() {
        startCalled = true
    }
}

@MainActor
struct SubclassBindableTests {
    let main = Interpreter.main
    let type = Base.pyType
    
    init() {
        Interpreter.main.setAttribute("Base", Base.pyType.object)
        Interpreter.run("""
        class Subclass(Base):
            def __init__(self):
                super().__init__()
                self.val = 'val'

        subclass_test = Subclass()
        """)
    }
    
    @Test func startCalled() {
        let base = Base(main["subclass_test"])
        Interpreter.run("subclass_test.start()")
        
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
        #expect(base?._pythonCache.reference == nil)
    }
}
