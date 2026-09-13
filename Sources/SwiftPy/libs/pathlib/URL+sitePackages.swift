//
//  URL+sitePackages.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

import Foundation

extension URL {
    /// Application Support/site-packages, created on first use. Kept out of
    /// Documents so installed packages stay hidden from the Files app.
    static func sitePackages() throws -> URL {
        let url = URL.applicationSupportDirectory
            .appending(path: "site-packages", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
