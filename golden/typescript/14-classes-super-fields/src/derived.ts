import { Base } from "./base";

function seed(): number {
  return 7;
}

export class Derived extends Base {
  static instances: number[] = Derived.init();
  weight: number = seed();
  static {
    seed();
  }
  constructor(id: string) {
    super(id);
  }
  static init(): number[] {
    return [seed()];
  }
  tag(): string {
    return "derived:" + super.tag();
  }
  show(): string {
    return this.describe();
  }
}
