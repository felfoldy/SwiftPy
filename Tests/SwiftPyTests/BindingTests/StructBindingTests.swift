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
struct StructView: View {
    var value: String

    init(value: String) {
        self.value = value
    }

    init() {
        value = "default"
    }

    static func make(value: String) -> StructView {
        StructView(value: value)
    }

    static func make() -> StructView {
        StructView()
    }

    var body: some View {
        Text(value)
    }
}

extension StructView: PythonValueBindable {
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
        type.function("__init__(self) -> None") {
            __init__($1, StructView.init)
        }
        type.staticmethod("make(value: str) -> StructView") {
            PyBind.function($0, $1, StructView.make(value:))
        }
        type.staticmethod("make() -> StructView") {
            PyBind.function($0, $1) { StructView.make() }
        }
        type.property(
            "value",
            getter: { _bind_getter(\.value, $1) },
            setter: { _bind_setter(\.value, $1) }
        )

        return type
    }()
}

@MainActor
struct StructBindingTests {
    init() {
        py.main.StructView = PyObject(StructView.pyType)
    }
    
    @Test
    func initializerBinding() throws {
        Interpreter.run("""
        view = StructView('content')
        value = view.value
        """)
        
        let view: StructView = try #require(py.main.view)
        #expect(view.value == "content")
        #expect(py.main.value == "content")
    }
    
    @Test
    func setter() throws {
        Interpreter.run("""
        view = StructView('content')
        view.value = 'new content'
        """)
        
        let value: String = try #require(py.main.view?.value)
        #expect(value == "new content")
    }

    @Test
    func staticMethodOverload() throws {
        Interpreter.run("""
        a = StructView.make('content')
        b = StructView.make()
        """)

        #expect(py.main.a?.value == "content")
        #expect(py.main.b?.value == "default")
    }
}
