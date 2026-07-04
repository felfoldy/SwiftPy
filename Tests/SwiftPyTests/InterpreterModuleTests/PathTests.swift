//
//  PathTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-04.
//

import Testing
@testable import SwiftPy
import Foundation

struct PathTests {
    private func path(_ string: String) -> Path {
        Path(url: URL(filePath: string))
    }

    @Test func name() {
        #expect(path("/foo/bar/file.txt").name == "file.txt")
    }

    @Test func stem() {
        #expect(path("/foo/bar/file.txt").stem == "file")
    }

    @Test func suffix() {
        #expect(path("/foo/bar/file.txt").suffix == ".txt")
        #expect(path("/foo/bar/file").suffix == "")
    }

    @Test func suffixes() {
        #expect(path("/file.tar.gz").suffixes == [".tar", ".gz"])
        #expect(path("/file.txt").suffixes == [".txt"])
        #expect(path("/.hidden").suffixes == [])
        #expect(path("/file").suffixes == [])
    }

    @Test func parent() {
        #expect(path("/foo/bar/file.txt").parent.name == "bar")
    }

    @Test func parts() {
        #expect(path("/foo/bar/file.txt").parts == ["/", "foo", "bar", "file.txt"])
    }

    @Test func isAbsolute() {
        #expect(path("/foo/bar").isAbsolute() == true)
    }

    @Test func withName() {
        #expect(path("/foo/bar/file.txt").withName("other.py").name == "other.py")
    }

    @Test func withStem() {
        #expect(path("/foo/bar/file.txt").withStem("other").name == "other.txt")
    }

    @Test func withSuffix() {
        #expect(path("/foo/bar/file.txt").withSuffix(".py").suffix == ".py")
        #expect(path("/foo/bar/file.txt").withSuffix("").suffix == "")
    }

    @Test func readWriteText() throws {
        let file = Path(url: FileManager.default.temporaryDirectory
            .appending(path: "swiftpy_rw_test.txt"))
        defer { try? file.unlink() }

        try file.writeText("hello")
        #expect(file.isFile())
        #expect(!file.isDir())
        #expect(try file.readText() == "hello")
    }

    @Test func touch() throws {
        let file = Path(url: FileManager.default.temporaryDirectory
            .appending(path: "swiftpy_touch_test.txt"))
        defer { try? file.unlink() }

        try file.touch()
        #expect(file.isFile())
    }

    @Test func mkdirAndRmdir() throws {
        let dir = Path(url: FileManager.default.temporaryDirectory
            .appending(path: "swiftpy_mkdir_test", directoryHint: .isDirectory))
        if dir.exists() { try dir.unlink() }
        defer { try? dir.unlink() }

        try dir.mkdir()
        #expect(dir.isDir())
        #expect(!dir.isFile())
        try dir.rmdir()
        #expect(!dir.exists())
    }

    @Test func iterdir() throws {
        let dirUrl = FileManager.default.temporaryDirectory
            .appending(path: "swiftpy_iterdir_test", directoryHint: .isDirectory)
        let dir = Path(url: dirUrl)
        if dir.exists() { try dir.unlink() }
        defer { try? dir.unlink() }

        try dir.mkdir()
        try Path(url: dirUrl.appending(path: "test.txt")).writeText("content")

        let contents = try dir.iterdir()
        #expect(contents.count == 1)
        #expect(contents[0].name == "test.txt")
    }

    @Test func glob() throws {
        let dirUrl = FileManager.default.temporaryDirectory
            .appending(path: "swiftpy_glob_test", directoryHint: .isDirectory)
        let dir = Path(url: dirUrl)
        if dir.exists() { try dir.unlink() }
        defer { try? dir.unlink() }

        try dir.mkdir()
        for name in ["a.txt", "b.txt", "c.py"] {
            try Path(url: dirUrl.appending(path: name)).writeText("")
        }

        let txtFiles = try dir.glob("*.txt")
        #expect(txtFiles.count == 2)
    }
}
