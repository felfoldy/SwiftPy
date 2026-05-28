//
//  StructBindingTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-05-27.
//

import SwiftPy
import SwiftUI
import Testing

@MainActor
struct StructView {
    let value: String
    
    init() {
        value = "default"
    }
    
    init(value: String) {
        self.value = value
    }
}

extension StructView: PythonValueObject {
    func toPython(_ reference: PyRef) {
        py.newobject(
            Optional(self),
            type: Self.pyType,
            out: reference,
            slots: -1
        )
    }
    
    @inlinable
    static func fromPython(_ reference: PyRef) -> StructView {
        reference.toUserdata(as: Self?.self)!
    }
    
    static let pyType: PyType = {
        let type = py.newtype(
            name: "StructView",
            base: .object,
            module: nil,
            dtor: { Self?.deinitialize(userdata: $0) }
        )
        type.magic("__new__") { __new__($1) }
        type.function("__init__(self, value: str) -> None") { argc, argv in
            __init__(argc, argv, StructView.init(value:))
        }
        type.property(
            "value",
            getter: { _bind_getter(\.value, $1) },
            setter: nil
        )
        return type
    }()
}

protocol PythonValueObject: PythonConvertible {}

enum OverloadError: Error {
    case argumentMismatch
    case functionFailure(any Error)
}

extension PythonValueObject {
    static func __new__(_ argv: PyRef?) -> Bool {
        let type = py.totype(argv)
        py.newobject(
            Self?.none,
            type: type,
            out: py.retval,
            slots: -1
        )
        return true
    }
    
    @inlinable
    static func __init__<each Arg: PythonConvertible>(
        _ argc: Int32, _ argv: PyRef?,
        _ initializer: @MainActor (repeat each Arg) throws -> Self
    ) -> Bool {
        PyAPI.return {
            let result = try PyBind.castArgs(argc: argc, argv: argv, from: 1) as (repeat each Arg)
            try initializer(repeat (each result)).storeInPython(argv)
            return .none
        }
    }
    
    @inlinable
    func storeInPython(_ reference: PyRef?) {
        reference?.userdata
            .assumingMemoryBound(to: Self?.self)
            .pointee = self
    }

    @inlinable
    static func _bind_getter<Value>(_ keypath: KeyPath<Self, Value>, _ argv: PyRef?) -> Bool {
        PyAPI.return { Self(argv)?[keyPath: keypath] }
    }
}

@MainActor
struct StructBindingTests {
    @Test
    func initializerBinding() throws {
        py.main.StructView = PyObject(StructView.pyType)
        
        Interpreter.run("""
        view = StructView('content')
        value = view.value
        """)
        
        let view: StructView = try #require(py.main.view)
        #expect(view.value == "content")
        #expect(py.main.value == "content")
    }
}
