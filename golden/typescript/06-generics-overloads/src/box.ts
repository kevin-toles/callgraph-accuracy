export class Box<T> {
  constructor(private value: T) {}
  map<U>(fn: (v: T) => U): Box<U> {
    return new Box<U>(fn(this.value));
  }
}

export function parse(s: string): number;
export function parse(s: number): number;
export function parse(s: string | number): number {
  return typeof s === "number" ? s : s.length;
}

export function demo(): Box<number> {
  const b: Box<string> = new Box<string>("x");
  parse(1);
  parse("a");
  return b.map<number>((v) => parse(v));
}
