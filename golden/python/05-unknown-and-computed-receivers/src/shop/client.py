class Widget:
    def __init__(self):
        self.ready = True

    def ping(self):
        return self.ready


class Service:
    def __init__(self, client):
        self.client = client

    def fetch(self, req):
        data = self.client.get(req)
        req.session.close()
        parts = "a,b".split(",")
        first = parts[0].strip()
        return make_widget().ping(), data, first


def make_widget():
    return Widget()


def local_typed():
    w = Widget()
    return w.ping()
