type Handler = (n: number) => number;

export class Pipeline {
  private readonly step: Handler;
  private transform: (s: string) => string;
  constructor(step: Handler, transform: (s: string) => string) {
    this.step = step;
    this.transform = transform;
  }
  run(n: number): string {
    this.reset();
    return this.transform("" + this.step(n));
  }
  reset(): void {}
}
