export type RootRenderFunction<HostElement = unknown> = (
  vnode: unknown,
  container: HostElement,
) => void;
export interface Renderer<E> {
  render: RootRenderFunction<E>;
}
export function createRenderer<E>(options: unknown): Renderer<E> {
  return { render: (v: unknown, c: E) => {} };
}
