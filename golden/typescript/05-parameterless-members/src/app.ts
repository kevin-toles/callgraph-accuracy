export class Config {
  load(): string {
    return "cfg";
  }
}

export class Db {
  save(v: string): void {}
}

export class App {
  private cfg: Config;
  private db: Db;
  constructor(cfg: Config, db: Db) {
    this.cfg = cfg;
    this.db = db;
  }
  get store(): Db {
    return this.db;
  }
  config(): Config {
    return this.cfg;
  }
  boot(): void {
    this.store.save(this.config().load());
  }
}
