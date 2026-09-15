import inspect
from interpreter.native import modules as _registered_modules


def _callable_signature(obj, fallback_name=None):
    interface = getattr(obj, '_interface', None)
    if interface:
        return interface

    name = fallback_name or getattr(obj, '__name__', None) or repr(obj)
    try:
        return name + str(inspect.signature(obj))
    except:
        pass

    # A native bound method can hide the descriptor's text signature. Recover
    # the declaration generated for its Swift-bound owner in that case.
    try:
        owner = getattr(obj, '__self__', None)
        owner_type = owner if isinstance(owner, type) else type(owner)
        owner_interface = getattr(owner_type, '_interface', None)
        if owner_interface:
            marker = "def " + name + "("
            for line in owner_interface.split("\n"):
                declaration = line.strip()
                start = declaration.find(marker)
                if start != -1:
                    signature = declaration[start + len("def "):]
                    if signature.endswith(" ..."):
                        signature = signature[:-len(" ...")]
                    if signature.endswith(":"):
                        signature = signature[:-1]
                    parameters = _parameter_text(signature)
                    if parameters is not None:
                        parts = _split_top_level(parameters)
                        if parts and parts[0].strip() in ('self', 'cls'):
                            parts = parts[1:]
                        opening = signature.find("(")
                        closing = opening + len(parameters) + 1
                        return signature[:opening + 1] + ", ".join(parts) + signature[closing:]
    except:
        pass

    return name + "(...)"


def _callable_definition(obj, fallback_name=None):
    signature = _callable_signature(obj, fallback_name)
    try:
        is_coroutine = inspect.iscoroutinefunction(obj)
    except:
        is_coroutine = False
    prefix = "async " if getattr(obj, '_is_async', False) or is_coroutine else ""
    if signature.startswith("def "):
        signature = signature[len("def "):]
    if not signature.endswith(":"):
        signature = signature + ":"
    return prefix + "def " + signature


def _callable_definitions(obj, fallback_name=None):
    overloads = getattr(obj, '_overloads', None)
    if not overloads:
        return [_callable_definition(obj, fallback_name)]
    return [_callable_definition(overload, fallback_name) for overload in overloads]


def _callable_doc(obj):
    doc = getattr(obj, '__doc__', None)
    if doc:
        return doc
    for overload in getattr(obj, '_overloads', None) or []:
        doc = getattr(overload, '__doc__', None)
        if doc:
            return doc
    return None


def _signature_card(entry, definition, overload=False):
    declaration = []
    if overload:
        declaration.append("@overload")
    if getattr(entry, '_is_static', False):
        declaration.append("@staticmethod")
    declaration += _interface_lines(definition)
    return _fenced(declaration)


def _signature_cards(obj, definitions):
    overloads = getattr(obj, '_overloads', None)
    entries = overloads if overloads else [obj]
    lines = []
    for index in range(len(definitions)):
        lines += _signature_card(
            entries[index], definitions[index], overload=bool(overloads)
        )
        lines.append("")
    lines.pop()
    return lines


def _docstring_lines(doc, indent="    "):
    lines = doc.strip().split("\n")
    if len(lines) == 1:
        return [indent + '"""' + lines[0] + '"""']

    body = [indent + '"""' + lines[0]]
    body += [indent + line for line in lines[1:]]
    body.append(indent + '"""')
    return body


def _callable_lines(obj, fallback_name=None, indent=""):
    definition = indent + _callable_definition(obj, fallback_name)

    doc = getattr(obj, '__doc__', None)
    if not doc:
        return [definition + " ..."]

    return [definition] + _docstring_lines(doc, indent + "    ")


def _class_signature(cls):
    base = cls.__base__
    if base is not None and base.__name__ != 'object':
        return "class " + cls.__name__ + "(" + base.__name__ + "):"
    return "class " + cls.__name__ + ":"


def _class_lines(cls):
    interface = getattr(cls, '_interface', None)
    if interface:
        return [interface]

    lines = [_class_signature(cls)]

    doc = getattr(cls, '__doc__', None)
    if doc:
        lines += _docstring_lines(doc)

    for attr_name in dir(cls):
        if attr_name.startswith('_'):
            continue
        try:
            attr = getattr(cls, attr_name)
        except:
            continue
        if not callable(attr):
            continue

        # A blank line separates members, but not the first one from its class.
        if len(lines) > 1:
            lines.append("")
        lines += _callable_lines(attr, fallback_name=attr_name, indent="    ")

    # An empty class body still needs one, as in a stub file.
    if len(lines) == 1:
        return [lines[0] + " ..."]

    return lines


def _available_modules():
    # Enumerate what this interpreter ships, not the full CPython distribution.
    # iter_modules consults sys.path (including zip files) without executing
    # discovered modules. Recompute so later registrations and paths appear.
    try:
        import pkgutil
        import sys
        import _imp
    except ImportError:
        return _registered_modules()
    names = set(_registered_modules())
    names.update(sys.builtin_module_names)
    names.update([name for name, module in list(sys.modules.items()) if module is not None])
    names.update(_imp._frozen_module_names())
    names.update([info.name for info in pkgutil.iter_modules()])
    # SwiftPy's source importer also searches these locations outside sys.path.
    import os
    from pathlib import Path
    directories = [os.getcwd()]
    try:
        site = str(Path.site_packages())
        directories.append(site)
        directories.extend([os.path.join(site, entry) for entry in os.listdir(site) if os.path.isdir(os.path.join(site, entry))])
    except OSError:
        pass
    for directory in directories:
        try:
            names.update([entry[:-3] for entry in os.listdir(directory) if entry.endswith('.py') and os.path.isfile(os.path.join(directory, entry))])
        except OSError:
            pass
    return sorted([
        name for name in names
        if '.' not in name and not name.startswith('_') and name.isidentifier()
    ])


def _code_docstring(code):
    """The string a module's code stores as `__doc__`, docstring or assignment."""
    import dis
    previous = None
    for instruction in dis.get_instructions(code):
        if (instruction.opname == 'STORE_NAME' and instruction.argval == '__doc__'
                and previous is not None and previous.opname == 'LOAD_CONST'
                and isinstance(previous.argval, str)):
            return previous.argval
        previous = instruction
    return None


def _unimported_module_doc(name):
    """A module's doc without running it: a listing must not execute user code.
    Bytecode and source loaders hand out code objects; builtin modules are C
    already linked into the interpreter, so importing those does nothing."""
    import importlib.util
    import importlib.machinery
    spec = importlib.util.find_spec(name)
    loader = spec.loader if spec is not None else None
    if loader is None:
        return None
    if loader is importlib.machinery.BuiltinImporter:
        return getattr(importlib.import_module(name), '__doc__', None)
    if hasattr(loader, 'get_code'):
        code = loader.get_code(name)
        if code is not None:
            return _code_docstring(code)
    source = loader.get_source(name) if hasattr(loader, 'get_source') else None
    if source:
        import ast
        tree = ast.parse(source)
        doc = ast.get_docstring(tree)
        if doc is None:
            for node in tree.body:
                if isinstance(node, ast.Assign) and any([isinstance(t, ast.Name) and t.id == '__doc__' for t in node.targets]):
                    if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
                        return node.value.value
        return doc
    return None


def _module_doc(name):
    try:
        import sys
        if getattr(getattr(sys, 'implementation', None), 'name', None) == 'cpython':
            module = sys.modules.get(name)
            if module is not None:
                doc = getattr(module, '__doc__', None)
            else:
                doc = _unimported_module_doc(name)
        else:
            doc = getattr(__import__(name), '__doc__', None)
        if doc:
            return doc.strip().split("\n")[0]
    except:
        pass
    return None


def _module_summary(name):
    doc = _module_doc(name)
    if doc:
        return name + " - " + doc
    return name


def _modules_lines():
    lines = ["Registered modules:", ""]
    for name in _available_modules():
        lines.append("  " + _module_summary(name))
    return lines


def _resolve_name(name):
    parts = name.split('.')
    try:
        obj = __import__(parts[0])
    except ImportError:
        obj = getattr(__import__('builtins'), parts[0])
    for part in parts[1:]:
        obj = getattr(obj, part)
    return obj


# Topics help documents without resolving a name for them. Hosts can add
# complete markdown documents to `_documents` without binding fake Python
# objects for them.
_topics = ('modules',)
_documents = {}


def _bundled_document(name):
    from pathlib import Path
    try:
        path = Path.resources() / (name + '.md')
        return path.read_text() if path.is_file() else None
    except Exception:
        return None


def _document(name):
    return _documents.get(name) or _bundled_document(name)


def _is_reference(name):
    if name in _topics or _document(name) is not None:
        return True

    try:
        _resolve_name(name)
        return True
    except (ImportError, AttributeError):
        return False


def _module_members(module):
    classes = []
    functions = []
    exported_names = getattr(module, '__all__', None)
    names = exported_names if exported_names is not None else dir(module)

    for attr_name in names:
        if not isinstance(attr_name, str) or attr_name.startswith('_'):
            continue
        try:
            attr = getattr(module, attr_name)
        except:
            continue
        if isinstance(attr, type):
            classes.append((attr_name, attr))
        elif callable(attr):
            functions.append((attr_name, attr))
    # Preserve an explicit public API's declared order. `dir` hands fallback
    # names back in no order worth showing.
    if exported_names is None:
        classes.sort()
        functions.sort()
    return classes, functions


def _module_lines(module):
    name = getattr(module, '__name__', None) or str(module)
    lines = ["Help on module " + name + ":", ""]

    doc = getattr(module, '__doc__', None)
    if doc:
        lines.append(doc)
        lines.append("")

    classes, functions = _module_members(module)

    if classes:
        lines.append("## Classes")
        for _, cls in classes:
            lines.append("")
            lines += _class_lines(cls)
        lines.append("")

    if functions:
        lines.append("## Functions")
        for name, function in functions:
            lines.append("")
            lines += _callable_lines(function, fallback_name=name)

    return lines


_help_text = None


def _default_help_text():
    return """
SwiftPy Python help

Pass a name to `help` to see what it documents.

See also ``modules``.
""".strip()


def _help_lines(obj):
    if obj is None:
        return [_document('README') or _help_text or _default_help_text()]

    module_type = type(__import__('sys'))

    if isinstance(obj, str):
        document = _document(obj)
        if document is not None:
            return [document]
        if obj == "modules":
            return _modules_lines()

        try:
            resolved = _resolve_name(obj)
        except (ImportError, AttributeError):
            return ["No help found for " + repr(obj)]
        if isinstance(resolved, module_type):
            return _module_lines(resolved)
        if isinstance(resolved, type):
            return _class_lines(resolved)
        if callable(resolved):
            # A native function carries no `__name__`, so without the name it
            # was looked up by it prints as its repr.
            return _callable_lines(resolved, fallback_name=obj.split('.')[-1])
        return _class_lines(type(resolved))

    if isinstance(obj, module_type):
        return _module_lines(obj)
    if isinstance(obj, type):
        return _class_lines(obj)
    if callable(obj):
        return _callable_lines(obj)
    return _class_lines(type(obj))


def _fenced(lines):
    return ["```python"] + lines + ["```"]


def _fenced_stubs(stubs):
    body = []
    for stub in stubs:
        if body:
            body.append("")
        body += stub
    return _fenced(body)


def _definition_name(definition):
    start = definition.find("def ")
    start = 0 if start == -1 else start + len("def ")
    end = definition.find("(", start)
    if end == -1:
        return _without_trailing_colon(definition[start:])
    return definition[start:end].strip()


def _split_top_level(text):
    parts = []
    current = ""
    depth = 0
    for char in text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += char
    parts.append(current)
    return parts


def _parameter_text(definition):
    start = definition.find("(")
    if start == -1:
        return None

    # An annotation can hold brackets of its own, so the closing one is the
    # bracket that returns to depth zero.
    depth = 0
    index = start
    while index < len(definition):
        char = definition[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                return definition[start + 1:index]
        index += 1
    return None


def _takes_self(definition):
    # Nothing at runtime tells a bound static method from an instance one;
    # the signature is what says so, as it does in Python.
    text = _parameter_text(definition)
    if not text:
        return False

    return _split_top_level(text)[0].strip() == "self"


def _parameter_names(definition):
    text = _parameter_text(definition)
    if text is None:
        return []

    names = []
    for part in _split_top_level(text):
        name = part.strip()
        for separator in (":", "="):
            cut = name.find(separator)
            if cut != -1:
                name = name[:cut].strip()
        name = name.lstrip("*").strip()
        if name and name != "self":
            names.append(name)
    return names


def _dedented(doc):
    # The first line follows the quotes, so it carries no indentation.
    lines = doc.split("\n")
    body = lines[1:]

    indents = []
    for line in body:
        if line.strip():
            indents.append(len(line) - len(line.lstrip()))
    indent = min(indents) if indents else 0

    return [lines[0].strip()] + [line[indent:] for line in body]


def _parameter_description(line, parameter_names):
    # Matching the name is what keeps prose holding a colon out.
    cut = line.find(":")
    if cut <= 0:
        return None

    name = line[:cut].strip()
    if name not in parameter_names:
        return None

    return (name, line[cut + 1:].strip())


def _doc_sections(doc, parameter_names):
    if not doc:
        return None, [], []

    lines = _dedented(doc)

    summary = []
    index = 0
    while index < len(lines) and lines[index].strip():
        summary.append(lines[index].strip())
        index += 1

    parameters = []
    discussion = []
    # A line directly under a parameter carries on its description; a blank
    # line ends it, so prose after the parameters stays discussion.
    in_parameter = False
    for line in lines[index:]:
        stripped = line.strip()
        parameter = _parameter_description(stripped, parameter_names)

        if parameter:
            parameters.append(parameter)
            in_parameter = True
        elif not stripped:
            in_parameter = False
            discussion.append("")
        elif in_parameter:
            name, description = parameters[-1]
            parameters[-1] = (name, description + " " + stripped)
        else:
            discussion.append(line)

    while discussion and not discussion[0].strip():
        discussion.pop(0)
    while discussion and not discussion[-1].strip():
        discussion.pop()

    return " ".join(summary), parameters, discussion


def _without_trailing_colon(text):
    # pocketpy has no `str.rstrip`, so the stub's colon comes off by hand.
    text = text.strip()
    return text[:-1].strip() if text.endswith(":") else text


def _interface_lines(definition, max_length=60):
    definition = _without_trailing_colon(definition)
    if len(definition) <= max_length:
        return [definition]

    parameters = _parameter_text(definition)
    start = definition.find("(")
    if parameters is None or start == -1:
        return [definition]

    suffix = definition[start + len(parameters) + 2:]
    lines = [definition[:start + 1]]
    for parameter in _split_top_level(parameters):
        parameter = parameter.strip()
        if parameter:
            lines.append("    " + parameter + ",")
    lines.append(")" + suffix)
    return lines


def _return_annotation(definition):
    parts = definition.split("->")
    if len(parts) == 1:
        return None
    return _without_trailing_colon(parts[-1])


def _owning_module_name(path):
    # A function carries no module of its own, so the path it was looked up by
    # says where it came from. The longest prefix that is still a module owns it,
    # which keeps a method under its module rather than its class.
    parts = path.split('.')
    module_type = type(__import__('sys'))

    name = None
    for index in range(1, len(parts)):
        prefix = '.'.join(parts[:index])
        try:
            resolved = _resolve_name(prefix)
        except (ImportError, AttributeError):
            break
        if not isinstance(resolved, module_type):
            break
        name = prefix
    return name


def _doc_markdown(doc, definition):
    summary, parameters, discussion = _doc_sections(
        doc, _parameter_names(definition)
    )

    lines = []
    if parameters:
        lines += ["", "## Parameters", ""]
        for name, description in parameters:
            lines.append("- `" + name + "`: " + description)

    if discussion:
        lines += ["", "## Discussion", ""] + discussion

    return summary, lines


def _overload_sections(overloads, definitions):
    lines = []
    for index in range(len(definitions)):
        entry = overloads[index]
        definition = definitions[index]
        summary, body = _doc_markdown(getattr(entry, '__doc__', None), definition)

        if index:
            lines.append("")

        lines += _signature_card(entry, definition, overload=True)
        if summary:
            lines += ["", summary]
        lines += body

    return lines


def _function_markdown(obj, fallback_name=None, parent_path=None):
    definitions = _callable_definitions(obj, fallback_name)

    lines = []
    if parent_path:
        lines += [_reference_markdown(parent_path), ""]

    overloads = getattr(obj, '_overloads', None)
    if overloads:
        # Each overload starts with its own syntax, so no separate function
        # heading is needed above them.
        return lines + _overload_sections(overloads, definitions)

    summary, body = _doc_markdown(_callable_doc(obj), definitions[0])
    lines += _signature_cards(obj, definitions)
    if summary:
        lines += ["", summary]

    return lines + body


def _reference_markdown(path):
    # The double backticks DocC uses. Whatever link a host makes of it is the
    # host's own, so no scheme belongs here. A `/` in the path marks the part to
    # show on its own.
    return "``" + path + "``"


def _parent_reference_path(path):
    parts = path.split('.')
    if len(parts) < 2:
        return None

    parent = '.'.join(parts[:-1])
    # Keep the module qualification for a class, but display the class itself.
    return parent.rsplit('.', 1)[0] + "/" + parent.rsplit('.', 1)[1] if "." in parent else parent


def _modules_markdown():
    lines = ["| Module | Description |", "| --- | --- |"]
    for name in _available_modules():
        doc = _module_doc(name) or ""
        # A pipe in a summary would end the cell early.
        lines.append("| " + _reference_markdown(name) + " | " + doc.replace("|", "\\|") + " |")
    return lines


def _module_markdown(module):
    name = getattr(module, '__name__', None) or str(module)
    lines = [_reference_markdown("modules"), ""]

    doc = getattr(module, '__doc__', None)
    if doc:
        lines += [doc.strip(), ""]

    classes, functions = _module_members(module)

    if classes:
        lines += ["## Classes", ""] + _class_entries(name, classes)

    if functions:
        lines += ["## Functions", ""] + _function_entries(name, functions)

    return lines


def _class_header(cls):
    # From the bound interface where there is one, so a base shows the name it
    # was bound under rather than the name of the Swift type.
    interface = getattr(cls, '_interface', None)
    if interface:
        return _without_trailing_colon(interface.split("\n")[0])
    return _without_trailing_colon(_class_signature(cls))


def _interface_summary(interface):
    for line in interface.split("\n")[1:]:
        line = line.strip()
        if not line:
            continue
        if not line.startswith('"""'):
            return None

        line = line[3:]
        if line.endswith('"""'):
            line = line[:-3]
        return line.strip() or None
    return None


def _linked_doc_references(text):
    parts = text.split("`")
    for index in range(1, len(parts), 2):
        name = parts[index]
        if "." in name and _is_reference(name):
            parts[index] = _reference_markdown(name)
        else:
            parts[index] = "`" + name + "`"
    return "".join(parts)


def _class_summary(cls):
    # `@Scriptable` writes the class comment to `__doc__`; a class declared by an
    # interface string keeps its documentation inside the stub instead.
    doc = getattr(cls, '__doc__', None)
    if doc:
        summary, _, _ = _doc_sections(doc, [])
        return _linked_doc_references(summary)

    interface = getattr(cls, '_interface', None)
    return _interface_summary(interface) if interface else None


def _listing_entry(owner_path, member_name, declaration, summary=None):
    if owner_path:
        # The slash keeps the heading down to the member's own name.
        heading = _reference_markdown(owner_path + "/" + member_name)
    else:
        heading = member_name

    lines = ["### " + heading, ""] + _fenced(declaration) + [""]
    if summary:
        lines += [summary, ""]
    return lines


def _class_entries(module_name, classes):
    lines = []
    for member_name, cls in classes:
        lines += _listing_entry(
            module_name,
            member_name,
            [_class_header(cls)],
            _class_summary(cls)
        )
    return lines


def _function_entries(owner_path, functions):
    lines = []
    for member_name, function in functions:
        overloads = getattr(function, '_overloads', None)
        entries = overloads if overloads else [function]

        for entry in entries:
            definition = _callable_definition(entry, member_name)
            summary, _, _ = _doc_sections(getattr(entry, '__doc__', None), [])
            signature = _without_trailing_colon(definition)
            declaration = []
            if overloads:
                declaration.append("@overload")
            if getattr(entry, '_is_static', False):
                declaration.append("@staticmethod")
            declaration.append(signature)

            parameters = ", ".join(_parameter_names(definition))
            reference_name = member_name + "(" + parameters + ")"

            lines += _listing_entry(owner_path, reference_name, declaration, summary)

    return lines


def _class_initializers(cls):
    initializer = getattr(cls, '__init__', None)

    if initializer is None or not callable(initializer):
        return []

    return [('__init__', initializer)]


def _class_methods(cls):
    methods = []
    for attr_name in dir(cls):
        if attr_name.startswith('_'):
            continue
        try:
            attr = getattr(cls, attr_name)
        except:
            continue
        if callable(attr):
            methods.append((attr_name, attr))
    methods.sort()
    return methods


def _class_property_names(cls):
    names = []
    for attr_name in dir(cls):
        if attr_name.startswith('_'):
            continue
        try:
            attr = getattr(cls, attr_name)
        except:
            continue
        # `property` isn't a name to compare against here.
        if type(attr).__name__ == 'property':
            names.append(attr_name)

    for attr_name in getattr(cls, '__annotations__', None) or {}:
        if not attr_name.startswith('_') and attr_name not in names:
            names.append(attr_name)

    names.sort()
    return names


def _property_declaration(cls, name):
    annotation = (getattr(cls, '__annotations__', None) or {}).get(name)
    return name + ": " + annotation if annotation else name


def _property_summary(cls, name):
    getter = getattr(getattr(cls, name, None), 'fget', None)
    doc = getattr(getter, '__doc__', None)
    if not doc:
        return None

    summary, _, _ = _doc_sections(doc, [])
    return summary


def _property_is_readonly(cls, name):
    prop = getattr(cls, name, None)
    # An annotation-only name has no property object to ask.
    if type(prop).__name__ != 'property':
        return False
    return getattr(prop, 'fset', None) is None


def _property_entries(cls, names):
    lines = []
    for name in names:
        line = "- `" + _property_declaration(cls, name) + "`"
        if _property_is_readonly(cls, name):
            line += " (read only)"
        summary = _property_summary(cls, name)
        if summary:
            line += ": " + summary
        lines.append(line)
    return lines


def _property_markdown(path):
    parts = path.split('.')
    name = parts[-1]
    cls = _resolve_name('.'.join(parts[:-1]))

    lines = ["# " + name, ""]

    module_name = _owning_module_name(path)
    if module_name:
        lines += [_reference_markdown(module_name), ""]

    summary = _property_summary(cls, name)
    if summary:
        lines += [summary, ""]

    declaration = _property_declaration(cls, name)
    if _property_is_readonly(cls, name):
        declaration += "  # read only"

    return lines + _fenced([declaration])


def _builtin_class_path(cls):
    name = getattr(cls, '__name__', None)
    if not name:
        return None

    try:
        builtin = getattr(__import__('builtins'), name)
    except (ImportError, AttributeError):
        return None
    return name if builtin is cls else None


def _class_markdown(cls, path=None):
    header = _class_header(cls)
    lines = []

    parent_path = _parent_reference_path(path) if path else None
    if parent_path:
        lines += [_reference_markdown(parent_path), ""]

    lines += _fenced([header])
    lines.append("")

    summary = _class_summary(cls)
    if summary:
        lines += [summary, ""]

    properties = _class_property_names(cls)
    if properties:
        lines += ["## Properties", ""] + _property_entries(cls, properties)

    initializers = _class_initializers(cls)
    if initializers:
        lines += ["## Initializers", ""] + _function_entries(path, initializers)

    methods = _class_methods(cls)
    if methods:
        lines += ["## Functions", ""] + _function_entries(path, methods)

    return lines


def _markdown_lines(obj):
    if obj is None:
        # A host's README is already markdown, so it is passed through as it is.
        return [_document('README') or _help_text or _default_help_text()]

    module_type = type(__import__('sys'))

    if isinstance(obj, str):
        document = _document(obj)
        if document is not None:
            return [document]
        if obj == "modules":
            return _modules_markdown()

        try:
            resolved = _resolve_name(obj)
        except (ImportError, AttributeError):
            return ["No help found for `" + obj + "`"]
        if isinstance(resolved, module_type):
            return _module_markdown(resolved)
        if isinstance(resolved, type):
            return _class_markdown(resolved, path=obj)
        if callable(resolved):
            return _function_markdown(
                resolved,
                fallback_name=obj.split('.')[-1],
                parent_path=_parent_reference_path(obj)
            )
        # A property documents itself; the class it is reached through is what
        # declares it.
        if type(resolved).__name__ == 'property' and "." in obj:
            return _property_markdown(obj)
        # An instance is documented by the class it is of.
        return _class_markdown(type(resolved))

    if isinstance(obj, module_type):
        return _module_markdown(obj)
    if isinstance(obj, type):
        return _class_markdown(obj, path=_builtin_class_path(obj))
    if callable(obj):
        return _function_markdown(obj)
    return _class_markdown(type(obj))


def help(obj=None):
    """Show help for a module, class, function, or instance.

    Returns a markdown view where the console can render one, and falls back to
    printing plain text on hosts without it."""
    try:
        from views import Markdown
    except:
        print("\n".join(_help_lines(obj)))
        return

    return Markdown("\n".join(_markdown_lines(obj)))
