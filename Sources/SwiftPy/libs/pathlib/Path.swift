//
//  Path.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-26.
//

import Foundation

@Scriptable
public final class Path {
    public var url: URL

    internal init(url: URL?) throws {
        guard let url else {
            throw PythonError.ValueError("Path not found")
        }
        self.url = url
    }
    
    public convenience init(path: String) throws {
        let url = URL(filePath: path, relativeTo: .currentDirectory())
        try self.init(url: url)
    }

    /// Create a new directory at this given path.
    public func mkdir() throws {
        try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true)
    }

    /// Removes the file or directory at the specified Path.
    public func unlink() throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Documents directory.
    public static func home() throws -> Path {
        try Path(url: .documentsDirectory)
    }

    /// The path to the program’s current directory.
    public static func cwd() throws -> Path {
        try Path(url: .currentDirectory())
    }
    
    /// Documents/site-packges directory.
    public static func sitePackages() throws -> Path {
        let sitePackagesUrl = try home().url.appending(path: "site-packages", directoryHint: .isDirectory)
        let path = try Path(url: sitePackagesUrl)

        // Create site-packages folder if not exists.
        if !FileManager.default.fileExists(atPath: sitePackagesUrl.path) {
            try FileManager.default.createDirectory(
                at: sitePackagesUrl,
                withIntermediateDirectories: true
            )
        }

        return path
    }
    
    /// Returns a Boolean value that indicates whether a file or directory exists at a specified path.
    public static func exists(path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func __truediv__(_ other: String) throws -> Path {
        try Path(url: url.appending(path: other))
    }
}

extension Path: CustomStringConvertible {
    public var description: String {
        url.path
    }
}
