export interface Store {
  get(key: string): string;
  put(key: string, value: string): void;
}

export abstract class Job {
  protected constructor() {}
  abstract execute(): void;
  run(): void {
    this.execute();
    this.log();
  }
  log(): void {}
}
