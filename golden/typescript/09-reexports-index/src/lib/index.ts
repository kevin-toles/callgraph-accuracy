export * from "./strings";
export * as nums from "./nums";
import { shout } from "./strings";

export function banner(s: string): string {
  return shout(s);
}
