import { add, sub, mul, Acc, times, toJson, minus } from "./core.js";

export function compute() {
  const acc = new Acc();
  return toJson([add(1, 2), sub(3, 1), mul(2, 2), times(3, 3), minus(5, 1), acc]);
}
