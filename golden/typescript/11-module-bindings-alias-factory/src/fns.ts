export function baseRender(n: number): string {
  return "r" + n;
}
type RenderFn = (n: number) => string;
export const render = baseRender as RenderFn;
export const strict = baseRender!;
export const checked = (baseRender) satisfies RenderFn;
export const double = (n: number): number => n * 2;

export function makeLogger(prefix: string): (msg: string) => string {
  const f = (msg: string) => prefix + msg;
  return f;
}
export const memo = <T>(fn: () => T) => (): T => fn();
export const log = makeLogger("[x]");
export const cached = memo(() => render(double(1)));

log(render(2) + strict(3) + checked(4));
cached();
