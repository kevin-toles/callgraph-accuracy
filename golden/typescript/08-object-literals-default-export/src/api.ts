function util(s: string): string {
  return s;
}

export const handlers = {
  ping(): string {
    return util("pong");
  },
  echo(s: string): string {
    return handlers.ping() + util(s);
  },
};

export function make() {
  return {
    run(): string {
      return util("run");
    },
  };
}

export default {
  start(): string {
    return handlers.echo("go");
  },
};
