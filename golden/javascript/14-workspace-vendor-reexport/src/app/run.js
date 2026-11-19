import { padLeft, casing } from "@acme/strutil";
import { leftPad } from "../vendor/left.js";

export function run(s) {
  return casing.upper(padLeft(leftPad(s), 8));
}
