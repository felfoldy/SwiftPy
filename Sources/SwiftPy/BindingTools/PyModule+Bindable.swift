//
//  PyModule+Bindable.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-09.
//


public extension PyModule {
    func classes(_ types: PythonBindable.Type...) {
        for type in types { `class`(type) }
    }

    @discardableResult
    func `class`(_ type: PythonValueBindable.Type) -> PyModule {
        let type = type.pyType
        #if cpython
        let object = type.object
        self[dynamicMember: type.name] = object
        // A type made without a module is named `builtins.<name>`; the first
        // module to register it becomes its home.
        if object.__module__ as String? == "builtins" {
            object.__module__ = self.__name__
        }
        #else
        // Not setattr: on a pocketpy module that does not reach the dict, and
        // the failure is swallowed, leaving the class silently unregistered.
        py.setdict(reference, name: type.name, value: py.tpobject(type))
        #endif
        return self
    }
}
