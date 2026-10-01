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
