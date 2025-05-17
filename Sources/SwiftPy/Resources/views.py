import random

class View(_View):
    def __init__(self, content_type: str = 'Custom'):
        super().__init__(content_type)
        self._fields = {}
        
    def update(self):
        _View._create_body(self)
        if self._parent:
            print('update parent')
            _View._create_body(self._parent)


def state():
    id = View._make_id()

    def fget(self):
        return self._fields[id]

    def fset(self, value):
        print(f"{id} - {value}")
        self._fields[id] = value
        self.update()

    return property(fget, fset)


class VStack(View):
    def __init__(self, *views: View):
        super().__init__('VStack')
        self._subviews = list(views)
        self.update()
        
    def add(self, view: View):
        subviews = self._subviews
        subviews.append(view)
        self._subviews = subviews


class Text(View):
    text: str = state()

    def __init__(self, text: str):
        super().__init__('Text')
        self.text = text
