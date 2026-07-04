import json
from storages.native import *

def _did_change(self):
    if getattr(self, '_data', None) is not None:
        self._data.json = json.dumps(self._fields)

@classmethod
def _makemodels(cls, models: list):
    elements = []
    for model in models:
        args = json.loads(model.json)
        element = cls(**args)
        element._data = model
        elements.append(element)
    return elements

def _extend(cls):
    cls._did_change = _did_change
    cls._makemodels = _makemodels
