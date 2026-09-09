//
//  PyModule+Bindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//

import PocketPython

public extension PyModule {
    func classes(_ types: PythonBindable.Type...) {
        for type in types { `class`(type) }
    }

    @discardableResult
    func `class`(_ type: PythonValueBindable.Type) -> PyModule {
        let type = type.pyType
        py.setdict(reference, name: type.name, value: py.tpobject(type))
        return self
    }
}
