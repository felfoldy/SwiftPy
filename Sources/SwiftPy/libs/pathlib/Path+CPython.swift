//
//  Path+CPython.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

#if cpython
import Foundation

/// A `pathlib.Path` held from Swift, with the surface the pocketpy `Path` has
/// so bindings typed `Path` work on both backends.
@MainActor
public final class Path: PythonConvertible {
    public let object: PyObject

    private static let pathlib = py.module("pathlib")!
    private static let purePath = PyType(pathlib.PurePath!)!

    public init(object: PyObject) {
        self.object = object
    }

    public convenience init(_ path: String) {
        // pathlib.Path(str) only raises when given a non-str.
        self.init(object: try! Self.pathlib.throwing.Path(path).object)
    }

    convenience init(url: URL) {
        self.init(url.path(percentEncoded: false))
    }

    convenience init(url: URL?) throws {
        guard let url else {
            throw PythonError.ValueError("Path not found")
        }
        self.init(url: url)
    }

    public var url: URL {
        URL(filePath: description, relativeTo: .currentDirectory())
    }

    // Pure path attributes never raise, so a throw here is a bug.
    private func attribute<Value: PythonConvertible>(_ name: String) -> Value {
        try! object.throwing[dynamicMember: name]
    }

    @discardableResult
    private func call(_ name: String, _ args: (any PythonConvertible)?...) throws(PythonError) -> ThrowingPyObject {
        try object.throwing[dynamicMember: name].call(unpacking: args)
    }

    @_disfavoredOverload
    private func call<Result: PythonConvertible>(_ name: String, _ args: (any PythonConvertible)?...) throws(PythonError) -> Result {
        try object.throwing[dynamicMember: name].call(unpacking: args)
    }

    /// `list(self.<name>(...))`: pathlib hands back generators, not lists.
    private func paths(_ name: String, _ args: (any PythonConvertible)?...) throws(PythonError) -> [Path] {
        let items = try object.throwing[dynamicMember: name].call(unpacking: args)
        return try py.module("builtins")!.throwing.list(items.object)
    }

    public var name: String { attribute("name") }
    public var stem: String { attribute("stem") }
    public var suffix: String { attribute("suffix") }
    public var suffixes: [String] { attribute("suffixes") }
    public var parent: Path { attribute("parent") }
    // A tuple in Python, and only a list casts.
    public var parts: [String] { try! py.module("builtins")!.throwing.list(object.throwing.parts.object) }

    public func isFile() -> Bool { (try? call("is_file")) ?? false }
    public func isDir() -> Bool { (try? call("is_dir")) ?? false }
    public func isSymlink() -> Bool { (try? call("is_symlink")) ?? false }
    public func isAbsolute() -> Bool { (try? call("is_absolute")) ?? false }
    public func exists() -> Bool { (try? call("exists")) ?? false }

    public func readText() throws -> String { try call("read_text") }
    public func writeText(_ data: String) throws { try call("write_text", data) }
    public func touch() throws { try call("touch") }
    public func mkdir() throws { try call("mkdir", 0o777, true, true) }
    /// Removes a file, or a directory with everything in it.
    public func unlink() throws {
        if isDir() {
            try py.module("shutil")!.throwing.rmtree(object)
        } else {
            try call("unlink")
        }
    }
    public func rmdir() throws { try call("rmdir") }
    public func iterdir() throws -> [Path] { try paths("iterdir") }
    public func glob(_ pattern: String) throws -> [Path] { try paths("glob", pattern) }

    public func withName(_ name: String) -> Path { try! call("with_name", name) }
    public func withStem(_ stem: String) -> Path { try! call("with_stem", stem) }
    public func withSuffix(_ suffix: String) -> Path { try! call("with_suffix", suffix) }
    public func resolve() -> Path { (try? call("resolve")) ?? self }

    /// Documents directory.
    public static func home() -> Path {
        Path(url: .documentsDirectory)
    }

    public static func cwd() -> Path {
        Path(url: .currentDirectory())
    }

    /// The host bundle's resource directory.
    public static func resources() throws -> Path {
        try Path(url: Bundle.main.resourceURL)
    }

    /// The app's temporary directory.
    public static func tmp() -> Path {
        Path(url: FileManager.default.temporaryDirectory)
    }

    public static func sitePackages() throws -> Path {
        Path(url: try .sitePackages())
    }

    // MARK: PythonConvertible

    public static var pyType: PyType { purePath }

    public func toPython() throws(PythonError) -> PyObject { object }

    public static func fromPython(_ reference: PyRef) -> Path {
        if PyType.str.isInstance(reference) {
            return Path(String.fromPython(reference))
        }
        return Path(object: py.retain(reference))
    }

    /// A str is taken too, the way `os.fspath` takes either.
    public static func isConvertible(_ reference: PyRef) -> Bool {
        purePath.isInstance(reference) || PyType.str.isInstance(reference)
    }
}

extension Path: @MainActor CustomStringConvertible {
    public var description: String { try! call("__fspath__") }
}
#endif
