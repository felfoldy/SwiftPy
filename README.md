# SwiftPy

![Swift Version](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue.svg)
[![Release](https://img.shields.io/github/v/tag/felfoldy/SwiftPy?sort=semver&label=release&color=blue)](https://github.com/felfoldy/SwiftPy/releases)
[![License](https://img.shields.io/github/license/felfoldy/SwiftPy)](LICENSE)
[![Tests](https://github.com/felfoldy/SwiftPy/actions/workflows/tests.yml/badge.svg)](https://github.com/felfoldy/SwiftPy/actions/workflows/tests.yml)
[![Coverage](https://codecov.io/gh/felfoldy/SwiftPy/graph/badge.svg)](https://codecov.io/gh/felfoldy/SwiftPy)
[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://felfoldy.github.io/SwiftPy/documentation/swiftpy/)
[![Docs Build](https://github.com/felfoldy/SwiftPy/actions/workflows/docs.yml/badge.svg)](https://github.com/felfoldy/SwiftPy/actions/workflows/docs.yml)

SwiftPy is a fast and lightweight Python interpreter built on [pocketpy](https://github.com/pocketpy/pocketpy) with Swift macro binding tools.

## Documentation

* [API Documentation](https://felfoldy.github.io/SwiftPy/documentation/swiftpy/)

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/felfoldy/SwiftPy.git", from: "0.24.0")
]
```

## Usage

### @Scriptable

Annotate your Swift classes with the `@Scriptable` macro to automatically generate a corresponding Python interface:

```swift
@Scriptable
final class Player {
    var name: String
    var score: Int

    init(name: String, score: Int = 0) {
        self.name = name
        self.score = score
    }

    func addScore(points: Int) {
        score += points
    }
}
```

This generates the following Python interface:
```py
class Player:
    name: str
    score: int

    def __init__(self, name: str, score: int = 0) -> None:
        ...

    def add_score(self, points: int) -> None:
        ...
```

Method and property names are converted to `snake_case`.

### Creating a module

Register the type in a module so Python scripts can import it. Do this once at startup:

```swift
PyBind.module("game") { game in
    game.class(Player.self)
}
```

### Running a script

With the module registered, run Python that imports and uses your Swift type:

```swift
Interpreter.run("""
from game import Player

player = Player("Ada", score=10)
player.add_score(5)
print(f"{player.name}: {player.score}")  # Ada: 15
""")
```

Read Python state back into Swift through the interoperability API.
Reading the `player` the script above created:

```swift
let score: Int? = py.main.player?.score  // 15
```
