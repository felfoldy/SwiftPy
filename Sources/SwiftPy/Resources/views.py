class View(_View):
    def __init__(self):
        super().__init__(type(self).__name__)
        self._states = {}
        
    def update(self):
        _View._create_body(self)
        if self._parent:
            _View._create_body(self._parent)
            
    def font(self, font: str) -> View:
        view = FontModifier(self)
        view.font = font
        return view


class ViewModifier(View):
    def __init__(self, content: View):
        super().__init__()
        self._modified_view = content


def state():
    id = View._make_id()

    def fget(self):
        return self._states[id]

    def fset(self, value):
        self._states[id] = value
        self.update()

    return property(fget, fset)

def view_init(cls: type):
    """Adds an initializer to the view.
    """
    
    def _view_init(self, *args, **kwargs):
        super(cls, self).__init__()
    
        cls = type(self)
        annotations = cls.__annotations__
        fields = annotations.keys()
        
        i = 0
        for field in fields:
            if field in kwargs:
                setattr(self, field, kwargs.pop(field))
            elif i < len(args):
                setattr(self, field, args[i])
                i += 1
            else:
                raise TypeError(f"{cls.__name__} missing required argument {field!r}")
        
    cls.__init__ = _view_init
    return cls


# MARK: - Basic

@view_init
class Text(View):
    text: str = state()


@view_init
class SystemImage(View):
    name: str = state()


class Table(View):
    rows: list[dict[str, str]] = state()

    def __init__(self, rows: list[dict[str, Any]]):
        super().__init__()
        if not rows:
            raise ValueError("Table requires at least one row of data")
        self.columns = list(rows[0].keys())
        self.rows = [
            { key: str(value) for key, value in row.items() }
            for row in rows
        ]


# MARK: - Containers

class ContainerView(View):
    def __init__(self, *views: View):
        super().__init__()
        if views:
            self._subviews = list(views)

    def __call__(self, *views: View):
        self._subviews = list(views)
        return self
    
    def add(self, view: View):
        subviews = self._subviews
        subviews.append(view)
        self._subviews = subviews


class VStack(ContainerView):
    pass


class ScrollView(ContainerView):
    pass


# MARK: - ViewModifiers

class Font:
    title = 'title'

class FontModifier(ViewModifier):
    font: str = state()
