//
//  PyArgumentsTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-25.
//

import Testing
import SwiftPy

@Scriptable
final class PyArgumentTests_SUT: PythonBindable {
    let a: Int

    var slotBind: String? {
        self[.result]
    }
    
    init(_ args: PyArguments) throws {
        try args.expectedArgCount(3)

        a = try args.cast(1)
        args[Slot.result] = args[2]
    }
}

extension PyArgumentTests_SUT: HasSlots {
    enum Slot: Int32, CaseIterable {
        case result
    }

    func setSlot(_ slot: Slot, value: PyAPI.Reference, to args: PyArguments) {
        args.value?[slot: slot.rawValue] = value
    }
}

@MainActor
struct PyArgumentsTests {
    @Test func argumentsInit() {
        _ = PyArgumentTests_SUT.pyType
        
        Interpreter.run("argumentsInit_result = PyArgumentTests_SUT(12, 'slot')")
        
        #expect(Interpreter.evaluate("argumentsInit_result.a") == 12)
        #expect(Interpreter.evaluate("argumentsInit_result.slot_bind") == "slot")
    }
}
