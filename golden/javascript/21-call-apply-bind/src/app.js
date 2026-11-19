import { validateInput } from "./util.js";
function local(a) { return a; }
const bound = validateInput.bind(null);
export function dispatch(evt, client, o, k) {
  validateInput.call(this, evt);
  local.apply(null, [evt]);
  bound(evt);
  const v = local.bind(null);
  v(evt);
  Object.prototype.hasOwnProperty.call(o, k);
  (function () { helper(); }).call(this);
  client.call(evt);
  validateInput.extra();
}
