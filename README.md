# SwiftPy

![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue.svg)

## Usage

### Register a function
```swift
// Create a function.
let function = #def("custom_func") {
   print("Swift code called from Python")
}

// Set the function to the __main__ module
Interpreter.main.set(function)

// Run a script.
Interpreter.execute("custom_func()")
```

#### Output
```
Swift code called from Python
```

### Register a function with a function signature
```swift
let function = #def("random() -> int") {
    Int.random(in: 0..<10)
}
```
