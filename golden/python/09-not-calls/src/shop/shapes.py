import os
from typing import Dict, List


class Shape:
    sides = 0

    def area(self) -> int:
        return self.sides


def describe(shapes: List[Shape]) -> Dict[str, int]:
    getter = Shape.area
    first = shapes[0]
    size = first.sides
    sep = os.sep
    assert shapes, "empty"
    del getter
    return {"n": len(shapes), "size": size, "sep": sep}
