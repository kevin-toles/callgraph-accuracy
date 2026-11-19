import { isValidExplicitDest } from "../display/api_utils.js";
export function setHash(dest) {
  return isValidExplicitDest(dest);
}
