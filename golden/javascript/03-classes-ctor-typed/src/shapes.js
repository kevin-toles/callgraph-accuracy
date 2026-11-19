export class Rect {
  constructor(w, h) {
    this.w = w;
    this.h = h;
  }
  area() {
    return this.w * this.h;
  }
  scaled(k) {
    return new Rect(this.w * k, this.h * k);
  }
  doubleArea() {
    return this.scaled(2).area();
  }
}
