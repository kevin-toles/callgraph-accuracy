function isOk(x) {
  return x > 0;
}

export function report(items) {
  return items
    .filter(isOk)
    .map((x) => format(x))
    .join(",");
}

function format(x) {
  return x.toFixed(2);
}
