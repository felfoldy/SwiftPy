/// Starts the task and keeps it alive until its work finishes. ``AsyncTask``
/// cancels itself when it is released, so a task nothing holds a reference to
/// would stop the moment Python collects it.
@MainActor
private func detach(_ task: AsyncTask) {
    task.resume()
    Task { [task] in _ = await task.task?.value }
}

extension Interpreter {
    func bindAsyncio() {
        bindModule("asyncio", docs: """
        Run asynchronous Python code without blocking the console.

        Define a coroutine with ``async def`` and use `await` to suspend it
        while other work runs. The module provides delays, concurrent execution,
        access to the current task, cancellation, and progress reporting.

        ```python
        import asyncio

        async def fetch(name, delay):
            await asyncio.sleep(delay)
            return f"{name} finished"

        results = await asyncio.gather(fetch("first", 0.2), fetch("second", 0.1))
        print(results)
        ```
        """) { asyncio in
            asyncio.class(AsyncTask.self)

            asyncio.asyncDef(
                "sleep(seconds: float) -> None",
                docstring: """
                Suspend the current coroutine for a number of seconds.

                seconds: The delay in seconds. Fractional values are supported.

                ```python
                import asyncio

                print("waiting")
                await asyncio.sleep(0.5)
                print("done")
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (seconds: Double) -> AsyncTask in
                    AsyncTask { try await Task.sleep(for: .seconds(seconds)) }
                }
            }

            // Both need what CPython's bindings still lack: `*args`, which
            // arrives unpacked rather than as one tuple, and turning a native
            // coroutine into a task.
            #if !cpython
            asyncio.asyncDef(
                "gather(*tasks) -> list",
                docstring: """
                Run multiple awaitables concurrently and wait for all of them.

                tasks: Coroutines or ``asyncio.AsyncTask`` objects to run.

                Returns a list of results in argument order, regardless of the
                order in which they finish. If a task raises, `gather` raises
                that error.

                ```python
                import asyncio

                async def delayed(value, seconds):
                    await asyncio.sleep(seconds)
                    return value

                values = await asyncio.gather(
                    delayed("slow", 0.2),
                    delayed("fast", 0.1),
                )
                print(values)  # ['slow', 'fast']
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (tuple: PyTuple) in
                    let tasks = try tuple.values.map(AsyncTask.init)
                    for task in tasks { task.resume() }
                    var result = [PyObject?]()
                    for task in tasks {
                        let value = try await task.untilCompletes()
                        result.append(value)
                    }
                    return result
                }
            }

            asyncio.def(
                "create_task(awaitable) -> asyncio.AsyncTask",
                docstring: """
                Start an awaitable in the background and return its task.

                awaitable: A coroutine or ``asyncio.AsyncTask``.

                Use this for work nothing waits for. Nothing propagates the
                task's error either, so the coroutine has to handle its own
                failures. Await the returned task to join the work instead.

                ```python
                import asyncio

                async def work():
                    await asyncio.sleep(1)
                    print("finished")

                asyncio.create_task(work())
                print("started")
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { (task: AsyncTask) -> AsyncTask in
                    detach(task)
                    return task
                }
            }
            #endif

            asyncio.def(
                "current_task() -> asyncio.AsyncTask | None",
                docstring: """
                Return the ``asyncio.AsyncTask`` currently running this coroutine.

                Returns `None` outside asynchronous task execution. Use the task
                to report progress, cancel work, or inspect its state.

                ```python
                import asyncio

                async def work():
                    task = asyncio.current_task()
                    for step in range(4):
                        task.set_progress(step / 3)
                        await asyncio.sleep(1)

                await work()
                ```
                """
            ) { argc, argv in
                PyBind.function(argc, argv) { () -> (any PythonConvertible) in AsyncTask.current }
            }
        }
    }
}
