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
        return name + "(...)"


def _callable_definition(obj, fallback_name=None):
    signature = _callable_signature(obj, fallback_name)
    prefix = "async " if getattr(obj, '_is_async', False) else ""
    if signature.startswith("def "):
        signature = signature[len("def "):]
    if not signature.endswith(":"):
        signature = signature + ":"
    return prefix + "def " + signature


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


def _module_doc(name):
    try:
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
    for name in _registered_modules():
        lines.append("  " + _module_summary(name))
    return lines


def _module_members(module):
    """The module's public classes and functions, each as (name, object)."""
    classes = []
    functions = []
    for attr_name in dir(module):
        if attr_name.startswith('_'):
            continue
        try:
            attr = getattr(module, attr_name)
        except:
            continue
        if isinstance(attr, type):
            classes.append((attr_name, attr))
        elif callable(attr):
            functions.append((attr_name, attr))
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

Useful functions:
  help('modules')   List available modules
  help('<module>')  Show help for a module
""".strip()


def _help_lines(obj):
    if obj is None:
        return [_help_text or _default_help_text()]

    module_type = type(__import__('math'))

    if isinstance(obj, str):
        if obj == "modules":
            return _modules_lines()

        try:
            return _module_lines(__import__(obj))
        except ImportError:
            return ["No help found for " + repr(obj)]

    if isinstance(obj, module_type):
        return _module_lines(obj)
    if isinstance(obj, type):
        return _class_lines(obj)
    if callable(obj):
        return _callable_lines(obj)
    return _class_lines(type(obj))


def _fenced(lines):
    """Python source as a markdown code block."""
    return ["```python"] + lines + ["```"]


def _fenced_stubs(stubs):
    """Several stubs in one code block, a blank line apart, so a section reads
    as one listing instead of a stack of separate blocks."""
    body = []
    for stub in stubs:
        if body:
            body.append("")
        body += stub
    return _fenced(body)


def _modules_markdown():
    lines = ["# Registered modules", "", "| Module | Description |", "| --- | --- |"]
    for name in _registered_modules():
        doc = _module_doc(name) or ""
        # A pipe in a summary would end the cell early.
        lines.append("| `" + name + "` | " + doc.replace("|", "\\|") + " |")
    return lines


def _module_markdown(module):
    name = getattr(module, '__name__', None) or str(module)
    lines = ["# " + name, ""]

    doc = getattr(module, '__doc__', None)
    if doc:
        lines += [doc.strip(), ""]

    classes, functions = _module_members(module)

    if classes:
        stubs = []
        for _, cls in classes:
            stubs.append(_class_lines(cls))
        lines += ["## Classes", ""] + _fenced_stubs(stubs) + [""]

    if functions:
        stubs = []
        for member_name, function in functions:
            stubs.append(_callable_lines(function, fallback_name=member_name))
        lines += ["## Functions", ""] + _fenced_stubs(stubs) + [""]

    return lines


def _markdown_lines(obj):
    if obj is None:
        # The help text is the host's to write, markdown included, so it is
        # passed through as it is.
        return [_help_text or _default_help_text()]

    module_type = type(__import__('math'))

    if isinstance(obj, str):
        if obj == "modules":
            return _modules_markdown()

        try:
            return _module_markdown(__import__(obj))
        except ImportError:
            return ["No help found for `" + obj + "`"]

    if isinstance(obj, module_type):
        return _module_markdown(obj)
    if isinstance(obj, type):
        return _fenced(_class_lines(obj))
    if callable(obj):
        return _fenced(_callable_lines(obj))
    return _fenced(_class_lines(type(obj)))


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
