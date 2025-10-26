//
//  Path.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2025-10-26.
//

import Foundation

@Scriptable
final class Path {
    /// Documents directory.
    static func home() -> String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
    }
    
    /// Documents/site-packges directory.
    static func sitePackages() throws -> String {
        let path = home() + "/site-packages"
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        return path
    }
    
    /// Returns a Boolean value that indicates whether a file or directory exists at a specified path.
    static func exists(path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
