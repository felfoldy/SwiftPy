__doc__ = "Provides persistent storage for model instances via Store."
__all__ = ["Store"]

from storage.native import *

def _did_change(self, field=None):
    data = getattr(self, '_data', None)
    if data is None:
        return
    import json
    if field is None:
        data.json = json.dumps(self._fields)
        return
    # Only the field set: another copy of the row, or another device, may have
    # written the others since this object read them.
    try:
        stored = json.loads(data.stored_json)
    except ValueError:
        stored = dict(self._fields)
    stored[field] = self._fields[field]
    data.json = json.dumps(stored)

@classmethod
def _makemodels(cls, models: list):
    elements = []
    for model in models:
        element = cls._from_json(model.json)
        element._data = model
        elements.append(element)
    return elements

def _extend(cls):
    cls._did_change = _did_change
    cls._makemodels = _makemodels
