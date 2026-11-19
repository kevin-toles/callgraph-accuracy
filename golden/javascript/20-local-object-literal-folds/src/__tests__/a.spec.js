import { ref } from "../src/ref.js";
test("x", () => {
  const Comp = { setup() { ref(0); } };
  render(Comp);
});
test("y", () => {
  const Comp = { setup() { ref(2); } };
  render(Comp);
});
export const Top = { setup() { ref(1); } };
