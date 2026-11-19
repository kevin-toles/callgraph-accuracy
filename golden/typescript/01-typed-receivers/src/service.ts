import { Repo } from "./repo";
import type { Server } from "node:http";

const shared: Repo = new Repo();

export class Service {
  private backup: Repo;
  constructor(private repo: Repo, private srv: Server) {
    this.backup = new Repo();
  }
  store(item: string): boolean {
    const local: Repo = this.repo;
    local.find(1);
    this.backup.save(item);
    shared.save(item);
    this.srv.close();
    return this.repo.save(item);
  }
}

export function handle(r: Repo, s: Server): void {
  r.find(2);
  s.close();
}
