# SwiftPy

![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue.svg)

SwiftPy is a fast and lightweight Python interpreter built on [pocketpy](https://github.com/pocketpy/pocketpy) with Swift macro binding tools.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/felfoldy/SwiftPy.git", from: "0.7.0")
]
```

## Usage

### @Scriptable

Annotate your Swift classes with the `@Scriptable` macro to automatically generate a corresponding Python interface. For example:

```swift
@Scriptable
@Observable class LoginViewModel {
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
