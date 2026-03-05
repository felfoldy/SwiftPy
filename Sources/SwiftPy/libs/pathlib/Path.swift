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

    /// Documents directory.
    public static func home() -> String {
        URL.documentsDirectory.path
    }
    
    /// The path to the program’s current directory.
    public static func cwd() throws -> Path {
        try Path(url: .currentDirectory())
    }
    
    /// Documents/site-packges directory.
    public static func sitePackages() throws -> String {
        let path = home() + "/site-packages"
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
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
