import { createVNode, onTick, setTick } from "./vnode";

setTick((n) => void n);
onTick(2);
createVNode("span");
