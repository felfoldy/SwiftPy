__doc__ = "Runs a file as a playground: every line's value is recorded."

import ast

# Records sent per line before only the count goes on; the last one is sent
# when the run ends, so a loop shows its count and last value.
_SENT_PER_LINE = 20

# By run, as its filename: two files can run at once.
_counts: dict = {}
_last: dict = {}


def _record(run, line, name, value):
    from interpreter import native
    # By line and name, so `x, y = ...` counts its line once.
    counts = _counts.setdefault(run, {})
    count = counts.get((line, name), 0) + 1
    counts[(line, name)] = count
    if count <= _SENT_PER_LINE:
        native._playground_record(line, name, value, count)
    else:
        _last.setdefault(run, {})[(line, name)] = value


def value(run, line, value):
    """An expression statement's value, which it returns."""
    if value is not None:
        _record(run, line, None, value)
    return value


def assigned(run, line, name, value):
    _record(run, line, name, value)


def begin(run):
    _counts[run] = {}
    _last.pop(run, None)


def end(run):
    """Sends each line's last value it held back, with its full count."""
    from interpreter import native
    counts = _counts.pop(run, {})
    for (line, name), value in _last.pop(run, {}).items():
        native._playground_record(line, name, value, counts[(line, name)])


def _call(run, function, *args):
    # The submodule itself, wherever the code's globals are.
    module = ast.Call(ast.Name('__import__', ast.Load()), [ast.Constant('interpreter.playground')],
                      [ast.keyword('fromlist', ast.Constant(('value',)))])
    return ast.Call(ast.Attribute(module, function, ast.Load()), [ast.Constant(run), *args], [])


def _targets(target):
    """The names an assignment target binds, as source, and loads of them."""
    if isinstance(target, (ast.Tuple, ast.List)):
        for element in target.elts:
            yield from _targets(element)
    elif isinstance(target, (ast.Name, ast.Attribute, ast.Subscript)):
        load = ast.parse(ast.unparse(target), mode='eval').body
        yield ast.unparse(target), load


class _Recorder(ast.NodeTransformer):
    def __init__(self, run):
        self.run = run

    def _body(self, body, docstring=False):
        statements = []
        for index, statement in enumerate(body):
            if docstring and index == 0 and isinstance(statement, ast.Expr) \
                    and isinstance(statement.value, ast.Constant) and isinstance(statement.value.value, str):
                statements.append(statement)
                continue
            statement = self.visit(statement)
            statements.extend(self._statement(statement))
        return statements

    def _statement(self, node):
        if isinstance(node, ast.Expr) and not isinstance(node.value, (ast.Yield, ast.YieldFrom)):
            node.value = ast.copy_location(_call(self.run, 'value', ast.Constant(node.lineno), node.value), node.value)
            return [node]
        if isinstance(node, ast.Assign):
            targets = [pair for target in node.targets for pair in _targets(target)]
        elif isinstance(node, (ast.AnnAssign, ast.AugAssign)) and getattr(node, 'value', None) is not None:
            targets = list(_targets(node.target))
        else:
            return [node]
        records = [ast.copy_location(ast.Expr(_call(self.run, 'assigned', ast.Constant(node.lineno), ast.Constant(name), load)), node)
                   for name, load in targets]
        return [node] + records

    def visit_ClassDef(self, node):
        # A class is a definition, methods and all: nothing in it is a result,
        # even when a system calls its methods every frame.
        return node

    def generic_visit(self, node):
        super().generic_visit(node)
        has_docstring = isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
        for field in ('body', 'orelse', 'finalbody'):
            body = getattr(node, field, None)
            if isinstance(body, list) and body and isinstance(body[0], ast.stmt):
                setattr(node, field, self._body(body, docstring=has_docstring and field == 'body'))
        return node


def statements(tree) -> list:
    """The top-level statements' lines, `[first, last]`, decorators included."""
    ranges = []
    for node in tree.body:
        first = min([node.lineno] + [d.lineno for d in getattr(node, 'decorator_list', [])])
        ranges.append([first, node.end_lineno or node.lineno])
    return ranges


def compile_source(source: str, filename: str):
    """`(code, statements)`, or the `SyntaxError` for Swift to raise."""
    try:
        tree = ast.parse(source, filename)
        ranges = statements(tree)
        body = _Recorder(filename)._body(tree.body, docstring=True)
        # The held-back values are sent however the run ends.
        tree.body = [
            ast.Expr(_call(filename, 'begin')),
            ast.Try(body=body or [ast.Pass()], handlers=[], orelse=[], finalbody=[ast.Expr(_call(filename, 'end'))]),
        ]
        ast.fix_missing_locations(tree)
        # 0x2000: a top-level await compiles to a coroutine.
        return compile(tree, filename, 'exec', 0x2000), ranges
    except SyntaxError as error:
        return error.with_traceback(None)


# What `_compile` made, for Swift to take, as it reads one value per call.
_compiled: dict = {}


def _compile(source: str, filename: str) -> str:
    """Compiles for Swift: an empty string, or the formatted `SyntaxError`."""
    result = compile_source(source, filename)
    if isinstance(result, SyntaxError):
        import traceback
        _compiled.clear()
        _compiled['error_line'] = result.lineno or 0
        return ''.join(traceback.format_exception_only(result))
    code, ranges = result
    _compiled.update(code=code, lines=[line for pair in ranges for line in pair], error_line=0)
    return ''


def _take(key: str):
    return _compiled.pop(key, None)


def _short(value) -> str:
    """Its repr; its type's name where it opens to what it holds, or the repr
    is only that or an address; an enum's member as it's written,
    `Alignment.CENTER`; a container's count."""
    import enum
    if isinstance(value, enum.Enum):
        return f'{type(value).__name__}.{value.name}'
    # Its count, `[2]`: its items show when it's opened. Only exactly these,
    # as a subclass may have a repr of its own.
    if type(value) in (list, tuple, set, frozenset, dict):
        open_, close = '[]' if type(value) is list else '()' if type(value) is tuple else '{}'
        return open_ + (str(len(value)) if value else '') + close
    # What opens reads as its type: its values show inside.
    if _has_items(value):
        return type(value).__name__
    try:
        text = repr(value)
    except Exception:
        return type(value).__name__
    import re
    name = type(value).__name__
    # An address, or a bare type path such as Swift's `Scenes.SceneEntity`.
    if (text.startswith('<') and ' at 0x' in text) or re.fullmatch(r'[A-Za-z_]\w*(\.[A-Za-z_]\w*)+', text):
        return name
    return text if len(text) <= 120 else text[:120] + '…'


def _items(value, limit: int = 30) -> list:
    """What a value holds, one level down, as `(name, item)`: a container's
    items, else its public attributes that aren't methods."""
    if value is None or isinstance(value, (str, bytes, int, float, complex, bool, type)):
        return []
    try:
        if isinstance(value, dict):
            return [(_short(key), item) for key, item in list(value.items())[:limit]]
        if isinstance(value, (list, tuple, set, frozenset)):
            return [(f'[{index}]', item) for index, item in enumerate(list(value)[:limit])]
        items = []
        # Indexed, as a Group of views is, before its properties.
        kind = type(value)
        if hasattr(kind, '__len__') and hasattr(kind, '__getitem__'):
            try:
                items = [(f'[{index}]', value[index]) for index in range(min(len(value), limit))]
            except Exception:
                items = []
        for name in dir(value):
            if name.startswith('_'):
                continue
            try:
                item = getattr(value, name)
            except Exception:
                continue
            if callable(item) and not hasattr(item, 'body'):
                continue
            items.append((name, item))
            if len(items) >= limit:
                break
        return items
    except Exception:
        return []


def _items_flat(value) -> list:
    """`_items`, flat as `[name, item, name, item, ...]` for Swift."""
    return [part for pair in _items(value) for part in pair]


def _has_items(value) -> bool:
    return bool(_items(value, limit=1))
