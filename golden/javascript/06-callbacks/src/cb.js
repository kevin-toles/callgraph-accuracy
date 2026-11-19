export function each(xs, fn) {
  for (const x of xs) {
    fn(x);
  }
}

export class Button {
  constructor(onClick) {
    this.onClick = onClick;
  }
  click() {
    this.onClick();
  }
}

function pick(flag) {
  return flag ? each : null;
}

export function run(handler) {
  const chosen = pick(true);
  chosen([1], handler);
  const b = new Button(handler);
  b.click();
  each([2], (v) => handler(v));
}
