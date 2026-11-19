import { type Store, Job } from "./store";

export class CopyJob extends Job {
  constructor(private src: Store, private dst: Store) {
    super();
  }
  execute(): void {
    this.dst.put("k", this.src.get("k"));
  }
}

export function kick(j: Job, s: Store): void {
  j.run();
  j.execute();
  s.put("a", s.get("b"));
}
