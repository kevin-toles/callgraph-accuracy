function _isValidExplicitDest(validRef, validName, dest) {
  return validRef(dest) && validName(dest);
}
export { _isValidExplicitDest };
