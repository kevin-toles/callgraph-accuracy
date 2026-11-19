class Outer:
    class Inner:
        def __init__(self, v):
            self.v = v

        def show(self):
            return repr(self.v)

    def build(self, v):
        def wrap():
            return Outer.Inner(v)
        return wrap()

    def helper(x):
        return x


def walk(values):
    def visit(v):
        return Outer.helper(v)
    scale = lambda n: visit(n)
    results = [visit(v) for v in values]
    ordered = sorted(values, key=lambda v: visit(v))
    return scale(results), ordered
