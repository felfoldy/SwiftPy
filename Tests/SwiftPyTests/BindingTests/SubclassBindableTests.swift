//
//  SubclassBindableTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-03-28.
//

import Testing
import SwiftPy

@Scriptable
private class Base: PythonBindable {
    var startCalled = false
    
    init() {}
    
    func start() {
        startCalled = true
    }
}

@MainActor
@Suite(.serialized)
struct SubclassBindableTests {
    let main = py.main
    let type = Base.pyType
    
    init() async {
        main.Base = PyObject(Base.pyType)
        await Interpreter.run("""
        class Subclass(Base):
            def __init__(self):
                super().__init__()
                self.val = 'val'

        subclass_test = Subclass()
        """)
    }
    
    @Test func startCalled() async {
        let base: Base? = main.subclass_test
        await Interpreter.run("subclass_test.start()")
        
        #expect(base?.startCalled == true)
    }
    
    @Test func removeCache() async {
        await Interpreter.run("""
        test2 = Base()
        """)
        
        let base: Base? = Interpreter.evaluate("test2")
        await Interpreter.run("""
        import gc
        
        del test2
        gc.collect()
        """)
        
        #expect(main.test2 == nil)
        #expect(base?._pythonCache.reference == nil)
    }
}
