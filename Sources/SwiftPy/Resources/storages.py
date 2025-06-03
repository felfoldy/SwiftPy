import json
from views import Window, Table, WebView

def _model__init__(self, *args, **kwargs):
    cls = type(self)
    annotations = cls.__annotations__
    fields = annotations.keys()
    self._fields = cls._defaults.copy()

    i = 0   # index into args
    for field in fields:
        if field in kwargs:
            self._fields[field] = kwargs.pop(field)
            continue

        if i < len(args):
            self._fields[field] = args[i]
            i += 1
            continue
        
        if field in self._fields: # has default value
            continue

        if 'None' in annotations[field]:
            self._fields[field] = None
        else:
            raise TypeError(f"{cls.__name__} missing required argument {field!r}")
    
    if '_data' in kwargs:
        self._data = kwargs.pop('_data')
    else:
        self._makedata()
    
    if len(args) > i:
        raise TypeError(f"{cls.__name__} takes {len(fields)} positional arguments but {len(args)} were given")
    if len(kwargs) > 0:
        raise TypeError(f"{cls.__name__} got an unexpected keyword argument {next(iter(kwargs))!r}")

def _model_makedata(self):
    cls = type(self)
    json = json.dumps(self._fields)
    nameKey = LookupKeyValue('__name__', cls.__name__)
    self._data = ModelData([nameKey], json)

def _model__repr__(self) -> str:
    cls = type(self)
    fields = cls.__annotations__.keys()
    obj_d = self._fields
    args: list = [f"{field}={obj_d[field]!r}" for field in fields]
    return f"{type(self).__name__}({', '.join(args)})"
    
@classmethod
def _model_makemodels(cls, models: list[ModelData]):
    elements = []
    for model in models:
        args = json.loads(model.json)
        element = cls(**args, _data=model)
        elements.append(element)
    return elements
    
@classmethod
def _model_inspect(cls, models: list[ModelData]):
    window = Window.create(f"Table{cls.__name__}")

    rows = []
    for model in models:
        model_d = json.loads(model.json)
        row = { "id": str(model.persistent_id) }
        str_row = {k: str(v) for k, v in model_d.items()}
        row.update(str_row)
        rows.append(row)
    
    window.view = Table(rows).title(cls.__name__)
    window.open()


def _make_property(field: str, all_fields: list[str]):
    def fget(self):
        return self._fields[field]

    def fset(self, value):
        self._fields[field] = value
        self._data.json = json.dumps(self._fields)
        ModelContainer.updated()

    return property(fget, fset)

def model(cls: type):
    assert type(cls) is type
    cls.__init__ = _model__init__
    cls.__repr__ = _model__repr__
    cls._makedata = _model_makedata
    cls._makemodels = _model_makemodels
    cls._inspect = _model_inspect
    
    fields = cls.__annotations__.keys()
    cls_d = cls.__dict__
    
    cls._defaults = {}

    # Remap fields into properties.
    for field in fields:
        # set default
        if field in cls_d:
            cls._defaults[field] = cls_d[field]
    
        setattr(cls, field, _make_property(field, fields))
    
    return cls

def show_tutorials():
    window = Window.create('storages-tutorial')
    window.view = WebView('https://felfoldy.github.io/SwiftPy/tutorials/swiftpy/createdatamodels')
    window.open()
