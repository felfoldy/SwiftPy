#if cpython
import Foundation
import Testing
@testable import SwiftPy

@MainActor
@Suite(.serialized)
struct ModuleDiscoveryTests {
    @Test func listsBundledNativeAndUnimportedModulesWithoutExecutingThem() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "\"\"\"A discoverable user module.\"\"\"\nraise RuntimeError('must not execute while listing')".write(to: directory.appending(path: "discovery_probe.py"), atomically: true, encoding: .utf8)
        let package = directory.appending(path: "discovery_package")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try "\"\"\"A discoverable package.\"\"\"".write(to: package.appending(path: "__init__.py"), atomically: true, encoding: .utf8)
        _ = try Interpreter.compile("pass")
        py.main._discovery_path = directory.path
        defer { await Interpreter.run("sys.path.remove(_discovery_path)", mode: .execution) }
        try await Interpreter.execute(Interpreter.compile("""
        import sys
        from interpreter.help import _available_modules, _modules_markdown
        before = _available_modules()
        for name in ['random', 'math', 'datetime', 'json', 'sys', 'os', 'asyncio', 'storage', 'rlcompleter']:
            assert name in before, name
        assert not any([name.startswith('_') for name in before])
        assert before == sorted(set(before))
        import os
        old_directory = os.getcwd()
        try:
            os.chdir(_discovery_path)
            assert 'discovery_probe' in _available_modules()
        finally:
            os.chdir(old_directory)
        sys.path.insert(0, _discovery_path)
        after = _available_modules()
        assert 'discovery_probe' in after
        assert 'discovery_package' in after
        text = '\\n'.join(_modules_markdown())
        assert 'A discoverable user module.' in text
        assert 'A discoverable package.' in text
        assert 'discovery_probe' not in sys.modules
        assert 'discovery_package' not in sys.modules
        """))
    }
}
#endif
