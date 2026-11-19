export function fmt(s) {
  return wrap(s);
}

function wrap(s) {
  return "[" + s + "]";
}
