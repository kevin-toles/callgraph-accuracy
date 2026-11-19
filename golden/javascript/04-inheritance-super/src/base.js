export class Animal {
  constructor(name) {
    this.name = name;
  }
  speak() {
    return this.sound();
  }
  sound() {
    return "...";
  }
}
