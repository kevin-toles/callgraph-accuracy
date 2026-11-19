export class Cache {
  get(key: string): string | undefined {
    return key;
  }
}

export class Loader {
  private cache: Cache | null;
  constructor(cache?: Cache) {
    this.cache = cache ?? null;
  }
  load(key: string, fallback?: Cache): string | undefined {
    const c: Cache | undefined = fallback;
    c?.get(key);
    fallback!.get(key);
    return this.cache?.get(key);
  }
}
