import vendorlib
from vendorlib.factory import MakeClient


def BuildLocal(name):
    return name


class Local:
    def __init__(self, name):
        self.name = name


def wire(name):
    client = MakeClient(name)
    conn = vendorlib.Connect(client)
    local = BuildLocal(name)
    obj = Local(local)
    return conn, obj
