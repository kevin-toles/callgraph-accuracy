function log(n: number): void {}

export class Queue {
  drain(xs: number[], onDone: (n: number) => void): void {
    const each = (x: number): void => {
      log(x);
      onDone(x);
    };
    function finish(): void {
      each(0);
    }
    for (const x of xs) each(x);
    [1].map((v) => log(v));
    finish();
  }
}

export function schedule(cb: () => void): void {
  setTimeout(cb, 0);
  cb();
}
