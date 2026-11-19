export class Base {
  constructor(protected id: string) {}
  describe(): string {
    return this.tag() + this.id;
  }
  tag(): string {
    return "base";
  }
}
