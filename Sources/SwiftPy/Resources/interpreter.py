from rlcompleter import Completer

def completions(text: str) -> list[str]:
    completer = Completer()

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

def bind_interfaces(module):
    interfaces = []

    for name, value in module.__dict__.items():
        if hasattr(value, '_interface'):
            interfaces.append(value._interface)
    
    module.__doc__ = "\n\n\n".join(interfaces)


def dir(obj) -> list[str]:
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
