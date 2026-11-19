import { _isValidExplicitDest } from "../shared/util.js";
const isRefProxy = v => typeof v === "object";
const isNameProxy = v => typeof v?.name === "string";
const isValidExplicitDest = _isValidExplicitDest.bind(null, isRefProxy, isNameProxy);
function add(a, b) {
  return a + b;
}
const add1 = add.bind(null, 1);
const cfg = makeConfig();
const opaque = cfg.bind(null);
export { isValidExplicitDest };
export function use(d) {
  isValidExplicitDest(d);
  add1(2);
  opaque(3);
}
