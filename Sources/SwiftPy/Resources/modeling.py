__doc__ = "Create typed data models for structured output and persistent storage."

@classmethod
def _model_from_json(cls, json_str: str):
    import json
    fields = list(cls.__annotations__.keys())
    data = json.loads(json_str)
    return cls(**{k: v for k, v in data.items() if k in fields})

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

def _model_did_change(self):
    pass

def _make_property(field: str):
    def fget(self):
        return self._fields[field]

    def fset(self, value):
        self._fields[field] = value
        self._did_change()

    return property(fget, fset)

def _make_schema(cls: type):
    cls_d = cls.__dict__
    properties = []

    for field, annotation in cls.__annotations__.items():
        property_schema = {
            "name": field,
            "type": annotation,
        }

        if field in cls_d:
            property_schema["default"] = cls_d[field]

        properties.append(property_schema)

    return {
        "name": cls.__name__,
        "properties": properties,
    }

def model(cls: type):
    """Convert an annotated class into a data model.

    Annotated attributes become mutable model fields. A class attribute supplies
    a field's default value; an optional field without a default starts as
    `None`. Model instances support positional and keyword initialization, a
    readable representation, structured-output schemas, and storage change
    tracking.

    ```python
    from modeling import model

    @model
    class Item:
        name: str
        quantity: int = 1
        note: str | None

    item = Item("Hammer", quantity=2)
    ```

    cls: The annotated class to convert.
    """
    assert type(cls) is type
    cls.__init__ = _model__init__
    cls.__repr__ = _model__repr__
    cls._did_change = _model_did_change
    cls._from_json = _model_from_json

    fields = cls.__annotations__.keys()
    cls_d = cls.__dict__

    cls._schema = _make_schema(cls)
    cls._defaults = {}

    for field in fields:
        if field in cls_d:
            cls._defaults[field] = cls_d[field]

        setattr(cls, field, _make_property(field))

    return cls
