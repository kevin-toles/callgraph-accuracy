import { trim, nums, banner } from "./lib";
import { shout } from "./lib/strings";

export function main(arg: string): number {
  banner(trim(arg));
  shout(arg);
  return nums.clamp(arg.length);
}
