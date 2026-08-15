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


def _module_summary(name):
    try:
        doc = getattr(__import__(name), '__doc__', None)
        if doc:
            return name + " - " + doc.strip().split("\n")[0]
    except:
        pass
    return name


def _modules_lines():
    lines = ["Registered modules:", ""]
    for name in _registered_modules():
        lines.append("  " + _module_summary(name))
    return lines


def _module_lines(module):
    name = getattr(module, '__name__', None) or str(module)
    lines = ["Help on module " + name + ":", ""]

    doc = getattr(module, '__doc__', None)
    if doc:
        lines.append(doc)
        lines.append("")

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


def help(obj=None):
    print("\n".join(_help_lines(obj)))
