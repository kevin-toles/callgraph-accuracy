function helper(x) {
  return x + 1;
}

export function outer(xs) {
  const inner = (x) => helper(x);
  function twice(x) {
    return inner(inner(x));
  }
  xs.forEach(function (x) {
    helper(x);
  });
  return twice(1);
}

export class Tree {
  visit(nodes) {
    const step = (n) => this.leaf(n);
    nodes.map((n) => step(n));
    return step(0);
  }
  leaf(n) {
    return helper(n);
  }
}

[1, 2].forEach((v) => outer([v]));
