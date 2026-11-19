def transform(x):
    return x


def pick_handler():
    return transform


def apply(fn, value):
    return fn(value)


def run(items, on_item):
    for item in items:
        on_item(item)
    handler = pick_handler()
    handler(items)
    return map(transform, items)


class Emitter:
    def __init__(self, hook):
        self._hook = hook

    def emit(self):
        self._hook()
        return apply(self.emit, 1)
