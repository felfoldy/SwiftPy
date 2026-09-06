//
//  Path.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-26.
//

import Foundation

/// A filesystem path that provides Python-style path inspection and file operations.
@Scriptable
public final class Path {
    public var url: URL

    internal init(url: URL) {
        self.url = url
    }
    
    internal init(url: URL?) throws {
        guard let url else {
            throw PythonError.ValueError("Path not found")
        }
        self.url = url
    }

    public convenience init(_ path: String) {
        let url = URL(filePath: path, relativeTo: .currentDirectory())
        self.init(url: url)
    }

    /// The final component of the path.
    public var name: String {
        url.lastPathComponent
    }

    /// The final component of the path, without its suffix.
    public var stem: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// The file extension of the final component, including the leading dot.
    public var suffix: String {
        let ext = url.pathExtension
        return ext.isEmpty ? "" : "." + ext
    }

    /// All suffixes of the final component.
    public var suffixes: [String] {
        let n = url.lastPathComponent
        let base = n.hasPrefix(".") ? String(n.dropFirst()) : n
        let dotParts = base.split(separator: ".", omittingEmptySubsequences: false)
        guard dotParts.count > 1 else { return [] }
        return dotParts.dropFirst().map { "." + $0 }
    }

    /// The logical parent of this path.
    public var parent: Path {
        Path(url: url.deletingLastPathComponent())
    }

    /// The path's components as a list.
    public var parts: [String] {
        let pathStr = url.path
        let components = pathStr.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        return pathStr.hasPrefix("/") ? ["/"] + components : components
    }

    /// Returns true if the path points to a regular file.
    public func isFile() -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }

    /// Returns true if the path points to a directory.
    public func isDir() -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    /// Returns true if the path points to a symbolic link.
    public func isSymlink() -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    /// Returns true if the path is absolute.
    public func isAbsolute() -> Bool {
        url.path.hasPrefix("/")
    }

    /// Returns a Boolean value that indicates whether a file or directory exists at a specified path.
    public func exists() -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Read file contents decoded as a string.
    public func readText() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Write a string to the file.
    public func writeText(_ data: String) throws {
        try data.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Create the file if it doesn't exist, or update its modification time.
    public func touch() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } else {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }

    /// Create a new directory at this given path.
    public func mkdir() throws {
        try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true)
    }

    /// Removes the file or directory at the specified Path.
    public func unlink() throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Remove this directory. The directory must be empty.
    public func rmdir() throws {
        let contents = try FileManager.default.contentsOfDirectory(atPath: url.path)
        guard contents.isEmpty else {
            throw PythonError.ValueError("Directory not empty: '\(url.path)'")
        }
        try FileManager.default.removeItem(at: url)
    }

    /// Return a list of Path objects of the directory contents.
    public func iterdir() throws -> [Path] {
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return contents.map { Path(url: $0) }
    }

    /// Glob the given pattern in the directory; supports `*`, `?`, and `**` (recursive).
    public func glob(_ pattern: String) throws -> [Path] {
        var results: [Path] = []
        if pattern.contains("**") {
            let subPattern = pattern.replacingOccurrences(of: "**/", with: "")
            let predicate = NSPredicate(format: "SELF LIKE %@", subPattern)
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
            while let fileUrl = enumerator?.nextObject() as? URL {
                if predicate.evaluate(with: fileUrl.lastPathComponent) {
                    results.append(Path(url: fileUrl))
                }
            }
        } else {
            let predicate = NSPredicate(format: "SELF LIKE %@", pattern)
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for fileUrl in contents where predicate.evaluate(with: fileUrl.lastPathComponent) {
                results.append(Path(url: fileUrl))
            }
        }
        return results
    }

    /// Return a new path with the file name changed.
    public func withName(_ name: String) -> Path {
        Path(url: url.deletingLastPathComponent().appending(path: name))
    }

    /// Return a new path with the stem changed.
    public func withStem(_ stem: String) -> Path {
        let ext = url.pathExtension
        return withName(ext.isEmpty ? stem : stem + "." + ext)
    }

    /// Return a new path with the suffix changed. Pass an empty string to remove the suffix.
    public func withSuffix(_ suffix: String) -> Path {
        let base = url.deletingPathExtension()
        if suffix.isEmpty {
            return Path(url: base)
        }
        let ext = suffix.hasPrefix(".") ? String(suffix.dropFirst()) : suffix
        return Path(url: base.appendingPathExtension(ext))
    }

    /// Make the path absolute, resolving any symlinks.
    public func resolve() -> Path {
        Path(url: url.standardizedFileURL.resolvingSymlinksInPath())
    }

    /// Documents directory.
    public static func home() -> Path {
        Path(url: .documentsDirectory)
    }

    /// The path to the program's current directory.
    public static func cwd() -> Path {
        Path(url: .currentDirectory())
    }

    /// The host bundle's resource directory.
    public static func resources() throws -> Path {
        try Path(url: Bundle.main.resourceURL)
    }

    /// The app's temporary directory. Safe to write scratch files to, but the
    /// system may purge its contents at any time.
    public static func tmp() -> Path {
        Path(url: FileManager.default.temporaryDirectory)
    }

    /// Application Support/site-packages directory. Kept out of Documents so
    /// installed packages stay hidden from the Files app.
    public static func sitePackages() throws -> Path {
        let sitePackagesUrl = URL.applicationSupportDirectory
            .appending(path: "site-packages", directoryHint: .isDirectory)
        let path = Path(url: sitePackagesUrl)

        if !FileManager.default.fileExists(atPath: sitePackagesUrl.path) {
            try FileManager.default.createDirectory(
                at: sitePackagesUrl,
                withIntermediateDirectories: true
            )
        }

        return path
    }

    func __truediv__(_ other: String) -> Path {
        Path(url: url.appending(path: other))
    }
}

extension Path: CustomStringConvertible {
    public var description: String {
        url.path
    }
}
