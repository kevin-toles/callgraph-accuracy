const { clean } = require("./util");

module.exports = function (s) {
  return "<" + clean(s) + ">";
};
