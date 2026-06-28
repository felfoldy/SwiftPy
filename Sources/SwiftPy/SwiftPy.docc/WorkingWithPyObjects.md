# Working with PyObjects

Hold Python values from Swift and read attributes, call functions, and bridge results back to Swift types.

## Overview

A ``PyObject`` is a safe, reference-counted handle to a Python value. As long as you hold the handle the underlying Python object stays alive, so the reference is always valid and won't be dereferenced out from under you. When the `PyObject` goes out of scope, the value is released automatically.

## Get a PyObject

Evaluate a Python expression and keep its result by asking for a ``PyObject``:
```swift
let numbers: PyObject? = Interpreter.evaluate("[1, 2, 3]")
```

You can also reach into a module to grab one of its members:
```swift
let math = py.module("math")
let sqrt = math?.sqrt   // a PyObject for the function
```

## Read and write attributes

Python attributes are available through ordinary Swift member syntax. Reading an attribute as a ``PyObject`` lets you keep chaining into the value:
```swift
let pi = math?.pi   // PyObject?
```

Annotate the result with a Swift type to bridge the value across automatically:
```swift
let pi: Double? = math?.pi
```

Assigning to a member writes the attribute back on the Python object:
```swift
py.main.config?.retries = 3
```

## Call functions

A ``PyObject`` that wraps a callable can be invoked directly. Annotate the result to bridge it to a Swift type:
```swift
let root: Double = try math!.sqrt(2.0)
```

Use a ``PyObject`` result when you want to keep working with the return value in Python, or ignore the result entirely when you only care about the side effect:
```swift
try py.main.logger?.info("started")
```

Calls throw a ``PythonError`` if the Python side raises an exception.

## Subscript dictionaries

When a ``PyObject`` wraps a dictionary, subscript it by key. As with attributes, you can read the value as another ``PyObject`` or bridge it to a Swift type:
```swift
let env: PyObject? = Interpreter.evaluate("{'name': 'SwiftPy', 'version': 11}")
let name: String? = env?["name"]
env?["version"] = 12
```

## Topics

### Related

- ``PyObject``
- ``PythonConvertible``
- ``Interpreter``
