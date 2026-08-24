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


def _callable_definitions(obj, fallback_name=None):
    """Concrete definitions for a callable, expanding an overload dispatcher."""
    overloads = getattr(obj, '_overloads', None)
    if not overloads:
        return [_callable_definition(obj, fallback_name)]
    return [_callable_definition(overload, fallback_name) for overload in overloads]


def _callable_doc(obj):
    """A dispatcher's documentation, falling back to its concrete overloads."""
    doc = getattr(obj, '__doc__', None)
    if doc:
        return doc
    for overload in getattr(obj, '_overloads', None) or []:
        doc = getattr(overload, '__doc__', None)
        if doc:
            return doc
    return None


def _overload_signature_lines(definitions):
    """Signatures for a Python fence, decorated when more than one is valid."""
    signatures = [_without_trailing_colon(definition) for definition in definitions]
    if len(signatures) == 1:
        return signatures

    lines = []
    for signature in signatures:
        lines += ["@overload", signature]
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


def _resolve_name(name):
    """Resolve a module name or a dotted member path from its root module."""
    parts = name.split('.')
    obj = __import__(parts[0])
    for part in parts[1:]:
        obj = getattr(obj, part)
    return obj


def _is_reference(name):
    """Whether a dotted path resolves from its root module.

    A host holding a reference asks this to choose between handing ``help`` the
    path, which is what names the module a function came from, and handing it
    an object bound in the session, which no module owns.
    """
    try:
        _resolve_name(name)
        return True
    except (ImportError, AttributeError):
        return False


def _module_members(module):
    """The module's public classes and functions, each as (name, object)."""
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

# What a reference link starts with, up to the name itself. Hosts that render
# markdown and take reference links set this; without it names stay plain code.
_reference_url_prefix = None


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


def _definition_name(definition):
    """The name in a ``def name(...):`` line."""
    start = definition.find("def ")
    start = 0 if start == -1 else start + len("def ")
    end = definition.find("(", start)
    if end == -1:
        return _without_trailing_colon(definition[start:])
    return definition[start:end].strip()


def _split_top_level(text):
    """``text`` split on the commas that aren't inside brackets."""
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
    """What a ``def name(...):`` line declares between its brackets, or
    ``None``."""
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
    """Whether a definition takes ``self``.

    Nothing at runtime tells a bound static method from an instance one; the
    signature is what says so, as it does in Python.
    """
    text = _parameter_text(definition)
    if not text:
        return False

    return _split_top_level(text)[0].strip() == "self"


def _parameter_names(definition):
    """The parameters a ``def name(...):`` line declares."""
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
    """A docstring's lines, with the indentation its body was written at
    removed. The first line follows the quotes, so it carries none."""
    lines = doc.split("\n")
    body = lines[1:]

    indents = []
    for line in body:
        if line.strip():
            indents.append(len(line) - len(line.lstrip()))
    indent = min(indents) if indents else 0

    return [lines[0].strip()] + [line[indent:] for line in body]


def _parameter_description(line, parameter_names):
    """A ``name: description`` line for one of the declared parameters, or
    ``None``. Matching the name is what keeps prose holding a colon out."""
    cut = line.find(":")
    if cut <= 0:
        return None

    name = line[:cut].strip()
    if name not in parameter_names:
        return None

    return (name, line[cut + 1:].strip())


def _doc_sections(doc, parameter_names):
    """A docstring as its summary, its documented parameters, and the rest."""
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
    """pocketpy has no ``str.rstrip``, so the stub's colon comes off by hand."""
    text = text.strip()
    return text[:-1].strip() if text.endswith(":") else text


def _return_annotation(definition):
    """The type a ``def name(...) -> type:`` line returns, or ``None``."""
    parts = definition.split("->")
    if len(parts) == 1:
        return None
    return _without_trailing_colon(parts[-1])


def _owning_module_name(path):
    """The module a dotted path lives in, or ``None``.

    A function carries no module of its own, so the path it was looked up by is
    what says where it came from. The longest prefix that is still a module owns
    it, which keeps a method under its module rather than its class."""
    parts = path.split('.')
    module_type = type(__import__('math'))

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


def _function_markdown(obj, fallback_name=None, module_name=None):
    """A function's help laid out as reference documentation."""
    definitions = _callable_definitions(obj, fallback_name)
    definition = definitions[0]
    parameter_names = []
    for item in definitions:
        for name in _parameter_names(item):
            if name not in parameter_names:
                parameter_names.append(name)
    summary, parameters, discussion = _doc_sections(
        _callable_doc(obj), parameter_names
    )

    lines = ["# " + _definition_name(definition), ""]

    if module_name:
        lines += [_reference_markdown(module_name), ""]

    if summary:
        lines += [summary, ""]

    lines += _fenced(_overload_signature_lines(definitions))

    if parameters:
        lines += ["", "## Parameters", ""]
        for name, description in parameters:
            lines.append("- `" + name + "`: " + description)

    if discussion:
        lines += ["", "## Discussion", ""] + discussion

    return lines


def _reference_markdown(name, text=None, code=True):
    """A name as markdown, linked where the host takes references.

    The scheme belongs to the host, so it sets ``_reference_url_prefix`` (as it
    sets ``_help_text``) and the name is appended to it. Module and member
    names are identifiers, so nothing in them needs escaping.

    text: Shown in place of the name.
    code: Whether the text is code, which a heading doesn't want.
    """
    label = text or name
    if code:
        label = "`" + label + "`"

    if not _reference_url_prefix:
        return label
    return "[" + label + "](" + _reference_url_prefix + name + ")"


def _modules_markdown():
    lines = ["# Registered modules", "", "| Module | Description |", "| --- | --- |"]
    for name in _registered_modules():
        doc = _module_doc(name) or ""
        # A pipe in a summary would end the cell early.
        lines.append("| " + _reference_markdown(name) + " | " + doc.replace("|", "\\|") + " |")
    return lines


def _module_markdown(module):
    name = getattr(module, '__name__', None) or str(module)
    lines = ["# " + name, ""]

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
    """The `class Type(Base)` line.

    Taken from the bound interface where there is one, so that a base shows the
    name it was bound under rather than the name of the Swift type."""
    interface = getattr(cls, '_interface', None)
    if interface:
        return _without_trailing_colon(interface.split("\n")[0])
    return _without_trailing_colon(_class_signature(cls))


def _interface_summary(interface):
    """The first line of the docstring an interface stub opens with."""
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


def _class_summary(cls):
    """What a class is for, in one line.

    ``@Scriptable`` writes the class comment to ``__doc__``; a class declared by
    an interface string keeps its documentation inside the stub instead."""
    doc = getattr(cls, '__doc__', None)
    if doc:
        summary, _, _ = _doc_sections(doc, [])
        return summary

    interface = getattr(cls, '_interface', None)
    return _interface_summary(interface) if interface else None


def _class_entries(module_name, classes):
    """One entry per class: its name, linked to its own help, over what it
    declares and what it is for. The listing reads as ``_function_entries``
    does."""
    lines = []
    for member_name, cls in classes:
        lines.append("#### " + _reference_markdown(
            module_name + "." + member_name,
            text=member_name,
            code=False
        ))
        lines.append("")
        lines += _fenced([_class_header(cls)])
        lines.append("")

        summary = _class_summary(cls)
        if summary:
            lines += [summary, ""]

    return lines


def _function_entries(owner_path, functions, of_class=False):
    """One entry per function: its name, linked to its own help, over the
    signature and what it does.

    The signature sits in a code block rather than in the link, because a link
    long enough to wrap loses its frame and spills over the line.

    owner_path: The dotted path the functions are reached by, or ``None`` where
        there is none to link to.
    of_class: Whether these are members, whose signature says whether they are
        static.
    """
    lines = []
    for member_name, function in functions:
        definitions = _callable_definitions(function, member_name)
        summary, _, _ = _doc_sections(_callable_doc(function), [])

        if owner_path:
            heading = _reference_markdown(
                owner_path + "." + member_name,
                text=member_name,
                code=False
            )
        else:
            heading = member_name

        lines.append("### " + heading)
        lines.append("")
        lines += _fenced(_overload_signature_lines(definitions))
        lines.append("")

        if summary:
            lines += [summary, ""]

    return lines


def _class_initializers(cls):
    """The class's initializer, as (name, object), where it binds one.

    A class that declares none has no `__init__` to find, so the section stays
    out rather than showing an empty one."""
    initializer = getattr(cls, '__init__', None)

    if initializer is None or not callable(initializer):
        return []

    return [('__init__', initializer)]


def _class_methods(cls):
    """The class's public methods, each as (name, object)."""
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


def _class_markdown(cls, path=None):
    """A class's help, laid out as a module's is: what it is, then what it
    offers.

    Properties are left out for now; a bound property is not callable, so it
    carries neither a signature nor documentation of its own.
    """
    header = _class_header(cls)
    lines = ["# " + (getattr(cls, '__name__', None) or header), ""]

    module_name = _owning_module_name(path) if path else None
    if module_name:
        lines += [_reference_markdown(module_name), ""]

    lines += _fenced([header])
    lines.append("")

    summary = _class_summary(cls)
    if summary:
        lines += [summary, ""]

    initializers = _class_initializers(cls)
    if initializers:
        lines += ["## Initializers", ""] + _function_entries(path, initializers)

    methods = _class_methods(cls)
    if methods:
        lines += ["## Functions", ""] + _function_entries(path, methods)

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
                module_name=_owning_module_name(obj)
            )
        # An instance is documented by the class it is of.
        return _class_markdown(type(resolved))

    if isinstance(obj, module_type):
        return _module_markdown(obj)
    if isinstance(obj, type):
        return _class_markdown(obj)
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
