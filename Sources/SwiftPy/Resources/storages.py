import json

def _model__init__(self, *args, **kwargs):
    cls = type(self)
    cls_d = cls.__dict__
    annotations = cls.__annotations__
    fields = annotations.keys()

    i = 0   # index into args
    for field in fields:
        if field in kwargs:
            setattr(self, field, kwargs.pop(field))
        else:
            if i < len(args):
                setattr(self, field, args[i])
                i += 1
            elif field in cls_d:    # has default value
                setattr(self, field, cls_d[field])
            else:
                if 'None' in annotations[field]:
                    setattr(self, field, None)
                else:
                    raise TypeError(f"{cls.__name__} missing required argument {field!r}")
    if len(args) > i:
        raise TypeError(f"{cls.__name__} takes {len(fields)} positional arguments but {len(args)} were given")
    if len(kwargs) > 0:
        raise TypeError(f"{cls.__name__} got an unexpected keyword argument {next(iter(kwargs))!r}")
    
    dict = self._asdict()
    json = json.dumps(dict)
    
    self._data = ModelData([], json)

def _model__repr__(self):
    cls = type(self)
    fields = cls.__annotations__.keys()

    obj_d = self.__dict__
    args: list = [f"{field}={obj_d[field]!r}" for field in fields]
    return f"{type(self).__name__}({', '.join(args)})"

def _model_asdict(self):
    cls = type(self)
    obj_d = self.__dict__
    fields = cls.__annotations__.keys()
    return {field: obj_d[field] for field in fields}

def model(cls: type):
    assert type(cls) is type
    cls.__init__ = _model__init__
    cls.__repr__ = _model__repr__
    cls._asdict = _model_asdict
    return cls
