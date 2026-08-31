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

    @Test("renders host-provided markdown documents as reference topics")
    func hostMarkdownDocuments() throws {
        Interpreter.run("""
        import help as _help_module
        _help_module._documents = {
            'README': '# Welcome',
            'CHANGELOG': '## 1.2.0\\n\\n- Added a feature.',
        }
        _document_out = "\\n".join(_help_module._markdown_lines('CHANGELOG'))
        _readme_out = "\\n".join(_help_module._markdown_lines(None))
        _document_is_reference = _help_module._is_reference('CHANGELOG')
        _readme_is_reference = _help_module._is_reference('README')
        _help_module._documents = {}
        """)

        let output: String = try #require(Interpreter.evaluate("_document_out"))
        #expect(output == "## 1.2.0\n\n- Added a feature.")
        #expect(Interpreter.evaluate("_readme_out") == "# Welcome")
        #expect(Interpreter.evaluate("_document_is_reference") == true)
        #expect(Interpreter.evaluate("_readme_is_reference") == true)
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
            #expect(output.contains("Pass a name to `help`"))
            // The listing is reached as a reference rather than as a call.
            #expect(output.contains("See also ``modules``"))
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

    /// A class's own page reads as a module's does: what it is, then what it
    /// offers. Properties are left out for now.
    @Suite("class markdown") @MainActor
    struct ClassMarkdown {
        init() {
            Interpreter.run("import interpreter")
            Interpreter.run("import help as _help_module")
        }

        private func markdown(of path: String) throws -> String {
            Interpreter.run("""
            import \(path.split(separator: ".")[0])
            _cm_out = "\\n".join(_help_module._markdown_lines('\(path)'))
            """)
            return try #require(Interpreter.evaluate("_cm_out"))
        }

        @Test("opens with the name, its module, the declaration, and the summary")
        func opening() throws {
            let output = try markdown(of: "p2p.Peer")

            #expect(output.hasPrefix("""
            # Peer

            ``p2p``

            ```python
            class Peer
            ```

            An object represents a peer in a multipeer session.
            """))
        }

        /// The macro binds each method's comment, so the summary comes from the
        /// method rather than from the class's interface stub.
        @Test("lists the methods with their own summaries")
        func methods() throws {
            let output = try markdown(of: "p2p.Peer")

            #expect(output.contains("""
            ## Functions

            ### ``p2p.Peer/advertise``

            ```python
            def advertise(self) -> None
            ```

            Makes the peer discoverable.
            """))
        }

        @Test("marks static methods in their declarations")
        func staticMethods() throws {
            let output = try markdown(of: "pathlib.Path")

            #expect(output.contains("""
            ### ``pathlib.Path/cwd``

            ```python
            @staticmethod
            def cwd() -> Path
            ```
            """))
        }

        /// The macro binds the initializer's comment too, so it reads as a
        /// method does rather than being buried in the class stub.
        @Test("lists the initializer above the methods")
        func initializers() throws {
            let output = try markdown(of: "p2p.Peer")

            #expect(output.contains("""
            ## Initializers

            ### ``p2p.Peer/__init__``

            ```python
            def __init__(self, name: str) -> None
            ```

            Initializes a peer with a display name.
            """))

            let initializers = try #require(output.range(of: "## Initializers"))
            let functions = try #require(output.range(of: "## Functions"))
            #expect(initializers.lowerBound < functions.lowerBound)
        }

        /// A class that declares no initializer binds no `__init__`, so it gets
        /// no empty section.
        @Test("leaves the section out where nothing is initialized")
        func withoutInitializer() throws {
            Interpreter.run("""
            _no_init = "\\n".join(_help_module._markdown_lines(int))
            """)
            let output: String = try #require(Interpreter.evaluate("_no_init"))

            #expect(!output.contains("## Initializers"))
        }

        @Test("takes the method signature from the binding")
        func methodSignature() throws {
            let output = try markdown(of: "p2p.Peer")

            #expect(output.contains("def autoconnect(self, name: str) -> None"))
            // The trailing colon belongs to a source stub, not to a signature.
            #expect(!output.contains("-> None:"))
        }

        @Test("is not the plain stub it used to be")
        func isNotAStub() throws {
            let output = try markdown(of: "p2p.Peer")

            #expect(!output.hasPrefix("```python"))
            #expect(!output.contains("\"\"\""))
        }

        /// A property carries no signature, so its declaration stands in for
        /// one, and what documents it is its getter.
        @Test("lists the properties with what declares and describes them")
        func properties() throws {
            Interpreter.run("""
            class _Card:
                title: str

                @property
                def summary(self) -> str:
                    '''One line about the card.'''
                    return self.title

            _prop_out = "\\n".join(_help_module._markdown_lines(_Card))
            """)
            let output: String = try #require(Interpreter.evaluate("_prop_out"))

            #expect(output.contains("""
            ## Properties

            - `summary` (read only): One line about the card.
            - `title: str`
            """))
        }

        @Test("lists properties like function parameters")
        func propertyRows() throws {
            let output = try markdown(of: "pathlib.Path")

            #expect(output.contains("""
            ## Properties

            - `name` (read only): The final component of the path.
            """))
            #expect(!output.contains("### ``pathlib.Path/name``"))

            let properties = try #require(output.range(of: "## Properties"))
            let initializers = try #require(output.range(of: "## Initializers"))
            #expect(properties.lowerBound < initializers.lowerBound)
        }

        /// Reached by its path, a property documents itself rather than the
        /// `property` it is an instance of.
        @Test("documents a property of its own")
        func propertyPage() throws {
            let output = try markdown(of: "pathlib.Path.name")

            #expect(output == """
            # name

            ``pathlib``

            The final component of the path.

            ```python
            name  # read only
            ```
            """)
        }

        /// Nothing names the module when help is handed the class itself, so
        /// the methods keep their headings without references.
        @Test("documents a class reached without a path")
        func withoutPath() throws {
            Interpreter.run("""
            import p2p
            _np_out = "\\n".join(_help_module._markdown_lines(p2p.Peer))
            """)
            let output: String = try #require(Interpreter.evaluate("_np_out"))

            #expect(output.hasPrefix("# Peer"))
            #expect(output.contains("### advertise"))
            #expect(!output.contains("### ``"))
        }

        @Test("links methods of a built-in class handed to help")
        func builtInClassReferences() throws {
            Interpreter.run("""
            _builtin_out = "\\n".join(_help_module._markdown_lines(str))
            _builtin_member_out = "\\n".join(_help_module._markdown_lines('str.upper'))
            """)
            let output: String = try #require(Interpreter.evaluate("_builtin_out"))
            let memberOutput: String = try #require(Interpreter.evaluate("_builtin_member_out"))

            #expect(output.contains("### ``str/count``"))
            #expect(output.contains("### ``str/encode``"))
            #expect(memberOutput.hasPrefix("# upper"))
            #expect(memberOutput.contains("def upper(...)"))
            #expect(!memberOutput.contains("<nativefunc object>"))
        }
    }

    /// A module lists its classes the way it lists its functions: the name
    /// linked to its own help, over what it declares and what it is for.
    @Suite("module class listing") @MainActor
    struct ModuleClassListing {
        init() {
            Interpreter.run("import interpreter")
            Interpreter.run("import help as _help_module")
        }

        private func markdown(of module: String) throws -> String {
            Interpreter.run("""
            import \(module)
            _cl_out = "\\n".join(_help_module._markdown_lines('\(module)'))
            """)
            return try #require(Interpreter.evaluate("_cl_out"))
        }

        @Test("links a documented class over its declaration and summary")
        func documentedClass() throws {
            let output = try markdown(of: "p2p")

            #expect(output.contains("""
            ### ``p2p/Peer``

            ```python
            class Peer
            ```

            An object represents a peer in a multipeer session.
            """))
        }

        @Test("shows a class with no documentation as its declaration alone")
        func undocumentedClass() throws {
            let output = try markdown(of: "asyncio")

            #expect(output.contains("""
            ### ``asyncio/AsyncTask``

            ```python
            class AsyncTask
            ```
            """))
        }

        /// A class declared by an interface string has no `__doc__`, so the
        /// summary comes from the docstring inside the stub.
        @Test("summarises a class declared by an interface string")
        func interfaceDeclaredClass() throws {
            Interpreter.run("""
            class _Stubbed:
                _interface = 'class Response(Base):\\n    \\"\\"\\"Holds a reply.\\n\\n    More prose.\\n    \\"\\"\\"'
            _if_out = "\\n".join(_help_module._class_entries('probe', [('Response', _Stubbed)]))
            """)
            let output: String = try #require(Interpreter.evaluate("_if_out"))

            #expect(output.contains("""
            ```python
            class Response(Base)
            ```

            Holds a reply.
            """))
            // Only the summary, not the rest of the stub's docstring.
            #expect(!output.contains("More prose."))
        }

        @Test("uses __all__ as the documented public API in declared order")
        func explicitPublicAPI() throws {
            Interpreter.run("""
            class _DocumentedModule:
                __all__ = ['second', 'first']
                def first(self): pass
                def second(self): pass
                def hidden(self): pass
            _all_classes, _all_functions = _help_module._module_members(_DocumentedModule())
            _all_names = [name for name, _ in _all_functions]
            """)

            let names: [String] = try #require(Interpreter.evaluate("_all_names"))
            #expect(names == ["second", "first"])
        }

        @Test("no longer stacks the classes into one code block")
        func notOneCodeBlock() throws {
            let output = try markdown(of: "p2p")

            #expect(!output.contains("""
            ## Classes

            ```python
            """))
        }
    }

    /// The markdown a function's help renders as. The reference for the layout
    /// is `help('requests.get')`, checked against the real module in
    /// swiftpy-requests; these cover the parsing on its own.
    @Suite("function markdown") @MainActor
    struct FunctionMarkdown {
        init() { Interpreter.run("import interpreter") }

        private func markdown(of expression: String) throws -> String {
            Interpreter.run("""
            import help as _help_module
            _fm_out = "\\n".join(_help_module._markdown_lines(\(expression)))
            """)
            return try #require(Interpreter.evaluate("_fm_out"))
        }

        @Test("titles the function and shows its summary")
        func titleAndSummary() throws {
            Interpreter.run("""
            def _summarized(value):
                '''Does a thing.'''
                pass
            """)

            let output = try markdown(of: "_summarized")

            #expect(output.hasPrefix("""
            # _summarized

            Does a thing.
            """))
        }

        @Test("documents the model decorator")
        func modelDecorator() throws {
            let output = try markdown(of: "'modeling.model'")

            #expect(output.contains("Convert an annotated class into a data model."))
            #expect(output.contains("Annotated attributes become mutable model fields."))
            #expect(output.contains("""
            ```python
            from modeling import model

            @model
            class Item:
            """))
            #expect(output.contains("item = Item(\"Hammer\", quantity=2)"))
            #expect(output.contains("- `cls`: The annotated class to convert."))
        }

        @Test("shows a bound signature without its trailing colon")
        func boundSignature() throws {
            Interpreter.run("import asyncio")

            let output = try markdown(of: "asyncio.sleep")

            #expect(output.contains("""
            ```python
            async def sleep(seconds: float) -> None
            ```
            """))
            // The trailing colon belongs to a source stub, not to a signature.
            #expect(!output.contains("-> None:"))
        }

        /// Each overload documents its own signature, so the page repeats the
        /// sections rather than merging what belongs to one of them.
        @Test("documents each overload under its own signature")
        func overloadSections() throws {
            bindResponder()

            let output = try markdown(of: "Responder.respond")

            #expect(output == """
            # respond

            ```python
            @overload
            def respond(self, prompt: str) -> str
            ```

            Produces a response to a prompt.

            ## Parameters

            - `prompt`: What to respond to.

            # respond

            ```python
            @overload
            def respond(self, prompt: str, schema: Any) -> Any
            ```

            Produces a structured response to a prompt.

            ## Parameters

            - `prompt`: What to respond to.
            - `schema`: The type the response conforms to.
            """)
            // The dispatcher's own signature documents nothing.
            #expect(!output.contains("*args"))
        }

        /// A listing heads every overload with the same name, each over the
        /// signature it documents.
        @Test("lists an overload dispatcher as one entry per overload")
        func overloadEntries() throws {
            bindResponder()
            Interpreter.run("""
            _overload_entries = "\\n".join(
                _help_module._function_entries(
                    'agents.Agent', [('respond', Responder.respond)]
                )
            )
            """)
            let entries: String = try #require(Interpreter.evaluate("_overload_entries"))

            #expect(entries.contains("""
            ### ``agents.Agent/respond``

            ```python
            @overload
            def respond(self, prompt: str) -> str
            ```

            Produces a response to a prompt.

            ### ``agents.Agent/respond``

            ```python
            @overload
            def respond(self, prompt: str, schema: Any) -> Any
            ```
            """))
        }

        /// Python can no longer set attributes on a function, so an overload
        /// dispatcher has to come from a real binding.
        private func bindResponder() {
            PyBind.module("HelpOverloadTests") { module in
                module.class(Responder.self)
            }
            Interpreter.run("""
            import help as _help_module
            from HelpOverloadTests import Responder
            """)
        }

        @Test("lists the documented parameters and leaves the rest out")
        func parameters() throws {
            Interpreter.run("""
            def _fetch(url, params, timeout):
                '''Sends a request.

                params: Mapping appended to the URL's query.
                timeout: Seconds allowed to pass without receiving data.
                '''
                pass
            """)

            let output = try markdown(of: "_fetch")

            #expect(output.contains("""
            ## Parameters

            - `params`: Mapping appended to the URL's query.
            - `timeout`: Seconds allowed to pass without receiving data.
            """))
            #expect(!output.contains("- `url`"))
            #expect(!output.contains("## Discussion"))
        }

        @Test("keeps prose out of the parameters")
        func discussion() throws {
            Interpreter.run("""
            def _documented(value, other):
                '''Does a thing.

                Some discussion of the thing.
                It runs on for a second line.

                value: What to do it to.
                '''
                pass
            """)

            let output = try markdown(of: "_documented")

            #expect(output.contains("""
            ## Parameters

            - `value`: What to do it to.
            """))
            #expect(output.contains("""
            ## Discussion

            Some discussion of the thing.
            It runs on for a second line.
            """))
        }

        @Test("carries a wrapped parameter description onto one line")
        func wrappedParameterDescription() throws {
            Interpreter.run("""
            def _wrapped(count):
                '''Wraps.

                count: How many, described at
                    length over two lines.
                '''
                pass
            """)

            let output = try markdown(of: "_wrapped")

            #expect(output.contains("- `count`: How many, described at length over two lines."))
            #expect(!output.contains("## Discussion"))
        }

        @Test("a colon in prose isn't a parameter")
        func colonInProse() throws {
            Interpreter.run("""
            def _prose(value):
                '''Explains.

                Note: this is prose, not a parameter.
                '''
                pass
            """)

            let output = try markdown(of: "_prose")

            #expect(!output.contains("## Parameters"))
            #expect(output.contains("Note: this is prose, not a parameter."))
        }

        @Test("tells a module-rooted path from a name only the session owns")
        func isReference() throws {
            Interpreter.run("""
            import help as _help_module
            def _session_only(x):
                pass
            _ref_math = _help_module._is_reference('math.sqrt')
            _ref_missing = _help_module._is_reference('math.no_such_member')
            _ref_local = _help_module._is_reference('_session_only')
            _ref_topic = _help_module._is_reference('modules')
            """)

            #expect(Interpreter.evaluate("_ref_math") == true)
            // A host uses this to fall back to the object it is bound to.
            #expect(Interpreter.evaluate("_ref_missing") == false)
            #expect(Interpreter.evaluate("_ref_local") == false)
            // A topic resolves no name, but help documents it all the same.
            #expect(Interpreter.evaluate("_ref_topic") == true)
        }

        @Test("shows the signature where there is no docstring")
        func noDocstring() throws {
            Interpreter.run("""
            def _bare(x):
                pass
            """)

            let output = try markdown(of: "_bare")

            #expect(output.contains("# _bare"))
            #expect(output.contains("def _bare(x)"))
            #expect(!output.contains("## Parameters"))
            #expect(!output.contains("## Discussion"))
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

/// An overloaded method whose overloads document different parameters. Bound
/// rather than assembled in Python, which can't set `_overloads` on a function.
private class Responder: PythonBindable {
    var _pythonCache = PythonBindingCache()

    static let pyType = PyType.make("Responder", base: .object) { type in
        type.function(
            "respond(self, prompt: str) -> str",
            """
            Produces a response to a prompt.

            prompt: What to respond to.
            """
        ) { _, _ in true }

        type.function(
            "respond(self, prompt: str, schema: Any) -> Any",
            """
            Produces a structured response to a prompt.

            prompt: What to respond to.
            schema: The type the response conforms to.
            """
        ) { _, _ in true }
    }
}
