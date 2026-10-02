__doc__ = "Utilities for interacting with the PyPrompt interpreter."
__all__ = ["display", "source", "set_timeout", "enable_trace", "disable_trace"]

from rlcompleter import Completer as _Completer
from interpreter.native import host, display, source, set_timeout, enable_trace, disable_trace


def _completions(text: str) -> list[str]:
    completer = _Completer()

    completion_list = []
    state = 0
    
    # Get completions until no more are found
    while True:
        completion = completer.complete(text, state)
        if completion is None:
            break
        completion_list.append(completion)
        state += 1
    
    return completion_list


def _check(source: str, prelude: str, cache: str, typeshed: str) -> str:
    # Called from Swift: mypy's diagnostics for `source`, read after `prelude`,
    # as JSON in source's own lines; "[]" where mypy isn't shipped.
    try:
        from mypy import api
    except ImportError:
        return "[]"

    import contextlib, io, warnings

    offset = prelude.count("\n") + 1 if prelude else 0
    # Quiet: a check runs between cards, so anything it printed would land
    # in the notebook (platform warns that ctypes is missing, for one).
    with warnings.catch_warnings(), contextlib.redirect_stderr(io.StringIO()):
        warnings.simplefilter("ignore")
        out, _, _ = _run_mypy(api, prelude, source, cache, typeshed)
    return _diagnostics(out, offset)


def _run_mypy(api, prelude: str, source: str, cache: str, typeshed: str):
    return api.run([
        "-c", f"{prelude}\n{source}" if prelude else source,
        "--output", "json",
        "--cache-dir", cache,
        # Not beside mypy, which is zipped.
        "--custom-typeshed-dir", typeshed,
        # The Rust parser isn't shipped.
        "--no-native-parser",
        # Cards reuse names, await at the top and import Swift modules.
        "--allow-redefinition",
        "--disable-error-code", "top-level-await",
        "--ignore-missing-imports",
    ])


def _diagnostics(out: str, offset: int) -> str:
    import json
    items = []
    for line in out.splitlines():
        try:
            found = json.loads(line)
        except ValueError:
            continue
        if found["line"] <= offset:
            continue
        message = found["message"]
        if found.get("hint"):
            message += "\n" + found["hint"]
        items.append({
            "line": found["line"] - offset,
            "column": found["column"] + 1,
            "end_line": found["end_line"] - offset,
            "end_column": found["end_column"] + 1,
            "severity": found["severity"] if found["severity"] in ("error", "note") else "warning",
            "message": message,
            "code": found.get("code"),
        })
    return json.dumps(items)


def _stubs() -> str:
    # Called from Swift: the registered modules as a type checker's files, JSON.
    import json
    from interpreter.help import _stubs
    return json.dumps(_stubs())


def _user_files():
    # The .py files an import can reach: the working directory's, and installed
    # ones as "site-packages/...". Bounded, since Documents can hold anything.
    import os
    roots = [(os.getcwd(), "")]
    try:
        from _swiftpy_paths import site_packages
        roots.append((site_packages(), "site-packages/"))
    except ImportError:
        pass
    found = 0
    stack = [(root, prefix, 0) for root, prefix in roots]
    while stack and found < 300:
        directory, prefix, depth = stack.pop()
        try:
            entries = list(os.scandir(directory))
        except OSError:
            continue
        for entry in entries:
            if entry.name.startswith(".") or entry.name == "__pycache__":
                continue
            try:
                if entry.is_dir() and depth < 4:
                    stack.append((entry.path, prefix + entry.name + "/", depth + 1))
                elif entry.name.endswith(".py") and entry.is_file():
                    info = entry.stat()
                    if info.st_size <= 200_000:
                        found += 1
                        yield prefix + entry.name, entry.path, info
            except OSError:
                continue


def _user_sources() -> str:
    # Called from Swift: `{path: text}` of `_user_files`, JSON.
    import json
    sources = {}
    for path, full, _ in _user_files():
        try:
            with open(full, encoding="utf-8") as file:
                sources[path] = file.read()
        except (OSError, UnicodeDecodeError):
            continue
    return json.dumps(sources)


def _user_sources_stamp() -> str:
    # Called from Swift: changes when a file of `_user_sources` does, or the
    # working directory, without reading any of them.
    import os
    files = sorted((path, info.st_mtime_ns, info.st_size) for path, _, info in _user_files())
    return repr((os.getcwd(), files))


def _json_markdown(value) -> str:
    # Called from Swift for the display of a dict or list; Swift has no way
    # to pass CPython's keyword-only indent.
    import json
    return json.dumps(value, indent=2)


import builtins as _builtins

# pocketpy's builtin dir is incomplete; the module only exists on that backend.
try:
    from _pocketpy import dir as _dir
    _builtins.dir = _dir
except ImportError:
    pass

from interpreter.help import help as _help


def _builtin_help(*args):
    if len(args) == 0:
        return _help(None)
    return _help(args[0])


_builtins.help = _builtin_help
