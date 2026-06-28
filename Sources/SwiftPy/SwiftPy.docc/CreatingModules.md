# Creating a Module

Expose Swift types and functions to Python by registering your own module.

## Overview

A module is the unit Python code imports to reach your Swift code. The usual building block is a Swift class exposed with the ``Scriptable(_:base:convertsToSnakeCase:)`` macro, which you then register in a module by name with ``PyBind/module(_:block:)``.

The module is created lazily the first time it is imported, so registering it is cheap — nothing runs until Python actually needs it. Register your modules once during start up, before any script that imports them runs.

## Expose a Swift class

Apply the ``Scriptable(_:base:convertsToSnakeCase:)`` macro to a class to make it usable from Python. The macro conforms the type to ``PythonBindable`` and exposes its initializer, properties, and methods. Names are converted to `snake_case` to match Python conventions:
```swift
@Scriptable
final class Counter {
    var count: Int = 0

    init() {}

    func increment(by amount: Int) {
        count += amount
    }
}
```

## Register the module

Call ``PyBind/module(_:block:)`` with the name Python will import and register the type with ``PyModule/class(_:)`` (or several at once with ``PyModule/classes(_:)``):
```swift
PyBind.module("game") { module in
    module.class(Counter.self)
}
```

Once registered, the class can be imported and used from Python. Notice `increment(by:)` is exposed as `increment`:
```python
from game import Counter

counter = Counter()
counter.increment(5)
print(counter.count)   # 5
```

## Add a function

Modules can also expose standalone functions. Use ``PyModule/def(_:docstring:function:)`` with a signature written in Python syntax, including type annotations; an optional docstring shows up in Python's `help()`. Inside the body, ``PyBind/function(_:_:_:)`` bridges the arguments to Swift types and converts your return value back to Python:
```swift
PyBind.module("greetings") { module in
    module.def(
        "hello(name: str) -> str",
        docstring: "Returns a greeting for the given name."
    ) { argc, argv in
        PyBind.function(argc, argv) { (name: String) in
            "Hello, \(name)!"
        }
    }
}
```

The function is then available on the module:
```python
import greetings

print(greetings.hello("SwiftPy"))   # Hello, SwiftPy!
```

Functions can be asynchronous too — return an awaitable from an `async` closure and Python can `await` it.

## Topics

### Related

- ``Scriptable(_:base:convertsToSnakeCase:)``
- ``PythonBindable``
- ``PyBind``
- <doc:WorkingWithPyObjects>
