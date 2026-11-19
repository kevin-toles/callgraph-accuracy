export class Svc {
  run(): void {}
  with(n: number): Svc { return this; }
}
function make(): Svc { return new Svc(); }
function maybe(): Svc | undefined { return undefined; }
function any<T>(): T { return undefined as any; }
export function use(svc: Svc) {
  make().run();
  const s = make();
  s.run();
  maybe()?.run();
  svc.with(1).run();
  const g = any<Svc>();
  g.run();
  let v = make();
  v = new Svc();
  v.run();
}
