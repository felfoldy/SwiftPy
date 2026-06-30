//
//  PyType.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-24.
//

import pocketpy

@MainActor
public extension PyType {
    static let None = PyType(tp_NoneType.rawValue)
    static let bool = PyType(tp_bool.rawValue)
    static let int = PyType(tp_int.rawValue)
    static let str = PyType(tp_str.rawValue)
    static let float = PyType(tp_float.rawValue)
    static let list = PyType(tp_list.rawValue)
    static let tuptle = PyType(tp_tuple.rawValue)
    static let object = PyType(tp_object.rawValue)
    static let dict = PyType(tp_dict.rawValue)
    static let function = PyType(tp_function.rawValue)
    static let staticmethod = PyType(tp_staticmethod.rawValue)
    static let boundmethod = PyType(tp_boundmethod.rawValue)
    static let bytes = PyType(tp_bytes.rawValue)
    static let generator = PyType(tp_generator.rawValue)
    static let module = PyType(tp_module.rawValue)

    // Errors:
    static let BaseException = PyType(tp_BaseException.rawValue)
    static let SyntaxError = PyType(tp_SyntaxError.rawValue)
    static let RecursionError = PyType(tp_RecursionError.rawValue)
    static let OSError = PyType(tp_OSError.rawValue)
    static let NotImplementedError = PyType(tp_NotImplementedError.rawValue)
    static let TypeError = PyType(tp_TypeError.rawValue)
    static let IndexError = PyType(tp_IndexError.rawValue)
    static let ValueError = PyType(tp_ValueError.rawValue)
    static let RuntimeError = PyType(tp_RuntimeError.rawValue)
    static let ZeroDivisionError = PyType(tp_ZeroDivisionError.rawValue)
    static let NameError = PyType(tp_NameError.rawValue)
    static let UnboundLocalError = PyType(tp_UnboundLocalError.rawValue)
    static let AttributeError = PyType(tp_AttributeError.rawValue)
    static let ImportError = PyType(tp_ImportError.rawValue)
    static let AssertionError = PyType(tp_AssertionError.rawValue)
    static let KeyError = PyType(tp_KeyError.rawValue)
    static let StopIteration = PyType(tp_StopIteration.rawValue)

    // MARK: - Convenient extensions.

    @inlinable
    var name: String {
        py.tpname(self)
    }

    // MARK: - Binding methods.
    
    @inlinable
    func magic(_ name: String, function: PyAPI.CFunction) {
        py.setdict(
            py.tpobject(self)!,
            name: name,
            value: py.newnativefunc(function)
        )
    }

    @inlinable
    func property(_ name: String, getter: PyAPI.CFunction, setter: PyAPI.CFunction? = nil) {
        py.bindproperty(
            type: self,
            name: name,
            getter: getter,
            setter: setter
        )
    }

    @inlinable
    func function(_ signature: String, _ docstring: String? = nil, block: PyAPI.CFunction) {
        py.tpobject(self)?.bind(
            signature,
            docstring: docstring,
            overloads: true,
            function: block,
        )
    }

    @inlinable
    func staticmethod(_ signature: String, _ docstring: String? = nil, function: PyAPI.CFunction) {
        let typeObject = py.tpobject(self)!

        // Create the underlying function.
        let functionRef = py.pushtmp()
        defer { py.pop() }
        let name = py.newfunction(functionRef, signature: signature, docstring: docstring, function: function)

        // Overload an existing static method of the same name.
        if let existing = py.getdict(typeObject, name: name) {
            // The wrapped callable lives in the staticmethod's only slot.
            let underlying = py_getslot(existing, 0)!

            // Already a dispatcher: just append the new overload.
            if let overloads = py.getdict(underlying, name: "_overloads") {
                py.list.append(overloads, value: functionRef)
                return
            }

            // Build a dispatcher wrapping the existing and the new function.
            let dispatcher = py.pushtmp()
            defer { py.pop() }
            functionRef.makeFunctionOverload(dispatcher, name: name, isInstance: false)

            let list = py.pushtmp()
            defer { py.pop() }
            py.newlist(list)
            py.list.append(list, value: underlying)
            py.list.append(list, value: functionRef)
            py.setdict(dispatcher, name: "_overloads", value: list)

            let staticmethod = try! py.call(py.tpobject(.staticmethod)!, args: dispatcher)
            py.setdict(typeObject, name: name, value: staticmethod)
            return
        }

        // First binding for this name.
        let staticmethod = try! py.call(py.tpobject(.staticmethod)!, args: functionRef)
        py.setdict(typeObject, name: name, value: staticmethod)
    }

    @inlinable
    static func make(_ name: String,
                     base: PyType = .object,
                     module: PyRef? = nil,
                     bind: (PyType) -> Void) -> PyType {
        let type = py.newtype(
            name: name,
            base: base,
            module: module
        ) { userdata in
            // Dtor callback.
            guard let pointer = userdata?.load(as: UnsafeRawPointer?.self) else {
                return
            }

            // Tale retained value.
            let unmanaged = Unmanaged<AnyObject>.fromOpaque(pointer)
            let obj = unmanaged.takeRetainedValue()

            // Clear cache.
            if let bindable = (obj as? PythonBindable) {
                bindable._pythonCache.reference?.deinitialize(count: 1)
                bindable._pythonCache.reference?.deallocate()
                bindable._pythonCache.reference = nil
            }
        }

        bind(type)
        return type
    }
}
