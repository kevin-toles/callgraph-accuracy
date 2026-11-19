function helper(s) {
  return s.trim();
}

module.exports = {
  clean(s) {
    return helper(s);
  },
  helper,
};
