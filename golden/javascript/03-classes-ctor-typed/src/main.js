import { Rect } from "./shapes.js";

function total() {
  const r = new Rect(2, 3);
  const a = r.area();
  return a + r.doubleArea();
}

const big = new Rect(10, 10);
big.area();
total();
