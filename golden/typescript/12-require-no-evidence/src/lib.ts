import { makeId } from "idgen";

export function helper(): number {
  return 1;
}
export const nextId = makeId();
export const answer = nextId();
