export class Service {
  constructor(client, opts) {
    this.client = client;
    this.opts = opts;
  }
  fetch(id) {
    const res = this.client.get(id);
    this.opts.retry.policy.apply(res);
    return res.data.items[0].render();
  }
  later() {
    return makeThing().start();
  }
}

export function untyped(conn) {
  conn.open();
  notDefinedAnywhere(conn);
  return "abc".toUpperCase();
}
