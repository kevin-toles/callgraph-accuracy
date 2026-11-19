import "./side.js";

export class Logger {
  log(msg) {
    console.log(JSON.stringify(msg));
    return parseInt("42", 10);
  }
  ref() {
    const f = this.log;
    const kind = typeof f;
    const size = this.size;
    return [kind, size, Math.max(1, 2)];
  }
}

globalThis.parseInt("7");
