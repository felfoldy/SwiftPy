# Getting Started

Welcome to ``SwiftPy``, a fast and lightweight Python interpreter powered by pocketpy and enhanced with Swift macro binding tools.

## Installation

@TabNavigator {
    @Tab("Add to Xcode Project") {
        1. Navigate to File > Add Package Dependencies…
        2. Enter the repository URL: `https://github.com/felfoldy/SwiftPy.git`
        3. Click `Add package`
    }

    @Tab("Add to Package.swift") {
        1. In your Package.swift manifest, add SwiftPy as dependency:
        ```swift
        dependencies: [
            .package(url: "https://github.com/felfoldy/SwiftPy.git", from: "0.11.0"),
        ],
        ```
        2. Add it to the dependencies array of your target:
        ```swift
        .target(
          name: "MyTargetName",
          dependencies: ["SwiftPy"]
        ),
        ```
    }
}

After that you can import the library:
```swift
import SwiftPy
```

## Run a script

The simplest way to run a script is with the ``Interpreter/run(_:)`` function:
```swift
Interpreter.run("print('Hello from Python')")
```
The Python virtual machine will be initialized at the first usage.
