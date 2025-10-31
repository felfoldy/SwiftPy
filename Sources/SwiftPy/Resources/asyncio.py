def coroutine(func):
    def coroutine(*args,**kwargs):
        cr = func(*args,**kwargs)
        return AsyncTask(cr)
    return coroutine

@coroutine
def sleep(delay: float) -> None:
    context = AsyncSleep(delay)
    yield from context()
