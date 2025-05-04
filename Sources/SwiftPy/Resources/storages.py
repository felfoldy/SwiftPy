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
            continue

        if i < len(args):
            setattr(self, field, args[i])
            i += 1
        elif field in cls_d: # has default value
            setattr(self, field, cls_d[field])
        elif 'None' in annotations[field]:
            setattr(self, field, None)
        else:
            raise TypeError(f"{cls.__name__} missing required argument {field!r}")
    
    if '_data' in kwargs:
        self._data = kwargs.pop('_data')
    else:
        dict = {field: self.__dict__[field] for field in fields}
        json = json.dumps(dict)
        nameKey = LookupKeyValue('__name__', cls.__name__)
        self._data = ModelData([nameKey], json)
    
    if len(args) > i:
        raise TypeError(f"{cls.__name__} takes {len(fields)} positional arguments but {len(args)} were given")
    if len(kwargs) > 0:
        raise TypeError(f"{cls.__name__} got an unexpected keyword argument {next(iter(kwargs))!r}")

def _model__repr__(self) -> str:
    cls = type(self)
    fields = cls.__annotations__.keys()
    obj_d = self.__dict__
    args: list = [f"{field}={obj_d[field]!r}" for field in fields]
    return f"{type(self).__name__}({', '.join(args)})"
    
@classmethod
def _model_fromdata(cls, data: ModelData):
    args = json.loads(data.json)
    return cls(**args, _data=data)

def model(cls: type):
    assert type(cls) is type
    cls.__init__ = _model__init__
    cls.__repr__ = _model__repr__
    cls._fromdata = _model_fromdata
    return cls
