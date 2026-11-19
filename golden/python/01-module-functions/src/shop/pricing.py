import math


def base_price(items):
    return len(items)


def total(items):
    subtotal = base_price(items)
    return math.ceil(subtotal)


DEFAULT = total([1, 2])
print(DEFAULT)

if __name__ == "__main__":
    total([])
