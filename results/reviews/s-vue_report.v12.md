# s-vue (typescript) blind call-graph review, round 12

precision 48/50; census ≈99.39% (363 wrong of 59316 in-scope); recall: 0 missed of 44 real calls; 0 non-calls

(The 2 sample edges not counted correct are spec gaps, not wrong edges. 0 of 50 sampled edges are wrong.)

## Scope
Tool output: `<scans>/final13-A/s-vue.v2.json` (59,934 edges). In scope: edges whose `source_file` ends in `.ts/.tsx/.mts/.cts` and has no path segment named exactly `test`, `tests`, `spec`, `examples` or `docs`. Vue's `__tests__/`, `__benchmarks__/`, `packages-private/dts-test` and e2e folders are in scope under Decisions 2026-11-09. That leaves **59,316 in-scope edges in 458 files**. 618 `.js/.mjs` edges are excluded.
- By confidence: low 30,267 · high 18,916 · medium 7,415 · unknown 2,718.
- By call_type: direct 37,942 · method 17,521 · callback 2,718 · constructor 1,029 · implicit 106.
- About 14.6k of the low edges are vitest globals (`expect` 10,574, `test` 3,021, `it`, `describe`, …). They are not imported because `vitest.config.ts` sets `globals: true`, so they are bare names not found in the scan: low, direct, correct. Where vitest is imported, the tool emits `vitest.bench`, `vitest.vi.fn` and the like at medium, which is also correct.

Method: stratified sample with seed `20261112` (low 23, high 16, medium 6, unknown 5), spread over 43 files. Recall used 3 functions. The census was scripted. The helper scripts are `s-vue_r12_*.py` in the fanout folder, and the wrong-edge union is in `s-vue_r12_wrong_union.json`.

## Precision sample (50)
- 48 edges are correct on every field: real call, caller, callee, tier, call_type and line. They include:
  - 23 low vitest-global or `.toBe`-style guesses.
  - High imports through `@vue/runtime-test` / `vue` re-exports to the defining module.
  - Named nested functions: `Teleport.TeleportImpl.process.mountToTarget`, `hydration.createHydrationFunctions.hydrateElement`.
  - The alias `extend` → `Object.assign` (medium).
  - The function-type binding `runtime-core/src.warn` (medium).
  - Decision-A `Element#dispatchEvent` (medium).
  - Factory binding `vOn.isNonKeyModifier` (`makeMap` returns `(key) => boolean`; medium).
  - Callbacks through params and destructured locals.
- 2 are spec gaps (#38 and #40, below). 0 are wrong.

## Recall (3 functions, 44 calls)
| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| `packages/reactivity/src/dep.ts` `trigger` (294–389, incl. nested `run`) | 32 | 32 | 0 | 0 |
| `packages/runtime-core/src/scheduler.ts` `flushJobs` (273–327) | 6 | 6 | 0 | 0 |
| `packages/reactivity/src/effect.ts` `ReactiveEffect#run` (162–192) | 6 | 6 | 0 | 0 |

Every edge matched on callee, tier, call_type and line. Highlights:
- `WeakMap#get` is medium because `targetMap: WeakMap<…>` is declared.
- `depsMap.get`/`.has`/`.forEach` are low, because the binding is typed only by the lib `WeakMap#get` signature.
- `dep.trigger.run` is high. The `run` passed as a reference in `depsMap.forEach(run)` is correctly not an edge.
- `Dep#trigger` is high, through the `Dep | undefined` parameter.
- `check` is a callback: a local bound to a conditional, not to a function literal.
- `this.fn()` is the callback `fn`, unknown.

## Mismatch table
The sample spec gaps come first, then one hand-checked representative per census pattern.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| reactivity/src/arrayInstrumentations.ts:166 (sample #38) | `return apply(this, 'map', fn, thisArg, undefined, arguments)` | `…/arrayInstrumentations` → `…arrayInstrumentations.apply`, high, direct | callee right. Caller is `mod` or `mod.arrayInstrumentations.map`; undecided | spec gap | object literal wrapped in `<any>{…}` is not named |
| runtime-core/__tests__/components/Teleport.spec.ts:910 (sample #40) | `const target = nodeOps.createElement('div')` | `…Teleport.spec.runSharedTests` → `runtime-test/src/nodeOps.nodeOps.createElement`, medium, direct | undecided: `mod.nodeOps.createElement` medium, or alias target `mod.createElement` high | spec gap | shorthand property `{ createElement }` of a named object literal |
| runtime-core/src/scheduler.ts:330 | `const count = seen.get(fn) \|\| 0` | `…scheduler.checkRecursiveUpdates` → `CountMap#get`, medium, method | `type CountMap = Map<…>` names no type of its own: guess `seen.get` low (alias expansion would also give `Map#get`, never `CountMap#get`) | wrong callee / confidence | TS type alias used as the receiver type |
| compiler-sfc/src/script/resolveType.ts:318 | `return ctx.error(` | → `TypeResolveContext#error`, medium, method | `ctx.error` low (`TypeResolveContext` is a union alias). The ID is also unqualified, though the alias is declared in the scan | wrong callee / confidence | alias as type |
| vue-compat/__tests__/compiler.spec.ts:9 | `Vue.configureCompat({` | → `packages/runtime-dom/src.CompatVue#configureCompat`, medium, method | `Vue.configureCompat` low (`CompatVue` is an intersection alias, defined in runtime-core/src/compat/global.ts, not runtime-dom) | wrong callee (C1/C2) | alias as type, plus re-export path used as the defining module |
| vue-compat/__tests__/instance.spec.ts:154 | `vm.$emit('test', 1, 2, 3, 4)` | → `…compat/instance.LegacyPublicInstance#$emit`, medium, method | `vm.$emit` low (`type LegacyPublicInstance = ComponentPublicInstance & …`) | wrong callee / confidence | alias as type |
| vue-compat/__tests__/global.spec.ts:368 | `Vue.util.defineReactive(obj, 'test', 1)` | → `packages/vue-compat/src.Vue.util.defineReactive`, medium, direct | `util.defineReactive` low. `Vue = createCompatVue()` is not an object literal | wrong callee (C2 invented ID) | member path of a value binding named as a module member |
| compiler-sfc/src/script/definePropsDestructure.ts:217 | `!TS_NODE_TYPES.includes(parent.type)` | → `compiler-core/src/babelUtils.TS_NODE_TYPES.includes`, medium, direct | `Array#includes`, medium, method (`TS_NODE_TYPES: string[]`, which the tool itself resolves this way in babelUtils.ts:49) | wrong callee (C1/C2) | same as above, through an import |
| compiler-core/src/transforms/transformElement.ts:568 | `context.onError(` | → `compiler-core/src/transform.TransformContext#onError`, medium, method | `onError` is a function-valued property (`onError?: (error) => void`): callback `onError`, unknown (or a low guess through the mapped `Required<Omit<…>>`). Never `T#onError` method | wrong callee / call_type | function-valued property reported as a method (CAPABILITIES open defect typescript/03) |
| runtime-core/src/compat/global.ts:586 | `instance.emit('hook:beforeDestroy')` | → `…component.ComponentInternalInstance#emit`, high, method | `emit: EmitFn` property: callback `emit`, unknown | wrong callee / call_type / confidence | function-valued property as method |
| reactivity/src/ref.ts:311 | `return (this._value = this._get())` | `…CustomRefImpl#value` → `…CustomRefImpl#_get`, high, method | `this._get` is assigned a value (`this._get = get`): callback `_get`, unknown | wrong (open defect 03) | function-valued property as method |
| reactivity/src/effect.ts:300 | `;(e as ReactiveEffect).trigger()` | → `reactivity/src/effect.Subscriber#trigger`, medium, method | `Subscriber` declares no `trigger`. The cast names `ReactiveEffect#trigger` (high); at worst it is a low guess | wrong callee (C2 invented) | cast ignored, declared type of `e` used |
| runtime-core/src/renderer.ts:636 | `mountElement(` | `…baseCreateRenderer.processElement` → `mountElement`, low, direct | `…renderer.baseCreateRenderer.mountElement`, high (named nested function, declared at :672) | wrong callee / confidence | forward reference to a later nested `const f = () =>` is left unresolved (C2: depends on source order) |
| runtime-core/src/hydration.ts:132 | `hydrateNode(container.firstChild!, vnode, null, null, null)` | `…createHydrationFunctions.hydrate` → `hydrateNode`, low, direct | `…createHydrationFunctions.hydrateNode`, high | wrong callee / confidence | forward reference to a nested function |
| runtime-core/src/components/KeepAlive.ts:129 | `const storageContainer = createElement('div')` | → `createElement`, low, direct | callback `createElement`, unknown (destructured local `renderer: { o: { createElement } }`) | wrong call_type / confidence | locals from a nested destructuring pattern, or with a default (`setScopeId: hostSetScopeId = NOOP`), are emitted as bare names instead of callbacks; the same file's top-level `p: patch` in hydration.ts is a callback |
| runtime-core/src/hydration.ts:202 | `nextNode = nextSibling(node)` | → `nextSibling`, low, direct | callback `nextSibling`, unknown (`o: { …, nextSibling, … } = rendererInternals`) | wrong call_type / confidence | nested destructuring |
| packages-private/dts-test/component.test-d.ts:178 | `… = extractComponentOptions(MyComponent)` | → `extractComponentOptions`, low, direct | `packages-private/dts-test/component.test-d.extractComponentOptions`, medium (`declare function` at :16; the tool does this for `utils.expectType`) | wrong callee / confidence | in-file `declare function` not bound |
| server-renderer/src/helpers/ssrCompile.ts:92 | `Function('require', code)(fakeRequire)` | → `Function`, low, direct | `globalThis.Function`, medium (as the tool does for `Symbol()`, `String()`) | wrong callee / confidence | global called without `new` not qualified |
| vue-compat/__tests__/misc.spec.ts:260 | `(` … `.message as Function` … `)('draggable', null, 'false')` | → `.message`, low, method, line 260 | callback `message`, unknown, on line 262 (property holding a function) | wrong call_type / confidence / line | call of a parenthesised, cast property value |

## Systematic patterns (scripted census, ordered by count)
The patterns do not overlap. Each was checked by hand on 2 or more edges.

| # | pattern | edges | script |
|---|---|---|---|
| W1 | TS type alias (`type X = …`: union, intersection, `Map<…>`, `Pick<…>`, `Record<…>`) used as the receiver type, giving `X#m` medium. Includes 48 `packages/runtime-dom/src.CompatVue#*`, named through a re-export rather than the defining module. Top callees: `CompatVue#configureCompat` 24, `#extend` 16, `LegacyPublicInstance#$emit` 15, `TypeResolveContext#error` 12 (unqualified), `LegacyPublicInstance#$on` 10, `MergedParserOptions#*` 13, KeepAlive `Cache#*`/`Keys#*`/`MatchPattern#*` 14, `FS#*` 6, `VNodeTypes#hydrate` (ignores the `as typeof TeleportImpl` cast) | 165 | `s-vue_r12_census_alias.py` |
| W5 | locals from a nested destructuring pattern, or a destructured default, or a local `let`, called as bare low direct names instead of callback/unknown (hydration.ts `nextSibling` 14, `parentNode` 8, `insert` 6, `createText` 5; KeepAlive, Suspense, Teleport `o: {…}`; `hostSetScopeId`; `getSSRProps`; `hydrateNode!`; `update`) | 53 | `s-vue_r12_census_bare.py` |
| W4 | forward references to a named nested function declared later in the same enclosing function, emitted as bare low names (renderer.ts `baseCreateRenderer.*` 38, hydration.ts `createHydrationFunctions.*` 14, others). Backward references in the same functions resolve high | 59 | `s-vue_r12_census_bare.py` |
| W2 | function-valued properties (field/ctor-param/interface property with function type, or `this.x = fn`) called as `T#prop` method: `TransformContext#onError` 16, `ComponentInternalInstance#emit` 5, `SSRTransformContext#onError` 4, `DevtoolsHook#emit` 2, `ReactiveEffect#scheduler`, `WatchHandle#stop`, `ComputedRefImpl#fn/#setter`, `CustomRefImpl#_get/#_set`, `VueElement#_createApp`, `VNode#ce`, … (open defect typescript/03 and the stored-property callback rule) | 40 | `s-vue_r12_census_fnprop.py` |
| W6 | in-file `declare function` (body-less, top level) not bound: bare low instead of `mod.f` medium | 18 | `s-vue_r12_union.py` |
| W1b | invented member IDs on value bindings that are not object literals: `src.Vue.util.defineReactive` 5, `src.Vue#$on/$mount/$test` 3, `templateAnalysisCache.has/clear` 3, `TS_NODE_TYPES.includes` 2, `activeEffectScope.effects.push`, `currentBlock.push`, `attrValidationCache.hasOwnProperty` (C2) | 16 | `s-vue_r12_union.py` |
| W8 | `(obj[k].message as Function)(…)` emitted as `.message` low method on the `(` line, instead of callback `message` on its own line | 10 | `s-vue_r12_union.py` |
| W3 | cast ignored, so a member the declared type does not have is named: `Subscriber#trigger` | 1 | `s-vue_r12_census_fnprop.py` |
| W7 | global `Function(...)` called without `new`, left bare | 1 | `s-vue_r12_union.py` |
| | **union** | **363** | `s-vue_r12_union.py` → `s-vue_r12_wrong_union.json` |

Census precision = 1 − 363/59,316 ≈ **99.39%**.

Checks that found nothing:
- No empty or `<global>` callers.
- No high callee missing from `nodes`.
- The callee's name is on its line, except for import aliases (`compile` → `compileSFCScript` and the like, which are correct), the 10 W8 edges and the `X.prototype.m.call` second edge.

## Missed-call patterns (recall)
None in the three recall functions (0 of 44). The census turned up these related shortfalls, already counted above as wrong edges rather than missing ones:
- W4: calls emitted with the wrong ID instead of the nested function's.
- W6: `declare function` calls under the wrong ID.

## Spec gaps (counted separately, not wrong; 938 edges in all)
| # | construct (quoted) | edges | question SPEC leaves open |
|---|---|---|---|
| G2 | `export const nodeOps: { createElement: typeof createElement … } = { insert, remove, createElement, … }`, called as `nodeOps.createElement('div')`; likewise `compatUtils.isCompatEnabled` / `ssrUtils.*`, where `compatUtils = (__COMPAT__ ? _compatUtils : null) as typeof _compatUtils` | 589 | Is a call of a named object literal's member, whose value is a shorthand or identifier naming a scanned function, `mod.obj.prop` (medium, as function-type evidence) or the alias target `mod.createElement` (high)? The Alias rule and C1 are stated for top-level bindings only |
| G6 | `import { computed, ref, effect } from '../dist/reactivity.esm-browser.prod'` in `__benchmarks__` (the file does not exist in the scan) | 93 | For a relative import whose target is not in the scan, is the module named by the normalised scan path (`packages/reactivity/dist/reactivity.esm-browser.prod.computed`) or the specifier "as written"? |
| G7 | `const Vue: CompatVue = createCompatVue()` … `new Vue({ … })` | 83 | What is the constructor ID for `new X()` when `X` is a module-level value binding with a construct-signature type, not a class: `mod.X#<init>` (the tool's answer), a callback, or something else? |
| G3 | `export const trackSlotScopes: NodeTransform = (node, context) => { … context.removeIdentifiers(slotProps) }` | 79 | Is a parameter typed only contextually, through the binding's function-type alias annotation, "given by a declaration" for decision A (giving `TransformContext#removeIdentifiers`, high), or does it stay a low guess? |
| G4 | `new Collection([obj])` (a `describe.each` parameter), `const E = defineCustomElement(…); new E()` | 47 | Is `new` through a parameter or local holding a class a callback (unknown), a constructor of `x#<init>`, or something else? |
| G1 | `export const arrayInstrumentations: Record<string \| symbol, Function> = <any>{ __proto__: null, map(fn, thisArg) { … } }` | 42 | Does an object literal wrapped in a type assertion (`<any>{…}` / `{…} as T`) stay a named object literal, so its methods are `mod.arrayInstrumentations.map`, or fold into the module? |
| G5 | `getComputedStyle(el)`, `matchMedia(query)` | 4 | Are browser/DOM globals "Globals" (`globalThis.getComputedStyle`, medium) like the ECMAScript ones, or bare low guesses? The tool already treats `document.*` as medium |
| G8 | `const updateTeleports = (instance.ut = (vars = getter()) => { … })` | 1 | Is a local bound to an assignment expression whose value is a function literal a named nested function (high) or a medium binding? |
