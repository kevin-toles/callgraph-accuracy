function createImpl(tag: string): string {
  return "<" + tag + ">";
}
function createDev(tag: string): string {
  return createImpl(tag);
}
const dev = process.env.NODE_ENV !== "production";
export const createVNode = (dev ? createDev : createImpl) as typeof createImpl;
export let onTick: (n: number) => void;
export function setTick(fn: (n: number) => void): void {
  onTick = fn;
}
export function render(): string {
  onTick(1);
  return createVNode("div");
}
