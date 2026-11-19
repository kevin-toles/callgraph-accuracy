function build() {
  return [];
}

function start() {
  return 1;
}

export class Registry {
  static items = build();
  count = start();
  static {
    Registry.items.push(start());
  }
  constructor() {
    this.reset();
  }
  reset() {
    return build();
  }
}

new Registry();
