def _Task__iter__(self):
    return self
    
def _Task__next__(self):
    if self.is_done:
        raise StopIteration(self.result)

AsyncTask.__iter__ = _Task__iter__
AsyncTask.__next__ = _Task__next__

def task_from(generator) -> AsyncTask:
    task = AsyncTask()
    task.generator = generator
    return task
