const lib = require("./lib");
const { helper } = require("./lib");
const dyn = require(process.argv[2]);
import { nextId } from "./lib";

export function entry(): number {
  lib.helper();
  nextId();
  dyn.start();
  return helper();
}
