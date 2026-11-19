def make_defaults():
    return {}


class Cart:
    DEFAULTS = make_defaults()

    def __init__(self, owner):
        self.owner = owner
        self.items = []
        self.reset()

    def reset(self):
        self.items = []

    def add(self, item):
        self.validate(item)
        return self.count()

    def validate(self, item):
        return isinstance(item, str)

    def count(self):
        return len(self.items)


def checkout(owner):
    cart = Cart(owner)
    Cart.count(cart)
    return cart
