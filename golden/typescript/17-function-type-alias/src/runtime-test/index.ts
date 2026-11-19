import { createRenderer, type RootRenderFunction } from "../runtime-core/index";
type Plain = (x: number) => number;
type Box = { v: number };
const { render: baseRender } = createRenderer<string>({});
export const render = baseRender as RootRenderFunction<string>;
const half = baseRender as unknown as Plain;
const boxed = baseRender as unknown as Box;
export function go() {
  render(null, "root");
  half(1);
  boxed();
}
