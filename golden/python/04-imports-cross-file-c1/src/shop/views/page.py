from ..util import slugify
from .. import util as u
from shop.util import slugify as sg
from shop import slugify as reexported
from shop.util import *
import shop.util


def render(name):
    a = slugify(name)
    b = u.slugify(name)
    c = sg(name)
    d = reexported(name)
    e = title_slug(name)
    f = shop.util.slugify(name)
    return [a, b, c, d, e, f]
