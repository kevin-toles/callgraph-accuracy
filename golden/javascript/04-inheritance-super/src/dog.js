import { Animal } from "./base.js";
import { EventEmitter } from "events";

export class Dog extends Animal {
  constructor(name) {
    super(name);
  }
  sound() {
    return "woof";
  }
  bark() {
    return this.speak() + super.sound();
  }
}

export class Bus extends EventEmitter {
  constructor() {
    super();
  }
  fire() {
    this.emit("go");
    super.removeAllListeners();
  }
}
