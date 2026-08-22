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

    @Test("composes the output into a single print")
    func printsOnce() throws {
        Interpreter.run("""
        import math
        import builtins as _b
        _once_cap = []
        _once_orig = _b.print
        def _once_cp(msg=''):
            _once_cap.append(str(msg))
        _b.print = _once_cp
        help(math)
        help(int)
        _b.print = _once_orig
        _once_calls = len(_once_cap)
        """)

        #expect(Interpreter.evaluate("_once_calls") == 2)
    }

    @Test("module is importable")
    func moduleIsImportable() {
        Interpreter.run("""
        import builtins as _b
        import help as _help_module
        _help_module_is_registered = callable(_b.help) and callable(_help_module.help)
        """)

        #expect(Interpreter.evaluate("_help_module_is_registered") == true)
    }

    @Suite("no args") @MainActor
    struct NoArgs {
        init() {
            Interpreter.run("import interpreter")
            Interpreter.run("import help as _help; _help._help_text = None")
        }

        @Test("returns None")
        func returnsNone() {
            Interpreter.run("_help_none_r = help()")
            #expect(Interpreter.evaluate("_help_none_r is None") == true)
        }

        @Test("prints welcome text")
        func printsWelcomeText() throws {
            Interpreter.run("""
            import builtins as _b
            import help as _help
            _help._help_text = None
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
            #expect(output.contains("SwiftPy Python help"))
            #expect(output.contains("Useful functions"))
            #expect(output.contains("help('modules')   List available modules"))
            #expect(output.contains("help('<module>')  Show help for a module"))
            #expect(!output.contains("Welcome to PyPrompt"))
        }

        @Test("prints configured welcome text")
        func printsConfiguredWelcomeText() throws {
            Interpreter.run("""
            import builtins as _b
            import help as _help
            _help._help_text = 'Custom app help'
            _ca_cap = []
            _ca_orig = _b.print
            def _ca_cp(msg=''):
                _ca_cap.append(str(msg))
            _b.print = _ca_cp
            help()
            _help._help_text = None
            _b.print = _ca_orig
            _ca_out = "\\n".join(_ca_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_ca_out"))
            #expect(output == "Custom app help")
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
                '''Synthetic function docs.'''
                pass
            _b.print = _fn_cp
            help(_my_fn)
            _b.print = _fn_orig
            _fn_out = "\\n".join(_fn_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_fn_out"))
            #expect(output.contains("def _my_fn(x):"))
            #expect(output.contains("    \"\"\"Synthetic function docs.\"\"\""))
        }

        @Test("prints Swift-bound function signature")
        func printsSwiftBoundFunctionSignature() throws {
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
            #expect(output.contains("def sleep(seconds: float) -> None:"))
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

        // The interpreter drops class docstrings, so documentation has to be
        // assigned to __doc__ to be visible here.
        @Test("prints class documentation")
        func printsClassDocumentation() throws {
            Interpreter.run("""
            import builtins as _b
            _doc_cap = []
            _doc_orig = _b.print
            def _doc_cp(msg=''):
                _doc_cap.append(str(msg))
            class _Documented:
                __doc__ = 'A documented class.'
            _b.print = _doc_cp
            help(_Documented)
            _b.print = _doc_orig
            _doc_out = "\\n".join(_doc_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_doc_out"))
            #expect(output == """
            class _Documented:
                \"\"\"A documented class.\"\"\"
            """)
        }

        @Test("uses class interface when available")
        func usesClassInterfaceWhenAvailable() throws {
            Interpreter.run("""
            import builtins as _b
            _sb_cap = []
            _sb_orig = _b.print
            def _sb_cp(msg=''):
                _sb_cap.append(str(msg))
            class _BoundClass:
                _interface = 'class BoundClass(value: int):'
                def method(self): pass
            _b.print = _sb_cp
            help(_BoundClass)
            _b.print = _sb_orig
            _sb_out = "\\n".join(_sb_cap)
            """)

            let output: String = try #require(Interpreter.evaluate("_sb_out"))
            #expect(output == "class BoundClass(value: int):")
            #expect(!output.contains("method"))
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
            #expect(output.contains("def help(obj=None):"))
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
            #expect(output.contains("## Functions"))
            #expect(output.contains("def host(name: str) -> None:"))
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
            #expect(output.contains("def sleep(seconds: float) -> None:"))
        }
    }

    @Suite("string topic") @MainActor
    struct StringTopic {
        init() { Interpreter.run("import interpreter") }

        @Test("imports module by name")
        func importsByName() {
            Interpreter.run("help('math')")
        }

        @Test("resolves a member inside a module")
        func resolvesModuleMember() throws {
            Interpreter.run("""
            import builtins as _b
            import help as _help_module
            _member_cap = []
            _member_orig = _b.print
            def _member_cp(msg=''):
                _member_cap.append(str(msg))
            _b.print = _member_cp
            help('math.sqrt')
            _b.print = _member_orig
            _member_out = "\\n".join(_member_cap)
            _member_markdown = "\\n".join(_help_module._markdown_lines('math.sqrt'))
            """)

            let output: String = try #require(Interpreter.evaluate("_member_out"))
            let markdown: String = try #require(Interpreter.evaluate("_member_markdown"))
            #expect(output.contains("sqrt"))
            #expect(markdown.contains("sqrt"))
            #expect(!output.contains("No help found"))
            #expect(!markdown.contains("No help found"))
        }

        @Test("lists registered modules")
        func listsRegisteredModules() throws {
            PyBind.module("testing.helper") { _ in }

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
            #expect(output.contains("  asyncio"))
            #expect(output.contains("  interpreter"))
            #expect(output.contains("  keyring"))
            #expect(output.contains("  modeling"))
            #expect(output.contains("  p2p"))
            #expect(output.contains("  pathlib"))
            #expect(!output.contains("interpreter.native"))
            #expect(!output.contains("testing.helper"))
            #expect(!output.contains("help"))
            #expect(!output.contains("rlcompleter"))
        }

        @Test("handles unknown module gracefully")
        func handlesUnknown() {
            Interpreter.run("help('_no_such_module_xyz')")
        }
    }
}
