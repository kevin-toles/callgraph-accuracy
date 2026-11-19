# koa call-graph review (v3)

**precision 50/50; census ≈99.7% (1 wrong of 339 in-scope); recall: 0 missed of 20 real calls; 0 non-calls**

**Scope.** The tool emitted 3974 edges. 339 of them are in `lib/*.js` and are in scope: 68 high, 143 medium, 124 low and 4 unknown. The rest are test code (`__tests__/`, `test-helpers/`) and are excluded. All 339 in-scope edges were read against the source lines, not only the sample. A scripted scan of every call site in `lib/` (`koa_v3_missed.py`) found no call without an edge.

**Sample.** `koa_v3_sample.py` drew the sample with seed `20261028`: 10 high, 20 medium, 16 low and all 4 unknown edges. The spec asks for at least 15 files, but in-scope edges exist in only 6 files (`only.js` has none), so the sample covers 5. All 50 edges are correct. Seven of them are `require(...)` edges (spec gap G1). They count as passes, not as errors.

**Recall.** I checked three functions, none of which the v2 review used.
- `Application#callback` (application.js:182–198), including its named nested arrow `Application#callback.handleRequest`: 7 of 7 calls found. `this.compose(...)` is a callback on an assigned `this.x`. `listenerCount` and `on` are inherited from `node:events` and correctly come out medium.
- `lib/request.host` (request.js:251–270): 6 of 6 found.
- `lib/response.redirect` (response.js:315–336): 7 of 7 found. The setter assignments `this.status=`, `this.type=` and `this.body=` are correctly not emitted as calls.

Helper scripts are in the fanout folder: `koa_v3_load.py`, `koa_v3_sample.py`, `koa_v3_census.py`, `koa_v3_missed.py` and `koa_v3_accessors.py`. `koa_v3_lib_edges.txt` holds the in-scope edge dump.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| context.js:151 | `this.set(name, headers[name])` | `lib/context.onerror` → `.set`, low, method | `this.m()` → `Type#m`, so `lib/context.set`. It stays low, because `set` is not defined in context.js; `delegates` adds it at runtime (lines 201/207). | wrong callee | `this` inside an arrow in an object-literal method is treated as an unknown receiver when the member is not defined in the object |
| application.js:19 (and 47 more) | `const request = require('./request')` | `lib/application` → `require`, medium, direct, is_external | The spec does not say whether `require(...)` is a call edge. If it is one, `./request` is in the scan and should not be `is_external`. | spec gap | n/a |
| response.js:447 vs 459 | `set etag (val) {` / `get etag () {` | Both accessors have caller `lib/response.etag` | The spec has no JS ID for getter and setter accessors. C# uses `Prop` / `Prop=` and Ruby uses `x=`. | spec gap | n/a |

## Systematic patterns

Ordered by count. Only pattern 4 is a counted error. Patterns 1–3 are spec gaps and are not in W.

1. **`require(...)` emitted as a call edge: 48 edges (spec gap G1).** Every `require` in `lib/` produces `require`, medium, direct, is_external. Nine of them load in-scan modules and are still flagged `is_external`: application.js:19–23, request.js:13 and 17, response.js:21–22.
2. **Getter and setter pairs share one caller ID: 7 IDs, 31 edges (spec gap G2).** `koa_v3_accessors.py` found: `lib/request.path` (1 get + 2 set), `query` (1+1) and `querystring` (1+2); `lib/response.length` (8+2), `type` (2+3), `lastModified` (2+3) and `etag` (1+2).
3. **`is_external` missing on medium out-of-scan callees: 20 of 95 non-`require` medium edges (spec gap G3).** 75 carry the flag. The 20 without it are every constructor edge (`node:events#<init>`, `node:async_hooks.AsyncLocalStorage#<init>`, `TypeError`/`Error`/`Date`/`URL#<init>`, `url.URL#<init>` ×3, `url.URLSearchParams#<init>` ×2, `cookies#<init>`), the 3 typed-receiver edges `url.URLSearchParams#toString`/`keys`/`getAll`, and the 2 inherited `Application#listenerCount` / `Application#on`.
4. **`this.m()` on a runtime-mixed-in member emitted as `.m`: 1 edge (wrong callee).** context.js:151 is the only one. `koa_v3_census.py` checks every leading-dot callee whose source line has `this.<m>(`. No `this.`-prefixed callees exist, and no edges have an empty or `<global>` caller.

## Spec gaps

- **G1. Whether `require(...)` is an edge.** The JS notes say "Imports, `require` … resolve to the defining module" and "Import statements are not calls". They do not say whether the `require()` call itself is an edge, or whether a `require` of an in-scan module is external. 48 edges are affected, 9 of them in-scan.
- **G2. JS accessor IDs.** There is no JS rule that separates `get x` from `set x`, so both share `mod.x`. 7 IDs and 31 edges are affected.
- **G3. `is_external` semantics.** The spec says only "appears only when true". The tool omits it on constructors, typed-receiver methods and inherited external methods. 20 edges are affected.
- **G4. `module.exports = class Application extends Emitter`.** The spec defines `module.exports = fn` → `mod.default` and the exported object → `mod`, but not an exported named class. The tool uses `lib/application.Application#m` for 40 caller edges and 7 callee edges. I judged this correct, since the JS notes use the `src/app.C#m` form, but it is not explicit.

## Previous findings

These are the mismatch-table rows and systematic patterns of `koa_report.v2.md`, judged against the current tool output.

| v2 item | status | count now (v2 count) |
|---|---|---|
| Mismatch row: context.js:151 `this.set` → `.set` (wrong callee) | **still present** | 1 (1) |
| Mismatch row: `require()` emitted as an edge (spec gap) | **still present**, still a spec gap | 48 edges, 9 in-scan flagged `is_external` (48 / 9) |
| Mismatch row: getter and setter accessors share one ID (spec gap) | **still present**, still a spec gap | 7 IDs / 31 edges. v2 said 6 IDs: it left out `lib/response.etag`, which has edges in both accessors (448/449 set, 460 get). |
| Pattern 1: `require()` emitted as a call (48) | **still present** | 48 |
| Pattern 2: `is_external` inconsistent on medium external callees (18 + 2 inherited) | **still present** | 20 without the flag vs 75 with it. Same split as v2: 18 external + 2 inherited. |
| Pattern 3: getter/setter pairs share one ID (6 IDs) | **still present** | 7 IDs, recounted by script (see above) |
| Pattern 4: `this.m()` on a runtime-mixed-in member → `.m` (1) | **still present** | 1 |

The in-scope edge counts per tier (68/143/124/4) are identical to v2, and no v1 regressions reappear: 0 `module<...>` callees, 0 low-confidence JS globals, and 0 empty or `<global>` callers.
