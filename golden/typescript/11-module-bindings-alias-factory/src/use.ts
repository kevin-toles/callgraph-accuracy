import { render, strict, log, cached, makeLogger, double } from "./fns";

export function go(): string {
  const local = makeLogger("y");
  cached();
  return log(render(double(1))) + strict(2) + local("z");
}
