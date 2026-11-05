__doc__ = "Utilities for interacting with the PyPrompt interpreter."
__all__ = ["display", "ainput", "InputResult", "stoppable", "source", "enable_trace", "disable_trace"]

from rlcompleter import Completer as _Completer
from interpreter.native import display, ainput, source, enable_trace, disable_trace

try:
    from _swiftpy_asyncio import stoppable
    stoppable.__module__ = __name__
except ImportError:
    # pocketpy runs no threads, and its stop reaches every call.
    def stoppable(function):
        """Makes a blocking call stoppable."""
        return function


class InputResult(str):
    """What the user answered `input` or ``interpreter.ainput`` with: the text,
    as a str, with the images they attached.

    Attributes:
        images: The attached images, as ``views.Image``; empty unless asked for with `images=True`.
    """

    images: list

    def __new__(cls, text: str = "", images: list | None = None):
        result = super().__new__(cls, text)
        result.images = list(images or [])
        return result


def _input_result(text: str, data: list[bytes]) -> InputResult:
    # Called from Swift with the answer; only a host with views attaches images.
    images = []
    if data:
        from views import Image
        images = [Image(item) for item in data]
    return InputResult(text, images)


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


_is_sampling_lines = False

def _start_line_sampler():
    global _is_sampling_lines
    if _is_sampling_lines:
        return
    _is_sampling_lines = True
    import _thread
    # Not a threading.Thread, which a script would see in threading.enumerate().
    _thread.start_new_thread(_sample_lines, (_thread.get_ident,))

def _sample_lines(get_ident, interval=0.25):
    """Report the innermost script line of whatever is running, until no run is
    left to report to. A library's frames are skipped for the line calling it."""
    global _is_sampling_lines
    import sys, time
    from interpreter.native import _line_sampling, _line_sampled
    me = get_ident()
    try:
        while _line_sampling():
            time.sleep(interval)
            for ident, frame in sys._current_frames().items():
                while ident != me and frame is not None:
                    source = frame.f_code.co_filename
                    if source.startswith('<script'):
                        _line_sampled(source, frame.f_lineno)
                        break
                    frame = frame.f_back
    finally:
        _is_sampling_lines = False

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
