class Base {
  constructor(name) {
    this.name = name;
  }
  greet() {
    return this.label();
  }
  label() {
    return this.name;
  }
}

module.exports = Base;
