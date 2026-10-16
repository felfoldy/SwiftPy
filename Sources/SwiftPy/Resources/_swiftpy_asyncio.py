"""The stdlib asyncio on the host's main loop.

Nothing here runs a loop: scheduling goes through Swift (``_swiftpy_loop``),
which runs each callback on the main actor between everything else the app
does. The loop is therefore always "running", the way it is in a notebook.
"""

import builtins
import functools
import itertools
import sys
import threading
import time
import traceback
import warnings

with warnings.catch_warnings():
    # selectors warns where it cannot register an at-fork handler, and the
    # iOS interpreter has no fork at all.
    warnings.simplefilter("ignore", RuntimeWarning)
    import asyncio
from asyncio import events

import _swiftpy_loop as _native

__all__ = ["SwiftEventLoop", "loop", "stoppable"]


class SwiftEventLoop(asyncio.AbstractEventLoop):
    """Scheduling primitives backed by Swift; everything else is the stdlib's."""

    def __init__(self):
        self._debug = False
        self._exception_handler = None
        self._task_factory = None

    # Scheduling

    def call_soon(self, callback, *args, context=None):
        handle = events.Handle(callback, args, self, context)
        _native.schedule(handle._run, 0.0)
        return handle

    call_soon_threadsafe = call_soon

    def call_later(self, delay, callback, *args, context=None):
        return self.call_at(self.time() + delay, callback, *args, context=context)

    def call_at(self, when, callback, *args, context=None):
        handle = events.TimerHandle(when, callback, args, self, context)

        def run():
            # A cancelled timer is simply skipped, as the stdlib loop does.
            if not handle.cancelled():
                handle._run()

        _native.schedule(run, max(0.0, when - self.time()))
        return handle

    def _timer_handle_cancelled(self, handle):
        pass

    def time(self):
        return time.monotonic()

    # Futures and tasks

    def create_future(self):
        return asyncio.Future(loop=self)

    def create_task(self, coro, **kwargs):
        if self._task_factory is None:
            return asyncio.Task(coro, loop=self, **kwargs)
        return self._task_factory(self, coro, **kwargs)

    def set_task_factory(self, factory):
        self._task_factory = factory

    def get_task_factory(self):
        return self._task_factory

    # Lifecycle: the loop lives as long as the interpreter.

    def is_running(self):
        return True

    def is_closed(self):
        return False

    def close(self):
        pass

    def stop(self):
        pass

    def run_forever(self):
        raise RuntimeError("the event loop is already running; use await instead")

    def run_until_complete(self, future):
        raise RuntimeError("the event loop is already running; use await instead")

    def run_in_executor(self, executor, func, *args):
        raise NotImplementedError("run_in_executor: Python has no thread pool here")

    async def shutdown_asyncgens(self):
        pass

    async def shutdown_default_executor(self, timeout=None):
        pass

    # Debugging and errors

    def get_debug(self):
        return self._debug

    def set_debug(self, enabled):
        self._debug = enabled

    def set_exception_handler(self, handler):
        self._exception_handler = handler

    def get_exception_handler(self):
        return self._exception_handler

    def default_exception_handler(self, context):
        message = context.get("message") or "Unhandled exception in event loop"
        print(message, file=sys.stderr)
        exception = context.get("exception")
        if exception is not None:
            traceback.print_exception(exception, file=sys.stderr)

    def call_exception_handler(self, context):
        if self._exception_handler is None:
            self.default_exception_handler(context)
            return
        try:
            self._exception_handler(self, context)
        except Exception as error:
            self.default_exception_handler({
                "message": "Unhandled error in exception handler",
                "exception": error,
                "context": context,
            })


def watch(future, token):
    """Hands the future back to Swift once it settles."""
    future.add_done_callback(lambda done: _native.resolve(token, done))


def fail(future, type_name, message):
    """Settles a future with an exception Swift only has by name."""
    if future.done():
        return
    if type_name == "CancelledError":
        future.cancel()
        return
    exception_type = getattr(builtins, type_name, None)
    if not isinstance(exception_type, type) or not issubclass(exception_type, BaseException):
        exception_type = RuntimeError
    future.set_exception(exception_type(message))


def _install_on_this_thread():
    """The running loop is kept per thread; this one runs on every thread
    Python runs on, so each of them is told."""
    global _cell_thread
    _cell_thread = threading.get_ident()
    events._set_running_loop(loop)


_cell_thread = None
_tokens = itertools.count()


def stoppable(function):
    """Makes a blocking call stoppable: on the cell's thread, it runs on a
    worker thread while the cell waits, so a stop ends the wait at once. The
    call itself carries on until it returns, and its result is dropped.

    For calls that block in C, such as I/O, which a stop otherwise can't
    reach until they return. The call must be safe to make from another
    thread and to finish after a stop.

    ```python
    from interpreter import stoppable

    @stoppable
    def receive(sock):
        return sock.recv(4096)
    ```
    """
    @functools.wraps(function)
    def call(*args, **kwargs):
        # Only the cell's thread waits in Swift; main can't wait at all.
        if threading.get_ident() != _cell_thread:
            return function(*args, **kwargs)
        token = next(_tokens)
        outcome = []

        def work():
            try:
                outcome.append((True, function(*args, **kwargs)))
            except BaseException as error:
                outcome.append((False, error))
            finally:
                _native.finish(token)

        threading.Thread(target=work, name=getattr(function, "__name__", "stoppable"), daemon=True).start()
        _native.wait(token)
        succeeded, value = outcome[0]
        if succeeded:
            return value
        raise value

    return call


def _run(main, **kwargs):
    raise RuntimeError(
        "asyncio.run() is not needed here: the event loop is already running, "
        "so `await main()` runs the coroutine"
    )


loop = SwiftEventLoop()
events._set_running_loop(loop)
asyncio.run = _run
# A C sleep can't be interrupted; this one ends at a stop.
time.sleep = stoppable(time.sleep)
asyncio.AsyncTask = _native.AsyncTask
