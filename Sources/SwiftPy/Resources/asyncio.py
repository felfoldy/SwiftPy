def coroutine(func):
    def coroutine(*args,**kwargs):
        cr = func(*args,**kwargs)
        return AsyncTask(cr)
    return coroutine
