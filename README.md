# SwiftPy

![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue.svg)

## Usage

```swift
// Create a function.
let function = #def("add(a: int, b: int) -> int") { args in
    let a: Int = args[0]!
    let b: Int = args[1]!
    return a + b
}

// Set the function to the __main__ module
Interpreter.main.bind(function)

// Run a script.
Interpreter.execute("x = add(10, 3)")
```
