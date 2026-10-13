//
//  Clipboard.swift
//  SwiftPy
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
protocol ClipboardStorage: AnyObject {
    var string: String? { get set }
}

@MainActor
enum Clipboard {
    // Replaced in tests, which mustn't touch the user's clipboard.
    static var storage: ClipboardStorage = SystemClipboard()
}

@MainActor
final class SystemClipboard: ClipboardStorage {
    var string: String? {
        get {
            #if canImport(UIKit)
            UIPasteboard.general.string
            #elseif canImport(AppKit)
            NSPasteboard.general.string(forType: .string)
            #else
            nil
            #endif
        }
        set {
            #if canImport(UIKit)
            UIPasteboard.general.string = newValue
            #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            if let newValue { NSPasteboard.general.setString(newValue, forType: .string) }
            #endif
        }
    }
}

extension Interpreter {
    func bindClipboard() {
        bindModule("clipboard", docs: """
        The system clipboard: copy text for other apps, or read what was copied.

        ```python
        import clipboard

        clipboard.copy("#1A334C")
        print(clipboard.paste())  # #1A334C
        ```
        """) { module in
            module.def(
                "copy(text: str) -> None",
                docstring: """
                Puts text on the clipboard, replacing what was there.

                text: The text to copy.
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (text: String) in
                    Clipboard.storage.string = text
                }
            }

            module.def(
                "paste() -> str | None",
                docstring: """
                The text on the clipboard, or None when it holds none. On iOS, \
                the system may ask the user to allow it.
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { () -> String? in
                    Clipboard.storage.string
                }
            }
        }
    }
}
