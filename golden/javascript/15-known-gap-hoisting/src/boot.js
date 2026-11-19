main();

function main() {
  const v = compute(2);
  return finish(v);

  function finish(x) {
    return compute(x) + 1;
  }
}

function compute(n) {
  return n * 2;
}

export class Late {
  go() {
    return compute(1);
  }
}
