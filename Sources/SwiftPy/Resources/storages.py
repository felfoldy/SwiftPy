import json

def _model__init__(self, *args, **kwargs):
    cls = type(self)
    cls_d = cls.__dict__
    annotations = cls.__annotations__
    fields = annotations.keys()

    i = 0   # index into args
    for field in fields:
        if field in kwargs:
            self._fields[field] = kwargs.pop(field)
            continue

        if i < len(args):
            self._fields[field] = args[i]
            i += 1
        elif field in self._fields: # has default value
            continue

        if 'None' in annotations[field]:
            self._fields[field] = None
        else:
            raise TypeError(f"{cls.__name__} missing required argument {field!r}")
    
    if '_data' in kwargs:
        self._data = kwargs.pop('_data')
    else:
        json = json.dumps(self._fields)
        nameKey = LookupKeyValue('__name__', cls.__name__)
        self._data = ModelData([nameKey], json)
    
    if len(args) > i:
        raise TypeError(f"{cls.__name__} takes {len(fields)} positional arguments but {len(args)} were given")
    if len(kwargs) > 0:
        raise TypeError(f"{cls.__name__} got an unexpected keyword argument {next(iter(kwargs))!r}")

def _model__repr__(self) -> str:
    cls = type(self)
    fields = cls.__annotations__.keys()
    obj_d = self._fields
    args: list = [f"{field}={obj_d[field]!r}" for field in fields]
    return f"{type(self).__name__}({', '.join(args)})"
    
@classmethod
def _model_fromdata(cls, data: ModelData):
    args = json.loads(data.json)
    return cls(**args, _data=data)

def _make_property(field: str, all_fields: list[str]):
    def fget(self):
        return self._fields[field]

    def fset(self, value):
        self._fields[field] = value
        self._data.json = json.dumps(self._fields)

    return property(fget, fset)

def model(cls: type):
    assert type(cls) is type
    cls.__init__ = _model__init__
    cls.__repr__ = _model__repr__
    cls._fromdata = _model_fromdata
    
    fields = cls.__annotations__.keys()
    cls_d = cls.__dict__
    
    cls._fields = {} # Default fields.

    for field in fields:
        prop = _make_property(field, fields)
        if field in cls_d:
            cls._fields[field] = cls_d[field]
        setattr(cls, field, prop)
    
    return cls
