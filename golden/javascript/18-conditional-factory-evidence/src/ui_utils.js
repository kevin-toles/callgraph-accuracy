function makeRound() {
  const k = 1;
  return k > 0 ? Math.fround : (x) => x;
}
const calcRound = typeof PDFJSDev !== "undefined" ? Math.fround : makeRound();
const makeDecode = () => {
  function decode(bytes) {
    return bytes;
  }
  return decode;
};
const makeValue = () => 1;
/** @type {function(number):number} */
export const BrotliDecode = makeDecode();
export const notFn = makeValue();
const mixed = typeof x === "undefined" ? Math.fround : notFn;
export function use(v) {
  calcRound(v);
  BrotliDecode(v);
  notFn(v);
  mixed(v);
}
