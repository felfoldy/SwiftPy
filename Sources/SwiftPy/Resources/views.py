class View(_View):
    def __init__(self):
        super().__init__(type(self).__name__)
        self._states = {}
        
    def update(self):
        if self._is_configured:
            _View._build_syntax(self)
            if self._parent:
                _View._build_syntax(self._parent)


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
        
        self._config()
        
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
    columns: list[str] = state()
    rows: list[dict[str, str]] = state()

    def __init__(self, rows: list[dict[str, Any]]):
        if not rows:
            raise ValueError("Table requires at least one row of data")
    
        super().__init__()
        self.columns = list(rows[0].keys())
        self.rows = [
            { key: str(value) for key, value in row.items() }
            for row in rows
        ]
        self._config()


# MARK: - Containers

class ContainerView(View):
    def __init__(self, *views: View):
        super().__init__()
        if views:
            self._subviews = list(views)
        self._config()

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

class ViewModifier(View):
    @classmethod
    def make(cls: type):
        def _method(self, *args, **kwargs):
            annotations = cls.__annotations__
            fields = list(annotations.keys())
            instance = cls()
            instance._modified_view = self
            
            i = 0
            for field in fields:
                if field in kwargs:
                    setattr(instance, field, kwargs.pop(field))
                elif i < len(args):
                    setattr(instance, field, args[i])
                    i += 1
                else:
                    raise TypeError(f"{mod_cls.__name__} missing required argument {field!r}")
            
            instance._config()
            return instance
        return _method

    @property
    def content(self) -> View:
        self._modified_view


class FontModifier(ViewModifier):
    font: str = state()


class ForegroundModifier(ViewModifier):
    style: str = state()


View.font = FontModifier.make()
View.foreground = ForegroundModifier.make()


# MARK: - Types

class Font:
    LARGE_TITLE = 'large_title'
    TITLE = 'title'
    TITLE2 = 'title2'
    TITLE3 = 'title3'
    HEADLINE = 'headline'
    SUBHEADLINE = 'subheadline'
    BODY = 'body'
    CALLOUT = 'callout'
    FOOTNOTE = 'footnote'
    CAPTION = 'caption'
    CAPTION2 = 'caption2'


class Color:
    RED     = 'red'
    ORANGE  = 'orange'
    YELLOW  = 'yellow'
    GREEN   = 'green'
    MINT    = 'mint'
    TEAL    = 'teal'
    CYAN    = 'cyan'
    BLUE    = 'blue'
    INDIGO  = 'indigo'
    PURPLE  = 'purple'
    PINK    = 'pink'
    BROWN   = 'brown'
    WHITE   = 'white'
    GRAY    = 'gray'
    BLACK   = 'black'
    CLEAR   = 'clear'
    
