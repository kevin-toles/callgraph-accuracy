export const add = (a, b) => a + b;
export const sub = function (a, b) {
  return add(a, -b);
};
export function mul(a, b) {
  return a * b;
}
export class Acc {
  constructor() {
    this.v = add(0, 0);
  }
}
export const times = mul;
export const toJson = JSON.stringify;
export const minus = (sub);

times(2, 3);
toJson({ a: sub(1, 2) });
new Acc();
