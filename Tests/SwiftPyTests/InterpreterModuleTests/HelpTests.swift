//
//  HelpTests.swift
//  SwiftPy
//
//  Created by Tibor Felföldy on 2026-07-14.
//

import Testing
import SwiftPy

@Suite("help()", .serialized) @MainActor
struct HelpTests {

    init() async {
        await Interpreter.run("import interpreter")
    }

    @Test("is registered as builtin")
    func isRegistered() async {
        #expect(Interpreter.evaluate("help is None") == false)
        #expect(Interpreter.evaluate("callable(help)") == true)
    }

    @Test("composes the output into a single print")
    func printsOnce() async throws {
        await Interpreter.run("""
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
    func moduleIsImportable() async {
        await Interpreter.run("""
        import builtins as _b
        import interpreter.help as _help_module
        _help_module_is_registered = callable(_b.help) and callable(_help_module.help)
        """)

        #expect(Interpreter.evaluate("_help_module_is_registered") == true)
    }

    @Test("renders host-provided markdown documents as reference topics")
    func hostMarkdownDocuments() async throws {
        await Interpreter.run("""
        import interpreter.help as _help_module
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

    @Suite("no args", .serialized) @MainActor
    struct NoArgs {
        init() async {
            await Interpreter.run("import interpreter")
            await Interpreter.run("import interpreter.help as _help; _help._help_text = None")
        }

        @Test("returns None")
        func returnsNone() async {
            await Interpreter.run("_help_none_r = help()")
            #expect(Interpreter.evaluate("_help_none_r is None") == true)
        }

        @Test("prints welcome text")
        func printsWelcomeText() async throws {
            await Interpreter.run("""
            import builtins as _b
            import interpreter.help as _help
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
        func printsConfiguredWelcomeText() async throws {
            await Interpreter.run("""
            import builtins as _b
            import interpreter.help as _help
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
    @Suite("class markdown", .serialized) @MainActor
    struct ClassMarkdown {
        init() async {
            await Interpreter.run("import interpreter")
            await Interpreter.run("import interpreter.help as _help_module")
        }

        private func markdown(of path: String) async throws -> String {
            await Interpreter.run("""
            import \(path.split(separator: ".")[0])
            _cm_out = "\\n".join(_help_module._markdown_lines('\(path)'))
            """)
            return try #require(Interpreter.evaluate("_cm_out"))
        }

        @Test("opens with its parent, declaration, and summary")
        func opening() async throws {
            let output = try await markdown(of: "p2p.Peer")

            #expect(output.hasPrefix("""
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
        func methods() async throws {
            let output = try await markdown(of: "p2p.Peer")

            #expect(output.contains("""
            ## Functions

            ### ``p2p.Peer/advertise()``

            ```python
            def advertise(self) -> None
            ```

            Makes the peer discoverable.
            """))
        }

        // pathlib is CPython's own on that backend.
        #if !cpython
        @Test("marks static methods in their declarations")
        func staticMethods() async throws {
            let output = try await markdown(of: "pathlib.Path")

            #expect(output.contains("""
            ### ``pathlib.Path/cwd()``

            ```python
            @staticmethod
            def cwd() -> Path
            ```
            """))
        }
        #endif

        /// The macro binds the initializer's comment too, so it reads as a
        /// method does rather than being buried in the class stub.
        @Test("lists the initializer above the methods")
        func initializers() async throws {
            let output = try await markdown(of: "p2p.Peer")

            #expect(output.contains("""
            ## Initializers

            ### ``p2p.Peer/__init__(name)``

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
        func withoutInitializer() async throws {
            await Interpreter.run("""
            _no_init = "\\n".join(_help_module._markdown_lines(int))
            """)
            let output: String = try #require(Interpreter.evaluate("_no_init"))

            #expect(!output.contains("## Initializers"))
        }

        /// A subclass links to what it inherits rather than repeating it: every
        /// view would otherwise list all of `View`'s modifiers.
        @Test("links inherited functions instead of listing them")
        func inheritedFunctions() async throws {
            await Interpreter.run("""
            class _HelpBase:
                def shared(self):
                    "Shared by subclasses."

            class _HelpChild(_HelpBase):
                def own(self):
                    "Only the child's."

            _inherited = "\\n".join(_help_module._markdown_lines(_HelpChild))
            """)
            let output: String = try #require(Interpreter.evaluate("_inherited"))

            #expect(output.contains("own()"))
            #expect(!output.contains("shared()"))
            #expect(output.contains("Inherits the functions of ``__main__/_HelpBase``."))
        }

        @Test("takes the method signature from the binding")
        func methodSignature() async throws {
            let output = try await markdown(of: "p2p.Peer")

            #expect(output.contains("def autoconnect(self, name: str) -> None"))
            // The trailing colon belongs to a source stub, not to a signature.
            #expect(!output.contains("-> None:"))
        }

        @Test("is not the plain stub it used to be")
        func isNotAStub() async throws {
            let output = try await markdown(of: "p2p.Peer")

            #expect(!output.hasPrefix("```python"))
            #expect(!output.contains("\"\"\""))
        }

        /// A property carries no signature, so its declaration stands in for
        /// one, and what documents it is its getter.
        @Test("lists the properties with what declares and describes them")
        func properties() async throws {
            await Interpreter.run("""
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

        // pathlib is CPython's own on that backend.
        #if !cpython
        @Test("lists properties like function parameters")
        func propertyRows() async throws {
            let output = try await markdown(of: "pathlib.Path")

            #expect(output.contains("""
            ## Properties

            - `name` (read only): The final component of the path.
            """))
            #expect(!output.contains("### ``pathlib.Path/name``"))

            let properties = try #require(output.range(of: "## Properties"))
            let initializers = try #require(output.range(of: "## Initializers"))
            #expect(properties.lowerBound < initializers.lowerBound)
        }
        #endif

        /// A native class's properties are getset descriptors, typed only in its stub.
        @Test("lists a native class's properties")
        func nativeProperties() async throws {
            let output = try await markdown(of: "p2p.Peer")

            #expect(output.contains("## Properties"))
            #expect(output.contains("- `on_message: "))
            #expect(output.contains("Callback handler."))

            let page = try await markdown(of: "p2p.Peer.on_message")
            #expect(page.hasPrefix("# on_message"))
            #expect(page.contains("Callback handler."))
        }

        @Test("shows an enum's definition with its cases")
        func enumCases() async throws {
            await Interpreter.run("""
            import enum
            class _Edge(enum.StrEnum):
                '''Where it sits.'''
                TOP = "top"
                BOTTOM = "bottom"

            _enum_out = "\\n".join(_help_module._markdown_lines(_Edge))
            """)
            let output: String = try #require(Interpreter.evaluate("_enum_out"))

            #expect(output.contains("""
            ```python
            class _Edge(StrEnum):
                TOP = 'top'
                BOTTOM = 'bottom'
            ```
            """))
            #expect(!output.contains("## Cases"))
            #expect(!output.contains("## Properties"))
        }

        /// Reached by its path, a property documents itself rather than the
        /// `property` it is an instance of.
        // pathlib is CPython's own on that backend.
        #if !cpython
        @Test("documents a property of its own")
        func propertyPage() async throws {
            let output = try await markdown(of: "pathlib.Path.name")

            #expect(output == """
            # name

            ``pathlib``

            The final component of the path.

            ```python
            name  # read only
            ```
            """)
        }
        #endif

        /// Nothing names the module when help is handed the class itself, so
        /// the methods keep their headings without references.
        @Test("documents a class reached without a path")
        func withoutPath() async throws {
            await Interpreter.run("""
            import p2p
            _np_out = "\\n".join(_help_module._markdown_lines(p2p.Peer))
            """)
            let output: String = try #require(Interpreter.evaluate("_np_out"))

            #expect(output.hasPrefix("""
            ```python
            class Peer
            ```
            """))
            #expect(output.contains("### advertise"))
            #expect(!output.contains("### ``"))
        }

        // Reads pocketpy's native functions.
        #if !cpython
        @Test("links methods of a built-in class handed to help")
        func builtInClassReferences() async throws {
            await Interpreter.run("""
            _builtin_out = "\\n".join(_help_module._markdown_lines(str))
            _builtin_member_out = "\\n".join(_help_module._markdown_lines('str.upper'))
            """)
            let output: String = try #require(Interpreter.evaluate("_builtin_out"))
            let memberOutput: String = try #require(Interpreter.evaluate("_builtin_member_out"))

            #expect(output.contains("### ``str/count(...)``"))
            #expect(output.contains("### ``str/encode(...)``"))
            #expect(memberOutput.hasPrefix("""
            ``str``

            ```python
            def upper(...)
            ```
            """))
            #expect(memberOutput.contains("def upper(...)"))
            #expect(!memberOutput.contains("<nativefunc object>"))
        }
        #endif
    }

    /// A module lists its classes the way it lists its functions: the name
    /// linked to its own help, over what it declares and what it is for.
    @Suite("module class listing", .serialized) @MainActor
    struct ModuleClassListing {
        init() async {
            await Interpreter.run("import interpreter")
            await Interpreter.run("import interpreter.help as _help_module")
        }

        private func markdown(of module: String) async throws -> String {
            await Interpreter.run("""
            import \(module)
            _cl_out = "\\n".join(_help_module._markdown_lines('\(module)'))
            """)
            return try #require(Interpreter.evaluate("_cl_out"))
        }

        @Test("links a documented class over its declaration and summary")
        func documentedClass() async throws {
            let output = try await markdown(of: "p2p")

            #expect(output.contains("""
            ### ``p2p/Peer``

            ```python
            class Peer
            ```

            An object represents a peer in a multipeer session.
            """))
        }

        // asyncio is CPython's own on that backend.
        #if !cpython
        @Test("shows a class with no documentation as its declaration alone")
        func undocumentedClass() async throws {
            let output = try await markdown(of: "asyncio")

            #expect(output.contains("""
            ### ``asyncio/AsyncTask``

            ```python
            class AsyncTask
            ```
            """))
        }
        #endif

        /// A class declared by an interface string has no `__doc__`, so the
        /// summary comes from the docstring inside the stub.
        @Test("summarises a class declared by an interface string")
        func interfaceDeclaredClass() async throws {
            await Interpreter.run("""
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
        func explicitPublicAPI() async throws {
            await Interpreter.run("""
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
        func notOneCodeBlock() async throws {
            let output = try await markdown(of: "p2p")

            #expect(!output.contains("""
            ## Classes

            ```python
            """))
        }
    }

    /// A package lists its modules, which are neither classes nor functions.
    #if cpython
    @Suite("package module listing", .serialized) @MainActor
    struct PackageModuleListing {
        init() async {
            await Interpreter.run("import interpreter")
            await Interpreter.run("import interpreter.help as _help_module")
        }

        private func markdown(of path: String) async throws -> String {
            await Interpreter.run("""
            \(path == "modules" ? "" : "import \(path.split(separator: ".")[0])")
            _pl_out = "\\n".join(_help_module._markdown_lines('\(path)'))
            """)
            return try #require(Interpreter.evaluate("_pl_out"))
        }

        @Test("lists its modules with their summaries")
        func modules() async throws {
            let output = try await markdown(of: "json")

            #expect(output.contains("""
            ## Modules

            ### ``json/decoder``

            ```python
            import json.decoder
            ```

            Implementation of JSONDecoder
            """))
            #expect(!output.contains("json/__main__"))
        }

        @Test("lists the app's modules, the bundled ones, then the standard library")
        func moduleGroups() async throws {
            let output = try await markdown(of: "modules")
            let other = try #require(output.range(of: "## Other modules"))
            let stdlib = try #require(output.range(of: "## Standard library"))

            #expect(output.hasPrefix("## "))
            #expect(output.range(of: "| ``interpreter`` |")!.lowerBound < other.lowerBound)
            #expect(output[other.upperBound..<stdlib.lowerBound].contains("| ``PIL`` |"))
            #expect(output[stdlib.upperBound...].contains("| ``json`` |"))
        }

        @Test("counts what the app bundles as its own, apart from the standard library")
        func appModules() async throws {
            await Interpreter.run("""
            _pl_app = _help_module._app_modules()
            _pl_stdlib = _help_module._stdlib_modules()
            """)
            let app: [String] = try #require(Interpreter.evaluate("_pl_app"))
            let stdlib: [String] = try #require(Interpreter.evaluate("_pl_stdlib"))

            #expect(app.contains("PIL"))
            #expect(app.contains("interpreter"))
            #expect(!app.contains("json"))
            #expect(stdlib.contains("json"))
            #expect(!stdlib.contains("PIL"))
        }

        @Test("opens a module its package has not imported")
        func unimportedModule() async throws {
            let output = try await markdown(of: "profiling.tracing")

            #expect(output.contains("Tracing profiler for Python."))
        }
    }
    #endif

    /// The markdown a function's help renders as. The reference for the layout
    /// is `help('requests.get')`, checked against the real module in
    /// swiftpy-requests; these cover the parsing on its own.
    @Suite("function markdown", .serialized) @MainActor
    struct FunctionMarkdown {
        init() async { await Interpreter.run("import interpreter") }

        private func markdown(of expression: String) async throws -> String {
            await Interpreter.run("""
            import interpreter.help as _help_module
            _fm_out = "\\n".join(_help_module._markdown_lines(\(expression)))
            """)
            return try #require(Interpreter.evaluate("_fm_out"))
        }

        @Test("shows syntax before the summary without a redundant title")
        func syntaxAndSummary() async throws {
            await Interpreter.run("""
            def _summarized(value):
                '''Does a thing.'''
                pass
            """)

            let output = try await markdown(of: "_summarized")

            #expect(output.hasPrefix("""
            ```python
            def _summarized(value)
            ```

            Does a thing.
            """))
        }

        @Test("reads Google style sections")
        func googleStyle() async throws {
            await Interpreter.run("""
            def _google(map_fn, filter_fn=None):
                '''Maps the parameters with ``map_fn``.

                Args:
                    map_fn (Callable): Maps an array to another array
                    filter_fn (Callable, optional): Filter to select which arrays to
                        map (default: :meth:`Module.valid_parameter_filter`).

                Returns:
                    The module instance.

                Raises:
                    ValueError: When a parameter is missing.
                '''
            """)

            let output = try await markdown(of: "_google")

            #expect(output.contains("Maps the parameters with `map_fn`."))
            #expect(output.contains("""
            ## Parameters

            - `map_fn`: Maps an array to another array
            - `filter_fn`: Filter to select which arrays to map (default: `Module.valid_parameter_filter`).

            ## Return Value

            The module instance.

            ## Raises

            - `ValueError`: When a parameter is missing.
            """))
            #expect(!output.contains("Args:"))
        }

        @Test("reads reST fields")
        func restFields() async throws {
            await Interpreter.run("""
            def _rest(mode, dither=None):
                '''Converts an image.

                :param mode: The requested mode.
                :param dither: Dithering method, used when converting
                   to "P".
                :type dither: int
                :returns: An :py:class:`~PIL.Image.Image` object.
                :rtype: Image
                '''
            """)

            let output = try await markdown(of: "_rest")

            #expect(output.contains("""
            - `mode`: The requested mode.
            - `dither`: Dithering method, used when converting to "P".

            ## Return Value

            An `PIL.Image.Image` object.
            """))
            #expect(!output.contains(":type"))
            #expect(!output.contains(":rtype"))
        }

        @Test("documents the model decorator")
        func modelDecorator() async throws {
            let output = try await markdown(of: "'modeling.model'")

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

        // asyncio is CPython's own on that backend.
        #if !cpython
        @Test("shows a bound signature without its trailing colon")
        func boundSignature() async throws {
            await Interpreter.run("import asyncio")

            let output = try await markdown(of: "asyncio.sleep")

            #expect(output.contains("""
            ```python
            async def sleep(seconds: float) -> None
            ```
            """))
            // The trailing colon belongs to a source stub, not to a signature.
            #expect(!output.contains("-> None:"))
        }
        #endif

        /// Each overload documents its own signature, so the page repeats the
        /// sections rather than merging what belongs to one of them.
        // Overloads are pocketpy's.
        #if !cpython
        @Test("documents each overload under its own signature")
        func overloadSections() async throws {
            await bindResponder()

            let output = try await markdown(of: "Responder.respond")

            // Help is handed the method itself, so nothing names the class it
            // is reached through and the page opens on the first signature.
            #expect(output == """
            ```python
            @overload
            def respond(self, prompt: str) -> str
            ```

            Produces a response to a prompt.

            ## Parameters

            - `prompt`: What to respond to.

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
        #endif

        /// A listing heads every overload with the same name, each over the
        /// signature it documents.
        // Overloads are pocketpy's.
        #if !cpython
        @Test("lists an overload dispatcher as one entry per overload")
        func overloadEntries() async throws {
            await bindResponder()
            await Interpreter.run("""
            _overload_entries = "\\n".join(
                _help_module._function_entries(
                    'agents.Agent', [('respond', Responder.respond)]
                )
            )
            """)
            let entries: String = try #require(Interpreter.evaluate("_overload_entries"))

            #expect(entries.contains("""
            ### ``agents.Agent/respond(prompt)``

            ```python
            @overload
            def respond(self, prompt: str) -> str
            ```

            Produces a response to a prompt.

            ### ``agents.Agent/respond(prompt, schema)``

            ```python
            @overload
            def respond(self, prompt: str, schema: Any) -> Any
            ```
            """))
        }
        #endif

        /// Python can no longer set attributes on a function, so an overload
        /// dispatcher has to come from a real binding.
        private func bindResponder() async {
            PyBind.module("HelpOverloadTests") { module in
                module.class(Responder.self)
            }
            await Interpreter.run("""
            import interpreter.help as _help_module
            from HelpOverloadTests import Responder
            """)
        }

        @Test("lists the documented parameters and leaves the rest out")
        func parameters() async throws {
            await Interpreter.run("""
            def _fetch(url, params, timeout):
                '''Sends a request.

                params: Mapping appended to the URL's query.
                timeout: Seconds allowed to pass without receiving data.
                '''
                pass
            """)

            let output = try await markdown(of: "_fetch")

            #expect(output.contains("""
            ## Parameters

            - `params`: Mapping appended to the URL's query.
            - `timeout`: Seconds allowed to pass without receiving data.
            """))
            #expect(!output.contains("- `url`"))
            #expect(!output.contains("## Discussion"))
        }

        @Test("keeps prose out of the parameters")
        func discussion() async throws {
            await Interpreter.run("""
            def _documented(value, other):
                '''Does a thing.

                Some discussion of the thing.
                It runs on for a second line.

                value: What to do it to.
                '''
                pass
            """)

            let output = try await markdown(of: "_documented")

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
        func wrappedParameterDescription() async throws {
            await Interpreter.run("""
            def _wrapped(count):
                '''Wraps.

                count: How many, described at
                    length over two lines.
                '''
                pass
            """)

            let output = try await markdown(of: "_wrapped")

            #expect(output.contains("- `count`: How many, described at length over two lines."))
            #expect(!output.contains("## Discussion"))
        }

        @Test("a colon in prose isn't a parameter")
        func colonInProse() async throws {
            await Interpreter.run("""
            def _prose(value):
                '''Explains.

                Note: this is prose, not a parameter.
                '''
                pass
            """)

            let output = try await markdown(of: "_prose")

            #expect(!output.contains("## Parameters"))
            #expect(output.contains("Note: this is prose, not a parameter."))
        }

        @Test("tells a module-rooted path from a name only the session owns")
        func isReference() async throws {
            await Interpreter.run("""
            import interpreter.help as _help_module
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
        func noDocstring() async throws {
            await Interpreter.run("""
            def _bare(x):
                pass
            """)

            let output = try await markdown(of: "_bare")

            // The signature is all there is to show; a title would only repeat it.
            #expect(output == """
            ```python
            def _bare(x)
            ```
            """)
            #expect(!output.contains("## Parameters"))
            #expect(!output.contains("## Discussion"))
        }
    }

    @Suite("callable", .serialized) @MainActor
    struct Callable {
        init() async { await Interpreter.run("import interpreter") }

        // pocketpy native builtins don't expose __name__, so we use a user-defined function
        @Test("prints function name")
        func printsFunctionName() async throws {
            await Interpreter.run("""
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

        // asyncio is CPython's own on that backend.
        #if !cpython
        @Test("prints Swift-bound function signature")
        func printsSwiftBoundFunctionSignature() async throws {
            await Interpreter.run("""
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
        #endif
    }

    @Suite("class", .serialized) @MainActor
    struct Class {
        init() async { await Interpreter.run("import interpreter") }

        @Test("prints class name")
        func printsClassName() async throws {
            await Interpreter.run("""
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
        func printsMethods() async throws {
            await Interpreter.run("""
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
        func printsClassDocumentation() async throws {
            await Interpreter.run("""
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
        func usesClassInterfaceWhenAvailable() async throws {
            await Interpreter.run("""
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

        @Test("documents a method as async when its class interface does")
        func documentsAsyncMethodsFromTheClassInterface() async throws {
            await Interpreter.run("""
            from interpreter.help import _class_methods, _function_entries
            class _Bound:
                _interface = 'class Bound:\\n    async def go(self, x: int) -> str: ...\\n    def stop(self) -> None: ...'
                def go(self, x): pass
                def stop(self): pass
            _entries = "\\n".join(_function_entries("m.Bound", _class_methods(_Bound), _Bound))

            import sys, types
            from interpreter.help import _markdown_lines
            _module = types.ModuleType("_asyncdoc")
            _module.Bound = _Bound
            sys.modules["_asyncdoc"] = _module
            _page = "\\n".join(_markdown_lines("_asyncdoc.Bound.go"))
            _text = "\\n".join(_markdown_lines("_asyncdoc.Bound.stop"))
            """)

            let entries: String = try #require(Interpreter.evaluate("_entries"))
            #expect(entries.contains("async def go("))
            #expect(!entries.contains("async def stop("))

            // The member's own page, not only the class's listing of it.
            let page: String = try #require(Interpreter.evaluate("_page"))
            #expect(page.contains("async def go("))
            let stop: String = try #require(Interpreter.evaluate("_text"))
            #expect(!stop.contains("async def"))
        }
    }

    @Suite("instance", .serialized) @MainActor
    struct Instance {
        init() async { await Interpreter.run("import interpreter") }

        @Test("routes to type help")
        func routesToTypeHelp() async throws {
            await Interpreter.run("""
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

    @Suite("module", .serialized) @MainActor
    struct Module {
        init() async { await Interpreter.run("import interpreter") }

        @Test("prints module name")
        func printsModuleName() async throws {
            await Interpreter.run("""
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
        func showsPythonModuleFunctionsWithSignatures() async throws {
            await Interpreter.run("""
            import builtins as _b
            import interpreter.help as _help_module
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
        func showsDocumentedModuleFunctions() async throws {
            await Interpreter.run("""
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
            #expect(!output.contains("completions(text: str) -> list[str]"))
        }

        // asyncio is CPython's own on that backend.
        #if !cpython
        @Test("shows bound classes from Swift module")
        func showsSwiftModuleClasses() async throws {
            await Interpreter.run("""
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
        #endif
    }

    @Suite("string topic", .serialized) @MainActor
    struct StringTopic {
        init() async { await Interpreter.run("import interpreter") }

        @Test("imports module by name")
        func importsByName() async {
            await Interpreter.run("help('math')")
        }

        @Test("resolves a reference as its pages write it")
        func resolvesReferenceForm() async throws {
            await Interpreter.run("""
            import interpreter.help as _help_module
            _ref_dotted = "\\n".join(_help_module._markdown_lines('pathlib.Path.read_text'))
            _ref_slashed = "\\n".join(_help_module._markdown_lines('pathlib.Path/read_text(encoding, errors, newline)'))
            _ref_lines = _help_module._help_lines('pathlib/Path')
            """)

            let dotted: String = try #require(Interpreter.evaluate("_ref_dotted"))
            #expect(dotted.contains("def read_text("))
            #expect(Interpreter.evaluate("_ref_slashed") == dotted)
            #expect(Interpreter.evaluate("_ref_lines[0].startswith('No help')") == false)
        }

        @Test("resolves a member inside a module")
        func resolvesModuleMember() async throws {
            await Interpreter.run("""
            import builtins as _b
            import interpreter.help as _help_module
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
        func listsRegisteredModules() async throws {
            PyBind.module("testing.helper") { _ in }

            await Interpreter.run("""
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
            #expect(output.contains("  embeddings"))
            #expect(output.contains("  interpreter"))
            #expect(output.contains("  modeling"))
            #expect(output.contains("  p2p"))
            #expect(output.contains("  pathlib"))
            #expect(!output.contains("interpreter.native"))
            #expect(!output.contains("testing.helper"))
            #if !cpython
            // On CPython the stdlib is listed too, rlcompleter with it.
            #expect(!output.contains("help"))
            #expect(!output.contains("rlcompleter"))
            #endif
        }

        @Test("handles unknown module gracefully")
        func handlesUnknown() async {
            await Interpreter.run("help('_no_such_module_xyz')")
        }
    }

    #if cpython
    @Suite("stubs") @MainActor
    struct Stubs {
        init() async {
            await Interpreter.run("""
            import ast, json, interpreter
            _stubs = json.loads(interpreter._stubs())
            """)
        }

        @Test("are written for registered modules, not private ones")
        func coverRegisteredModules() {
            #expect(Interpreter.evaluate("'keychain.pyi' in _stubs") == true)
            #expect(Interpreter.evaluate("'_swiftpy_asyncio.pyi' in _stubs") == false)
        }

        @Test("are written for a private module backing a public one")
        func coverBackingModules() async {
            PyBind.module("_backed") { _ in }
            PyBind.module("backed") { _ in }
            await Interpreter.run("_stubs = json.loads(interpreter._stubs())")
            #expect(Interpreter.evaluate("'_backed.pyi' in _stubs") == true)
        }

        @Test("parse as Python")
        func parse() async {
            await Interpreter.run("""
            _unparsed = []
            for _path, _text in _stubs.items():
                try:
                    ast.parse(_text)
                except SyntaxError:
                    _unparsed.append(_path)
            """)
            #expect(Interpreter.evaluate("_unparsed") == [String]())
        }

        @Test("keep the bound signatures and classes")
        func keepSignatures() async {
            await Interpreter.run("""
            _keychain = ast.parse(_stubs['keychain.pyi'])
            _secret = next(n for n in _keychain.body if isinstance(n, ast.FunctionDef) and n.name == 'secret')
            _signature = [ast.unparse(_secret.args.args[0].annotation), ast.unparse(_secret.returns)]
            """)
            #expect(Interpreter.evaluate("_signature") == ["str", "Secret"])
            #expect(Interpreter.evaluate("'class Secret:' in _stubs['keychain.pyi']") == true)
        }

        @Test("add what SwiftPy puts in builtins, and only that")
        func builtins() async {
            await Interpreter.run("""
            _builtins_stub = ast.parse(_stubs['__builtins__.pyi'])
            _names = [ast.unparse(n) if isinstance(n, ast.ImportFrom) else n.name for n in _builtins_stub.body]
            """)
            #expect(Interpreter.evaluate("_names") == ["from _swiftpy_builtins import View as View", "help"])
        }

        @Test("leave out what a module imports")
        func withoutImports() async throws {
            await Interpreter.run("""
            import sys, types
            from typing import Any, Callable
            from os import getcwd
            from interpreter.help import _stub_lines
            _module = types.ModuleType("_imports")
            _module.__all__ = []
            _module.Any, _module.Callable, _module.getcwd = Any, Callable, getcwd
            class _Local: pass
            _Local.__name__ = "Local"
            _Local.__module__ = "_imports"
            _module.Local = _Local
            _module.limit = 3
            _imported = "\\n".join(_stub_lines(_module))
            """)
            let text: String = try #require(Interpreter.evaluate("_imported"))
            #expect(text.contains("class Local"))
            #expect(text.contains("limit: int"))
            #expect(!text.contains("Any:") && !text.contains("class Any"))
            #expect(!text.contains("Callable") && !text.contains("getcwd"))
        }

        /// A `type` alias is written as one, so annotations elsewhere can use
        /// it, rather than as a variable of type `TypeAliasType`.
        @Test("write a type alias as one, which other stubs import")
        func typeAliases() async throws {
            await Interpreter.run("""
            import ast, types
            from interpreter.help import _stub_lines, _typed_stub
            _module = types.ModuleType("_lengths")
            exec("class Amount: pass\\ntype Size = float | Amount", _module.__dict__)
            _module.Amount.__module__ = "_lengths"
            _module.Size.__module__ = "_lengths"
            _lengths = _typed_stub(ast.parse("\\n".join(_stub_lines(_module))), "_lengths", {}, set())
            _user = _typed_stub(ast.parse("def grow(by: Size) -> None: ..."), "_user", {"Size": "_lengths"}, set())
            """)
            let lengths: String = try #require(Interpreter.evaluate("_lengths"))
            let user: String = try #require(Interpreter.evaluate("_user"))
            #expect(lengths.contains("type Size = float | Amount"), "\(lengths)")
            #expect(user.contains("from _lengths import Size"), "\(user)")
            #expect(user.contains("by: Size"), "\(user)")
        }

        /// A decorator's overloads, so `@tool` and `@tool(...)` both type as a
        /// `Tool`, which `inspect` writes by its private module.
        @Test("keep a Python function's overloads, and its classes by name")
        func pythonOverloads() async throws {
            await Interpreter.run("""
            import ast, sys, types
            from interpreter.help import _stub_lines, _typed_stub
            _private = types.ModuleType("_tools")
            exec("class Tool: pass", _private.__dict__)
            _private.Tool.__module__ = "_tools"
            _module = types.ModuleType("_decorators")
            _module.Tool = _private.Tool
            exec('''
            from typing import Callable, overload
            __all__ = ["tool"]

            @overload
            def tool(fn: Callable) -> Tool: ...
            @overload
            def tool(fn: None = None, *, name: str = "") -> Callable[[Callable], Tool]: ...
            def tool(fn=None, *, name=""):
                "Makes a tool."
            ''', _module.__dict__)
            sys.modules["_decorators"] = _module
            _decorators = _typed_stub(ast.parse("\\n".join(_stub_lines(_module))), "_decorators", {"Tool": "_tools"}, set())
            del sys.modules["_decorators"]
            """)
            let text: String = try #require(Interpreter.evaluate("_decorators"))
            #expect(text.components(separatedBy: "@overload").count == 3, "\(text)")
            #expect(text.contains("from _tools import Tool"), "\(text)")
            #expect(text.contains("from typing import Any, Callable, overload"), "\(text)")
            #expect(text.contains("-> Tool"), "\(text)")
            #expect(text.contains("-> Callable[[Callable], Tool]"), "\(text)")
        }

        @Test("write a subclass of str with its own members only")
        func builtinSubclass() async throws {
            await Interpreter.run("""
            import ast
            from interpreter import InputResult
            from interpreter.help import _class_lines
            _result_stub = "\\n".join(_class_lines(InputResult))
            _parses = bool(ast.parse(_result_stub))
            """)
            let text: String = try #require(Interpreter.evaluate("_result_stub"))
            #expect(text.contains("class InputResult(str):"), "\(text)")
            #expect(!text.contains("def count"), "\(text)")
            #expect(text.contains("    images: list"), "\(text)")
            #expect(Interpreter.evaluate("_parses") == true)
        }

        @Test("import a class from the public module that re-exports it")
        func publicOwners() async throws {
            await Interpreter.run("""
            import ast
            from interpreter.help import _class_owners
            _owners = _class_owners({
                "_models.pyi": ("_models", ast.parse("class Model: pass\\nclass Hidden: pass")),
                "models.pyi": ("models", ast.parse("class Model: pass")),
                "other.pyi": ("other", ast.parse("class Model: pass")),
            })
            """)
            #expect(Interpreter.evaluate("_owners['Model']") == "models")
            #expect(Interpreter.evaluate("_owners['Hidden']") == "_models")
        }

        @Test("import a class the module took from the standard library")
        func standardLibraryImports() async throws {
            await Interpreter.run("""
            import ast, sys, types
            from interpreter.help import _stub_lines, _typed_stub
            _module = types.ModuleType("_sources")
            exec("__all__ = ['Source']\\nfrom os import PathLike\\ntype Source = str | PathLike[str] | bytes", _module.__dict__)
            _module.Source.__module__ = "_sources"
            sys.modules["_sources"] = _module
            _sources = _typed_stub(ast.parse("\\n".join(_stub_lines(_module))), "_sources", {}, set())
            del sys.modules["_sources"]
            """)
            let text: String = try #require(Interpreter.evaluate("_sources"))
            #expect(text.contains("from os import PathLike"), "\(text)")
            #expect(text.contains("type Source = str | PathLike[str] | bytes"), "\(text)")
        }

        @Test("keep an enum's members and a class's constants")
        func membersAndConstants() async throws {
            await Interpreter.run("""
            import types, enum
            from interpreter.help import _stub_lines, _typed_stub
            _module = types.ModuleType("_options")
            class _Edge(enum.StrEnum):
                TOP = "top"
                TOP_LEADING = "top-leading"
                def flipped(self): return self
            class _Limits:
                LOW = 1
                NAME = "limits"
            for _cls in (_Edge, _Limits):
                _cls.__name__ = _cls.__name__[1:]
                _cls.__module__ = "_options"
                setattr(_module, _cls.__name__, _cls)
            _options = _typed_stub(ast.parse("\\n".join(_stub_lines(_module))), "_options", {}, set())
            """)
            let text: String = try #require(Interpreter.evaluate("_options"))
            #expect(text.contains("from enum import StrEnum"))
            #expect(text.contains("class Edge(StrEnum):"))
            #expect(text.contains("TOP = 'top'") && text.contains("TOP_LEADING = 'top-leading'"))
            #expect(text.contains("def flipped(self)"))
            #expect(!text.contains("def capitalize"))
            #expect(text.contains("LOW: int") && text.contains("NAME: str"))
        }

        @Test("leave out what only Swift knows")
        func withoutSwiftNames() async {
            await Interpreter.run("""
            from interpreter.help import _typed_stub, _without_swift_syntax
            _typed = _typed_stub(ast.parse(_without_swift_syntax(
                "class A(Unknown):\\n    x: UInt64\\n    y: list[any P]\\n    @overload\\n    def f(self) -> Data: ..."
            )), "m", {}, {"View"})
            """)
            #expect(Interpreter.evaluate("'class A:' in _typed") == true)
            #expect(Interpreter.evaluate("'x: Any' in _typed and 'y: list[Any]' in _typed") == true)
            #expect(Interpreter.evaluate("'-> Any' in _typed and 'overload' not in _typed") == true)
            #expect(Interpreter.evaluate("'from typing import Any' in _typed") == true)
        }
    }
    #endif
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
        ) { _, _ in PyAPI.return { nil } }

        type.function(
            "respond(self, prompt: str, schema: Any) -> Any",
            """
            Produces a structured response to a prompt.

            prompt: What to respond to.
            schema: The type the response conforms to.
            """
        ) { _, _ in PyAPI.return { nil } }
    }
}
