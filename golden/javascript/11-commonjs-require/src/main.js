const util = require("./util");
const { helper } = require("./util.js");
const fmt = require("./fmt");
const http = require("node:http");

function serve(name) {
  const plugin = require(name);
  plugin.init();
  const server = http.createServer(fmt);
  server.listen(8080);
  return util.clean(helper(name));
}

fmt(serve("x"));
