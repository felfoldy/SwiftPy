//
//  Interpreter+bindFunctools.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026. 07. 08.
//

import pocketpy

extension Interpreter {
    func bindFunctools() {
        py_import("functools")
        let functools = PyObject(py.retval)

        functools.def(
            "wraps(wrapped)",
            docs: "Decorator factory to make a wrapper function look like the wrapped function."
        ) { argc, argv in
            PyBind.function(argc, argv, wraps(wrapped:))
        }
    }

    
}

@MainActor
private func wraps(wrapped: PyObject) -> PyObject {
    // named `deco` so the closure below resolves `decorator(wrapper:)` globally
    let deco = PyObject {
        py.newfunction(
            $0,
            signature: "decorator(wrapper)",
            docstring: nil
        ) { argc, argv in
            PyBind.function(argc, argv, decorator(wrapper:))
        }
    }
    deco._wrapped = wrapped
    return deco
}

@MainActor
func decorator(wrapper: PyObject) throws(PythonError) -> PyObject {
    let function = py.retain(py_inspect_currentfunction())
    guard let wrapped = function?._wrapped,
          let name: String = wrapped.__name__ else {
        throw .TypeError("wraps() lost its wrapped function")
    }
    let doc: String? = wrapped.__doc__

    var plan: PyObject?
    var sig = "\(name)(*args, **kwargs)"

    if let inspect = py.module("inspect"),
       let signatureData = inspect._signature_data,
       let signature = inspect.signature,
       let signaturePlan = try? signatureData(wrapped),
       let sigObj = try? signature(wrapped),
       let sigText = try? py.str(sigObj.reference) {
        plan = signaturePlan
        sig = name + sigText
    }

    let forwarder = PyObject {
        py.newfunction(
            $0,
            signature: sig,
            docstring: doc,
            function: wrapsForwarder
        )
    }

    if let plan {
        forwarder._plan = plan
    }

    forwarder._wrapper = wrapper
    forwarder.__wrapped__ = wrapped
    return forwarder
}

@MainActor
let wrapsForwarder: PyAPI.CFunction = { _, argv in
    let function = PyObject(py_inspect_currentfunction())
    // Read from the dict before nested calls overwrite curr_function.
    guard let wrapper = function?._wrapper else {
        return PyAPI.throw(.RuntimeError, "wraps() forwarder lost its wrapper")
    }

    py.push(wrapper.reference)
    py.pushnil()

    var argc: Int32 = 0
    var kwargc: Int32 = 0

    if let plan = function?._plan {
        for i in 0..<py.tuple.len(plan.reference) {
            let entry = py.tuple.getitem(plan.reference, i: i)
            let kind = py.toint(py.tuple.getitem(entry, i: 1)!)
            let local = argv?[Int(i)]

            switch kind {
            case 2:  // *args tuple
                argc += PyBind.forwardArgs(local)
            case 3:  // keyword-only (after *args), pass by name
                let keyName = py_name(py_tostr(py.tuple.getitem(entry, i: 0)))
                py.newint(py.pushtmp(), value: Int(bitPattern: keyName))
                py.push(local)
                kwargc += 1
            case 4:  // **kwargs dict
                kwargc += PyBind.forwardKwargs(local)
            default:  // positional, defaults already bound
                py.push(local)
                argc += 1
            }
        }
    } else {
        // Fallback signature: (*args, **kwargs).
        argc = PyBind.forwardArgs(argv?[0])
        kwargc = PyBind.forwardKwargs(argv?[1])
    }

    return py_vectorcall(UInt16(argc), UInt16(kwargc))
}
