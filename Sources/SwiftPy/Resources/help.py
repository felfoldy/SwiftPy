import inspect
from interpreter.native import app_version, pocketpy_version, modules as _registered_modules


def _print_doc(doc, indent="    "):
    for line in doc.strip().split("\n"):
        print(indent + line)


def _section(title):
    print("## " + title)


def _callable_signature(obj, fallback_name=None):
    interface = getattr(obj, '_interface', None)
    if interface:
        return interface

    name = fallback_name or getattr(obj, '__name__', None) or repr(obj)
    try:
        return name + str(inspect.signature(obj))
    except:
        return name + "(...)"


def _callable(obj, fallback_name=None):
    print(_callable_signature(obj, fallback_name))

    doc = getattr(obj, '__doc__', None)
    if doc:
        _print_doc(doc)


def _class_signature(cls):
    base = cls.__base__
    if base is not None and base.__name__ != 'object':
        return "class " + cls.__name__ + "(" + base.__name__ + "):"
    return "class " + cls.__name__ + ":"


def _class(cls):
    print(_class_signature(cls))

    doc = getattr(cls, '__doc__', None)
    if doc:
        print()
        _print_doc(doc)

    methods = []
    for attr_name in dir(cls):
        if attr_name.startswith('_'):
            continue
        try:
            attr = getattr(cls, attr_name)
            if callable(attr):
                methods.append((attr_name, attr))
        except:
            pass

    for attr_name, attr in methods:
        print()
        print("    " + _callable_signature(attr, attr_name))
        doc = getattr(attr, '__doc__', None)
        if doc:
            first_line = doc.strip().split("\n")[0]
            print("        " + first_line)


def _module_summary(name):
    try:
        doc = getattr(__import__(name), '__doc__', None)
        if doc:
            return name + " - " + doc.strip().split("\n")[0]
    except:
        pass
    return name


def _modules():
    print("Registered modules:")
    print()
    for name in _registered_modules():
        print("  " + _module_summary(name))


def _module(module):
    name = getattr(module, '__name__', None) or str(module)
    print("Help on module " + name + ":")
    print()

    doc = getattr(module, '__doc__', None)
    if doc:
        print(doc)
        print()

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
        _section("Classes")
        for _, cls in classes:
            print()
            _class(cls)
        print()

    if functions:
        _section("Functions")
        for name, function in functions:
            print()
            _callable(function, fallback_name=name)


def help(obj=None):
    if obj is None:
        lines = [
            "Welcome to PyPrompt!",
            "",
            "PyPrompt is a lightweight Python interpreter powered by pocketpy.",
            "",
            "Enter Python code in the input field and tap the Python button to run it.",
            "",
            "Examples:",
            "  print(\"Hello, world!\")",
            "  2 + 2",
            "  [x * x for x in range(10)]",
            "",
            "Help topics:",
            "  help(module)        Show module classes and functions",
            "  help(type)          Show class details and methods",
            "  help(function)      Show a callable signature and documentation",
            "  help('module')      Import a module by name and show help",
            "  help('modules')     List registered module names",
            "",
            "PyPrompt " + app_version,
            "pocketpy " + pocketpy_version,
        ]
        print("\n".join(lines))
        return

    module_type = type(__import__('math'))

    if isinstance(obj, str):
        if obj == "modules":
            _modules()
            return

        try:
            module = __import__(obj)
            _module(module)
        except ImportError:
            print("No help found for " + repr(obj))
        return

    if isinstance(obj, module_type):
        _module(obj)
    elif isinstance(obj, type):
        _class(obj)
    elif callable(obj):
        _callable(obj)
    else:
        _class(type(obj))
