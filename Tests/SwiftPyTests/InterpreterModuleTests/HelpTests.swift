//
//  HelpTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-14.
//

import Testing
import SwiftPy

@Suite("help()") @MainActor
struct HelpTests {

    init() {
        Interpreter.run("import interpreter")
    }

    @Test("is registered as builtin")
    func isRegistered() {
        #expect(Interpreter.evaluate("help is None") == false)
        #expect(Interpreter.evaluate("callable(help)") == true)
    }

    @Test("module is importable")
    func moduleIsImportable() {
        Interpreter.run("""
        import builtins as _b
        import help as _help_module
        _help_module_is_registered = _help_module.help is _b.help
        """)

        #expect(Interpreter.evaluate("_help_module_is_registered") == true)
    }

    @Test("interpreter module exposes only public API")
    func interpreterModuleExposesOnlyPublicAPI() throws {
        Interpreter.run("""
        import interpreter as _interpreter
        _interpreter_public_names = []
        for name, value in _interpreter.__dict__.items():
            if not name.startswith('_'):
                _interpreter_public_names.append(name)
        _interpreter_has_binder = hasattr(_interpreter, '_bind_interfaces')
        _interpreter_has_old_binder = hasattr(_interpreter, 'bind_interfaces')
        """)

        let publicNames: [String] = try #require(Interpreter.evaluate("_interpreter_public_names"))
        #expect(publicNames == ["host"])
        #expect(Interpreter.evaluate("_interpreter_has_binder") == false)
        #expect(Interpreter.evaluate("_interpreter_has_old_binder") == false)
    }

    @Suite("no args") @MainActor
    struct NoArgs {
        init() { Interpreter.run("import interpreter") }

        @Test("returns None")
        func returnsNone() {
            Interpreter.run("_help_none_r = help()")
            #expect(Interpreter.evaluate("_help_none_r is None") == true)
        }

        @Test("prints welcome text")
        func printsWelcomeText() throws {
            Interpreter.run("""
            import builtins as _b
            _na_cap = []
            _na_orig = _b.print
            def _na_cp(msg=''):
                _na_cap.append(str(msg))
            _b.print = _na_cp
            help()
            _b.print = _na_orig
            _na_out = "\\n".join(_na_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_na_out"))
            #expect(output.contains("Welcome to PyPrompt"))
            #expect(output.contains("pocketpy"))
            #expect(output.contains("Help topics"))
            #expect(output.contains("help(module)"))
            #expect(output.contains("help(function)"))
            #expect(output.contains("help('module')"))
            #expect(output.contains("help('modules')"))
        }
    }

    @Suite("callable") @MainActor
    struct Callable {
        init() { Interpreter.run("import interpreter") }

        // pocketpy native builtins don't expose __name__, so we use a user-defined function
        @Test("prints function name")
        func printsFunctionName() throws {
            Interpreter.run("""
            import builtins as _b
            _fn_cap = []
            _fn_orig = _b.print
            def _fn_cp(msg=''):
                _fn_cap.append(str(msg))
            def _my_fn(x):
                pass
            _b.print = _fn_cp
            help(_my_fn)
            _b.print = _fn_orig
            _fn_out = "\\n".join(_fn_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_fn_out"))
            #expect(output.contains("_my_fn"))
        }

        @Test("prints Swift-bound function signature and docstring")
        func printsSwiftBoundFunctionSignatureAndDocstring() throws {
            Interpreter.run("""
            import asyncio
            import builtins as _b
            _sleep_cap = []
            _sleep_orig = _b.print
            def _sleep_cp(msg=''):
                _sleep_cap.append(str(msg))
            _b.print = _sleep_cp
            help(asyncio.sleep)
            _b.print = _sleep_orig
            _sleep_out = "\\n".join(_sleep_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_sleep_out"))
            #expect(output.contains("sleep(seconds: float) -> None"))
            #expect(output.contains("Coroutine that completes after a given time"))
        }
    }

    @Suite("class") @MainActor
    struct Class {
        init() { Interpreter.run("import interpreter") }

        @Test("prints class name")
        func printsClassName() throws {
            Interpreter.run("""
            import builtins as _b
            _tp_cap = []
            _tp_orig = _b.print
            def _tp_cp(msg=''):
                _tp_cap.append(str(msg))
            _b.print = _tp_cp
            help(int)
            _b.print = _tp_orig
            _tp_out = "\\n".join(_tp_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_tp_out"))
            #expect(output.contains("int"))
        }

        @Test("prints public methods")
        func printsMethods() throws {
            Interpreter.run("""
            import builtins as _b
            _cls_cap = []
            _cls_orig = _b.print
            def _cls_cp(msg=''):
                _cls_cap.append(str(msg))
            class _Animal:
                def speak(self): pass
                def move(self): pass
            _b.print = _cls_cp
            help(_Animal)
            _b.print = _cls_orig
            _cls_out = "\\n".join(_cls_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_cls_out"))
            #expect(output.contains("_Animal"))
            #expect(output.contains("speak"))
            #expect(output.contains("move"))
        }

        @Test("shows interface signatures for Swift-bound class")
        func showsSwiftBoundClassInterface() throws {
            Interpreter.run("""
            import asyncio
            import builtins as _b
            _sb_cap = []
            _sb_orig = _b.print
            def _sb_cp(msg=''):
                _sb_cap.append(str(msg))
            _b.print = _sb_cp
            help(asyncio.AsyncTask)
            _b.print = _sb_orig
            _sb_out = "\\n".join(_sb_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_sb_out"))
            #expect(output.contains("AsyncTask"))
            #expect(output.contains("cancel"))
        }
    }

    @Suite("instance") @MainActor
    struct Instance {
        init() { Interpreter.run("import interpreter") }

        @Test("routes to type help")
        func routesToTypeHelp() throws {
            Interpreter.run("""
            import builtins as _b
            _inst_cap = []
            _inst_orig = _b.print
            def _inst_cp(msg=''):
                _inst_cap.append(str(msg))
            _b.print = _inst_cp
            help(42)
            _b.print = _inst_orig
            _inst_out = "\\n".join(_inst_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_inst_out"))
            #expect(output.contains("int"))
        }
    }

    @Suite("module") @MainActor
    struct Module {
        init() { Interpreter.run("import interpreter") }

        @Test("prints module name")
        func printsModuleName() throws {
            Interpreter.run("""
            import math
            import builtins as _b
            _mod_cap = []
            _mod_orig = _b.print
            def _mod_cp(msg=''):
                _mod_cap.append(str(msg))
            _b.print = _mod_cp
            help(math)
            _b.print = _mod_orig
            _mod_out = "\\n".join(_mod_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_mod_out"))
            #expect(output.contains("math"))
        }

        @Test("shows Python module functions with signatures")
        func showsPythonModuleFunctionsWithSignatures() throws {
            Interpreter.run("""
            import builtins as _b
            import help as _help_module
            _pymod_cap = []
            _pymod_orig = _b.print
            def _pymod_cp(msg=''):
                _pymod_cap.append(str(msg))
            _b.print = _pymod_cp
            help(_help_module)
            _b.print = _pymod_orig
            _pymod_out = "\\n".join(_pymod_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_pymod_out"))
            #expect(output.contains("## Functions"))
            #expect(output.contains("help(obj=None)"))
        }

        @Test("shows documented module functions")
        func showsDocumentedModuleFunctions() throws {
            Interpreter.run("""
            import builtins as _b
            _interp_cap = []
            _interp_orig = _b.print
            def _interp_cp(msg=''):
                _interp_cap.append(str(msg))
            _b.print = _interp_cp
            help('interpreter')
            _b.print = _interp_orig
            _interp_out = "\\n".join(_interp_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_interp_out"))
            #expect(output.contains("Utilities for interacting with the PyPrompt interpreter."))
            #expect(output.contains("## Functions"))
            #expect(output.contains("host(name: str) -> None"))
            #expect(!output.contains("completions(text: str) -> list[str]"))
        }

        @Test("shows bound classes from Swift module")
        func showsSwiftModuleClasses() throws {
            Interpreter.run("""
            import asyncio
            import builtins as _b
            _smod_cap = []
            _smod_orig = _b.print
            def _smod_cp(msg=''):
                _smod_cap.append(str(msg))
            _b.print = _smod_cp
            help(asyncio)
            _b.print = _smod_orig
            _smod_out = "\\n".join(_smod_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_smod_out"))
            #expect(output.contains("asyncio"))
            #expect(output.contains("AsyncTask"))
            #expect(output.contains("sleep(seconds: float) -> None"))
            #expect(output.contains("Coroutine that completes after a given time"))
        }
    }

    @Suite("string topic") @MainActor
    struct StringTopic {
        init() { Interpreter.run("import interpreter") }

        @Test("imports module by name")
        func importsByName() {
            Interpreter.run("help('math')")
        }

        @Test("lists registered modules")
        func listsRegisteredModules() throws {
            Interpreter.run("""
            import builtins as _b
            _mods_cap = []
            _mods_orig = _b.print
            def _mods_cp(msg=''):
                _mods_cap.append(str(msg))
            _b.print = _mods_cp
            help('modules')
            _b.print = _mods_orig
            _mods_out = "\\n".join(_mods_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_mods_out"))
            #expect(output.contains("Registered modules"))
            #expect(output.contains("asyncio - Async task utilities."))
            #expect(output.contains("interpreter - Utilities for interacting with the PyPrompt interpreter."))
            #expect(output.contains("keyring - Secure password storage using the system keychain."))
            #expect(output.contains("modeling - Provides a model decorator for LLM structured output and ORM-style storage."))
            #expect(output.contains("p2p - Peer-to-peer discovery and messaging."))
            #expect(output.contains("pathlib - Object-oriented filesystem paths."))
            #expect(!output.contains("interpreter.native"))
            #expect(!output.contains("help"))
            #expect(!output.contains("rlcompleter"))
        }

        @Test("handles unknown module gracefully")
        func handlesUnknown() {
            Interpreter.run("help('_no_such_module_xyz')")
        }
    }
}
