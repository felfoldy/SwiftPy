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
    let value: String

    init(value: String) {
        self.value = value
    }

    init() {
        value = "default"
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
        type.magic("__view__") { __view__($1) }
        type.property(
            "value",
            getter: { _bind_getter(\.value, $1) },
            setter: nil
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
    func __view__binding() throws {
        Interpreter.run("""
        viewBinding = StructView()
        """)

        let viewBinding = try #require(py.main.viewBinding)
        let view: AnyView? = try viewBinding.__view__?()
        
        #expect(view != nil)
    }
}
