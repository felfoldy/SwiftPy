import random

class View(_View):
    def __init__(self, content_type: str = 'Custom'):
        super().__init__(content_type)
        self._fields = {}
        
    def update(self):
        _View._create_body(self)
        if self._parent:
            _View._create_body(self._parent)


def state():
    id = View._make_id()

    def fget(self):
        return self._fields[id]

    def fset(self, value):
        self._fields[id] = value
        self.update()

    return property(fget, fset)

# MARK: - Basic

class Text(View):
    text: str = state()

    def __init__(self, text: str):
        super().__init__('Text')
        self.text = text


class Table(View):
    rows: list[dict[str, str]] = state()

    def __init__(self, rows: list[dict[str, Any]]):
        super().__init__('Table')
        if not rows:
            raise ValueError("Table requires at least one row of data")
        self.columns = list(rows[0].keys())
        self.rows = [
            { key: str(value) for key, value in row.items() }
            for row in rows
        ]


# MARK: - Containers

class ContainerView(View):
    def __call__(self, *views: View):
        self._subviews = list(views)
        return self
    
    def add(self, view: View):
        subviews = self._subviews
        subviews.append(view)
        self._subviews = subviews


class VStack(ContainerView):
    def __init__(self, *views: View):
        super().__init__('VStack', )
        if views:
            self._subviews = list(views)


class ScrollView(ContainerView):
    def __init__(self, *views: View):
        super().__init__('ScrollView')
        if views:
            self._subviews = list(views)
