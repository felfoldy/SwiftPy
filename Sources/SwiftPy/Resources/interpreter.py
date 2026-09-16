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
