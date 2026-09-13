//
//  PathlibCPythonTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-09-13.
//

#if cpython
import Testing
@testable import SwiftPy

// The stdlib pathlib with the app's locations, and Path bridging both ways.
@MainActor
struct PathlibCPythonTests {
    @Test func stdlibPathWithExtras() throws {
        try Interpreter.execute(try Interpreter.compile("""
        import pathlib
        from pathlib import Path
        assert isinstance(Path.home(), pathlib.PurePath)
        assert Path.home().name == 'Documents'
        assert Path.tmp().is_dir() and Path.site_packages().is_dir()
        assert 'Documents' in Path.home.__doc__
        f = Path.tmp() / 'swiftpy_pathlib_test.txt'
        f.write_text('hi'); ok = f.read_text() == 'hi'; f.unlink()
        assert ok
        """))
    }

    @Test func bindingsTakePathOrStr() throws {
        let module = py.newmodule("pathlib_test")!
        module.def("name(p: Path) -> str") { argc, argv in
            PyBind.function(argc, argv) { (p: Path) in p.name }
        }
        module.def("text(s: str) -> str") { argc, argv in
            PyBind.function(argc, argv) { (s: String) in s }
        }
        try Interpreter.execute(try Interpreter.compile("""
        import pathlib_test
        from pathlib import Path
        assert pathlib_test.name(Path('/q/w.txt')) == 'w.txt'
        assert pathlib_test.name('/q/e.txt') == 'e.txt'
        assert pathlib_test.text(Path('/q/w.txt')) == '/q/w.txt'
        """))
    }
}
#endif
