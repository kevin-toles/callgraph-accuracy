import type { Opts } from "./opts";

export enum Mode {
  Fast = 1,
  Slow = 2,
}

export interface Shape {
  area(): number;
}

type Area = ReturnType<typeof measure>;

export function measure(s: unknown, o?: Opts): number {
  const sh: Shape = s as Shape;
  const sh2: Shape = <Shape>s;
  const m: Mode = Mode.Fast;
  const fn = sh.area;
  const a: Area = sh!.area();
  return a + sh2.area() + m + (o ? o.level : 0) + (fn ? 0 : 1);
}
