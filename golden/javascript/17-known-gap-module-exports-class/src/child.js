const Base = require("./base");

class Child extends Base {
  constructor(name) {
    super(name);
  }
  run() {
    return this.greet();
  }
}

module.exports = Child;
