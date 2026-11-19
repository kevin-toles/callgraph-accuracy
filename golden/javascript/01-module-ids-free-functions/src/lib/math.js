export function square(n) {
  return mul(n, n);
}

function mul(a, b) {
  return a * b;
}

export function cube(n) {
  return mul(square(n), n);
}
