import * as fs from "node:fs";

export class Reader {
  read(path: string): string {
    const raw = fs.readFileSync(path).toString();
    const obj = JSON.parse(raw);
    obj.normalize();
    missingHelper(raw);
    return JSON.parse(raw).title.trim();
  }
}
