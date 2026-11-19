def route(path):
    def wrap(fn):
        return fn
    return wrap


def trace(fn):
    return fn


@route("/home")
@trace
def home():
    return "ok"
