from storage.native import *

Store = Container

def _did_change(self):
    if getattr(self, '_data', None) is not None:
        import json
        self._data.json = json.dumps(self._fields)

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
