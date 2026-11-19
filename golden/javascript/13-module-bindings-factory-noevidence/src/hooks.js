import { makeId } from "idgen";

function makeAdder(n) {
  return function (x) {
    return x + n;
  };
}
const twice = (f) => (x) => f(f(x));

export const add5 = makeAdder(5);
export const quad = twice(add5);
export const nextId = makeId();

export function demo() {
  return [add5(1), quad(2), nextId()];
}
