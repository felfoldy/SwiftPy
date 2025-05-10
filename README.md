# SwiftPy

![Swift Version](https://img.shields.io/badge/Swift-6.1-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue.svg)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://felfoldy.github.io/SwiftPy/documentation/swiftpy/)

SwiftPy is a fast and lightweight Python interpreter built on [pocketpy](https://github.com/pocketpy/pocketpy) with Swift macro binding tools.

## Documentation

* [API Documentation](https://felfoldy.github.io/SwiftPy/documentation/swiftpy/)

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/felfoldy/SwiftPy.git", from: "0.11.0")
]
```

## Usage

### @Scriptable

Annotate your Swift classes with the `@Scriptable` macro to automatically generate a corresponding Python interface. For example:

```swift
@Scriptable
@Observable
class LoginViewModel {
    var username: String = ""
    var password: String = ""
    
    func login() {
        ...
    }
}
```

This will generate an equivalent type for Python:
```py
class LoginViewModel:
    username: str
    password: str
    
    def login(self) -> None:
        ...
```

#### Integrating with SwiftUI

Inject the view model into Python using the `interactable` modifier:
```swift
struct LoginView {
    @State private var viewModel = LoginViewModel()
    
    var body: some View {
        viewImplementation
            .interactable("viewmodel", viewModel)
    }
}
```

After injection, Python scripts can interact with the Swift view model:
```py
viewmodel = viewcontext.viewmodel
viewmodel.username = "username"
viewmodel.password = "password"
viewmodel.login()
```
