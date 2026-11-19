# zod (typescript): call-graph re-review (v3)

**precision 50/50; census ≈97.7% (236 wrong of 10,276 in-scope); recall: 0 missed of 50 real calls; 0 non-calls**

## Scope and method

The JSON has 51,109 edges. I kept 10,276. I dropped `.d.ts` files, `*.test.ts`/`*.spec.ts`, and anything under `__tests__/`, `tests/`, `test/`, `docs/`, `examples/`, `fixtures/` (integration test fixtures) and `vendor/`.

This scope is wider than v2's 6,990 edges. v2 also dropped `packages/bench` and `packages/integration`, and the spec does not list either. The census numbers are therefore not directly comparable to v2's sample numbers.

By confidence, the in-scope edges are 4,775 high, 2,667 low, 2,522 medium and 312 unknown.

**Precision sample.** I drew 50 edges with `random.seed(20261028)`: 21 high, 12 medium, 12 low and 5 unknown, with at most 3 per file, across 36 files. The script is `zod_v3_sample.py`.
- All 50 are correct per spec.
- One is a spec gap that I counted as correct: #36, scripts/write-stub-package-jsons.ts:38 `results.push(...)` with `const results: string[] = []`, which the tool gives as `results.push` low.
- Checked and right: callers for top-level code (module ID), named nested functions (`memoizer.memo.attach.wrapped`), field-initializer implicit edges (`safe.ZodFail#<init> → #status`), workspace `zod` imports (`z.strictObject` → `…v4/classic/schemas.strictObject` high), constructor-holding locals (`new _String(` → `_String` callback/unknown), and chain lines (triage-signal.ts:375 `.replace` on its own line).

**Recall.** All calls were found in all three functions:
- `v4/core/json-schema-processors.rewriteKeyNames` (lines 590-614): 13 of 13. Three of them have the wrong callee; see pattern 2.
- `v4/core/doc.Doc#write` (lines 23-37): 13 of 13.
- `v3/types.ZodNumber#_parse` (lines 1370-1453): 24 of 24.

**Census.** The scripts are `zod_v3_barrel.py`, `zod_v3_typedchain2.py`, `zod_v3_census.py`, `zod_v3_newcensus.py`, `zod_v3_super.py`, `zod_v3_nameonline.py`, `zod_v3_newlocal.py` and `zod_v3_nsimport.py`.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| v4/classic/schemas.ts:390 | `core.$ZodString.init(inst, def);` | `…classic/schemas → packages/zod/src/v4/core.$ZodString.init`, medium, method | The defining module, not the `core/index.ts` barrel. The same-file form `ZodType.init(inst, def)` gives `…v4/core/core.$constructor#init` high (sample #16, #18). This one should match that, or at least be `…v4/core/schemas.$ZodString.init` | wrong callee + wrong confidence | `export *` from a namespace import's barrel not followed |
| v4/classic/schemas.ts:2780 | `const ch = new core.$ZodCheck({` | `→ packages/zod/src/v4/core.$ZodCheck#<init>`, medium, constructor | `…v4/core/checks.$ZodCheck#<init>` (ID of a factory-made constructor: spec gap) | wrong callee | barrel not followed |
| scripts/compile-fuzz.ts:41 | `() => ({ schema: z.coerce.number(), …` | `→ packages/zod/src.coerce.number`, medium | `…v4/classic/coerce.number`, high (`export * as coerce` resolves to the defining module) | wrong callee + wrong confidence | `export * as` sub-namespace not followed |
| scripts/compile-fuzz.ts:360 | `got = fast.safeParse(input);` (`fast: z.ZodType`) | `→ packages/zod/src.ZodType#safeParse`, medium | `…v4/classic/schemas.ZodType#safeParse`, high | wrong callee + wrong confidence | type reached through the barrel |
| packages/bench/discriminated-union.ts:21 | `z3.object({` (`import * as z3 from "zod/v3"`) | `→ packages/zod/src/v3.object`, medium | defining module `…v3/types` (export alias `objectType as object`), high | wrong callee + wrong confidence | barrel not followed |
| v4/core/json-schema-processors.ts:593 (recall) | `for (const entry of ctx.seen.values()) {` (`function rewriteKeyNames(ctx: ToJSONSchemaContext)`, `seen: Map<schemas.$ZodType, Seen>`) | `…rewriteKeyNames → seen.values`, low | `Map#values`, medium (typed receiver via a property chain of a declared type) | wrong callee + wrong confidence | declared property type not followed through `param.field` |
| v4/core/to-json-schema.ts:274 | `ctx.metadataRegistry.get(schema)` (in `processSchema(…, ctx: ToJSONSchemaContext, …)`) | `→ metadataRegistry.get`, low | `…v4/core/registries.$ZodRegistry#get`, high | wrong callee + wrong confidence | same |
| v4/core/compile.ts:274 | `ctx.constants.set(name, value);` (`function addConstant(ctx: CompileContext, …)`) | `→ constants.set`, low | `Map#set`, medium | wrong callee + wrong confidence | same |
| v4/core/memoizer.ts:203 | `let bucket = state.buckets.get(inst);` (`function bucketFor(state: State, …)`) | `→ buckets.get`, low | `Map#get`, medium | wrong callee + wrong confidence | same |
| write-stub-package-jsons.ts:38 (sample #36) | `results.push(relativePath \|\| ".");` (`const results: string[] = []`) | `→ results.push`, low | The spec does not say whether a `T[]` annotation is a typed declaration. `Array<…>` annotations give `Array#push` medium | spec gap | — |
| v4/classic/from-json-schema.ts:512 | `stringSchema = stringSchema.check(z.email());` (`let stringSchema: ZodString`) | `→ …classic/schemas.ZodString#check`, medium | `check` is declared on supertype `ZodType` (in scan). `zodSchema: ZodType` → `ZodType#check` high at line 746. The superclass rule covers only `this.m()` | spec gap | — |
| v4/util.ts:951 | `if (traits?.has("$ZodType")) {` (`const traits: Set<string> \| undefined`) | `→ traits.has`, low | The declared type is a nullable union. The spec does not say whether `T \| undefined` counts | spec gap | — |
| v3/types.ts:1455 | `static create = (params?: …): ZodNumber => {` | no implicit `<clinit>` edge (but `static create = createZodEnum` at 4160 gets one) | The spec does not say whether an arrow-valued class field is a method-like definition or a non-lazy initializer | spec gap | — |
| packages/bench/compile-base64-inline-vs-hoist.ts:17 | `const manualHoisted = new F(` (`const F = Function;` at module level) | `→ …compile-base64-inline-vs-hoist.F#<init>`, medium | The local form in util.ts:530 is `F` callback/unknown. The spec says "local variable" and does not cover a module-level alias of a global constructor | spec gap | — |

## Systematic patterns (by census count)

1. **Callees named through a barrel `index.ts` instead of the defining module: 197 edges, all medium.** Counted by `zod_v3_barrel.py`: the callee's module is a directory with `index.ts`, no same-named `.ts` exists, and the symbol is not declared in the index.
   - `core.$ZodXxx.init(inst, def)` in v4/classic/schemas.ts, v4/mini/schemas.ts and v4/mini/iso.ts: 151.
   - `packages/zod/src/v3.*` from `import * as z3 from "zod/v3"` in bench: 22.
   - `packages/zod/src.*` (`z.iso.datetime`, `z.coerce.number`, `ZodType#safeParse`): 10.
   - Other `packages/zod/src/v4/core.*` (`core.util.constantCatch`, `core.globalRegistry.add/get`, `compileFastpass`): 9.
   - `packages/zod/src/v4.parse`: 2.
   - `core.$ZodCheck#<init>`: 2.
   - `packages/zod/src/mini.locales.en`: 1.

   The spec says `export *` and `export * as` re-exports resolve to the defining module. All of these targets are in the scan, so confidence should be high.
2. **Typed receiver through a property chain not resolved (`ctx.seen.get`, `ctx.refs.has`, `ctx.constants.set`, `state.buckets.get`, `ctx.metadataRegistry.get`): 39 edges, all low.** Counted by `zod_v3_typedchain2.py`. It counts `root.prop.m(` where the nearest binding of `root` is a parameter or const with an annotation naming an in-scan interface or class, and that interface declares `prop` with a named class type (`Map`, `Set`, `$ZodRegistry`).
   - Breakdown: `ToJSONSchemaContext.seen` 18, `ConversionContext.refs` 5, `.processing` 3 and `.registry` 1, `ToJSONSchemaContext.metadataRegistry` 4, `CompileContext.constants` 6, `State.buckets` 2.
   - This is a lower bound: deeper chains such as `ctx.external.registry.get` are not counted.
   - Plain typed locals and parameters are resolved: `= new T()` locals have 0 misses (`zod_v3_newlocal.py`), and `doc: Doc` gives `Doc#write` high ×186. `this.field` with a `= new Map()` initializer also resolves (registries.ts:40 `Map#set`).

Census precision: 1 − 236/10,276 ≈ 97.7%.

## Spec gaps (counted separately, not wrong)

- **`T[]` annotations** (`const L: string[]`, `payload.issues` with `issues: $ZodRawIssue[]`): about 269 local/parameter edges plus 30 property-chain edges, all low.
- **Primitive annotations** (`s: string`, `val: number`, `title: string` → `title.replace` low): 79.
- **Factory-made constructors** (`export const ZodObject = core.$constructor(...)`; `new ZodObject(def)` → `…schemas.ZodObject#<init>` medium): 102 edges. The ID and confidence for these are not defined by the spec.
- **Spread members of a named object literal** (`const z = { ..._schemas, ..._checks }` in from-json-schema.ts → `…from-json-schema.z.url` medium): 68.
- **Typed receiver whose member is declared on an in-scan supertype** (`ZodString#check`/`#min`/`#max`/`#regex` medium): 28.
- **Function-valued consts that are not function literals** (`util.objectKeys` 8 and `util.isInteger` 2, which are conditionals; `parse.parse`/`parseAsync` 4, which are call results): all medium direct/method, 14 in total.
- **Arrow-valued class fields with no implicit `<clinit>` edge**: 14 (v3/types.ts `static create = (…) =>`).
- **Nullable-union declarations** (`Set<…> | undefined`, `z.ZodType | null`): 7.
- **Type-alias receivers** (`ParsePath#push` 2, `util.Literal#toString` 1): 3.
- **Module-level `const F = Function`** → `F#<init>` medium: 3.

## Previous findings

1. **Regression: `new X(...)` with no edge (v2: 177 lines). Fixed.** `zod_v3_newcensus.py` finds 0 real `new X(` lines without an edge in non-test `packages/zod/src`. The 6 hits it reports are inside strings, comments or code-generation template literals.
   - Through a parameter or local (v2: 97): fixed. `Class` callback/unknown ×84 (api.ts:407 `_cidrv4 → Class`), `Definition` ×3 (core.ts:39/42/48), `F` ×6 (util.ts:530), `This` (types.ts:516), `_String`/`_Boolean`/`_Codec` ×1 each.
   - Same-file `$constructor` factory consts (v2: 76): fixed. Every `new Zod…(` line in classic/schemas.ts and mini/schemas.ts now has an edge, for example mini/schemas.ts:1767 `readonly → …mini/schemas.ZodMiniReadonly#<init>` medium. The ID is still a spec gap (102 edges, above).
2. **Namespace import IDs go through the barrel module. Still present, now counted at 197 edges** (pattern 1). v2 saw 2 instances and did not count it. classic/schemas.ts:2780 `core.$ZodCheck#<init>` is unchanged.
3. **Spec gap: spread members of `z` in from-json-schema.ts.** Unchanged: 68 edges `…from-json-schema.z.*` medium, including line 514 `z.url`.
4. **Spec gap: `T[]` declarations (`pairs.push`, `formErrors.push`).** Unchanged: types.ts:2514 and errors.ts:334 are still low. The current spec still does not cover `T[]`.
5. **Spec gap: type-alias receiver `ParsePath#push`.** Unchanged: types.ts:77/79 are still `…parseUtil.ParsePath#push` medium.
6. **Spec gap: conditional const `util.objectKeys`.** Unchanged: 8 edges medium.
7. **v1 findings that v2 reported fixed. Still fixed.**
   - Inherited `this.m()` in v3: `ZodType#_getOrReturnCtx` 51/51, `#_processInputParams` 17/17, `#_getType` 13/13 and `#parse` 2/2, all high.
   - Low edges through relative `import * as X`: 0.
   - `errorUtil.*`: 57/57 high.
   - v3 low `util.`/`errorUtil.` edges: 0.
