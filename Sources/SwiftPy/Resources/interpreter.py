__doc__ = "Utilities for interacting with the PyPrompt interpreter."

from rlcompleter import Completer as _Completer
from interpreter.native import host, display, set_timeout, enable_trace, disable_trace


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


def _dir(obj) -> list[str]:
    if hasattr(obj, '__dir__') and not isinstance(obj, type):
        return obj.__dir__()

    tp_module = type(__import__('math'))
    if isinstance(obj, tp_module):
        return [k for k, _ in obj.__dict__.items()]
    names = set()
    if not isinstance(obj, type):
        obj_d = obj.__dict__
        if obj_d is not None:
            names.update([k for k, _ in obj_d.items()])
        cls = type(obj)
    else:
        cls = obj
    while cls is not None:
        names.update([k for k, _ in cls.__dict__.items()])
        cls = cls.__base__
    return sorted(list(names))


import builtins as _builtins
_builtins.dir = _dir

from help import help as _help


def _builtin_help(*args):
    if len(args) == 0:
        return _help(None)
    return _help(args[0])


_builtins.help = _builtin_help
