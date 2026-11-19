export namespace Geo {
  export function area(r: number): number {
    return sq(r) * 3;
  }
  function sq(x: number): number {
    return x * x;
  }
  export class Pt {
    constructor(public x: number) {}
    norm(): number {
      return sq(this.x);
    }
  }
}

export namespace Outer.Inner {
  export function deep(): number {
    return Geo.area(1);
  }
}
