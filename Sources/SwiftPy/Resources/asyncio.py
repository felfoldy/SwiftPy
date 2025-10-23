class AsyncIterator:
    def __init__(self, task: AsyncTask):
        self.task = task

    def __next__(self):
        if self.task.is_done:
            raise StopIteration(self.task.result)


def __AsyncTask_iter(self):
    return AsyncIterator(self)

AsyncTask.__iter__ = __AsyncTask_iter
