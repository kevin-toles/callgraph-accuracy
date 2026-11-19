# h-mcp-servers (typescript): blind call-graph review, round 9

precision 45/50; census ≈99.0% (101 wrong of 10231 in-scope); recall: 0 missed of 35 real calls; 0 non-calls

(The other 5 of the 50 sample edges are spec gaps, not wrong: #10, #36, #46, #48 and #50. See "Spec gaps" below.)

## Scope
- Tool output: `<scans>/final12-A/h-mcp-servers.v2.json`, with 21078 edges in total. By extension: `.ts` 10231, `.mjs` 8852, `.py` 1993, `.js` 2. The `measured_accuracy` field was ignored.
- In scope: edges whose `source_file` is `.ts` and has no path segment named exactly test/tests/spec/examples/docs. `__tests__/` is not one of those segments, so it is in scope. That leaves **10231 edges in 109 files**. The `.mjs`/`.js`/`.py` edges are other languages and were ignored.
- By confidence: medium 5359, low 2709, high 2067, unknown 96.
- By call_type: direct 6405, method 3453, constructor 269, callback 96, implicit 8.
- By confidence and call_type together: medium/direct 4641, low/method 2709, high/direct 1764, medium/method 472, high/method 272, medium/constructor 246, unknown/callback 96, high/constructor 23, high/implicit 8.
- Sample: seed 9, stratified 24 medium / 12 low / 9 high / 5 unknown, spread over 32 files.
- Helper scripts are in the fanout folder: `h-mcp-servers_r9_load.py`, `_sample.py`, `_recall.py`, `_checks.py`, `_alias.py`, `_lowtyped.py`, `_lowdecl.py`, `_readonly.py`, `_fnprop.py`, `_destr.py` and `_census.py`. The census output is `h-mcp-servers_r9_census_out.json` and `h-mcp-servers_r9_g3.json`.

## Precision sample (50)
These 45 were judged correct: 1–9, 11–35, 37–45, 47 and 49.
- **Medium:** external imports as written (`vitest.expect`, `vitest.it.each`, `fs/promises.realpath`, `node:fs.rmSync`, `path.join` for `import path from "path"`, `zod.z.object`). Typed receivers (`Buffer[]` gives `Array#push`, `Map<…>` local gives `Map#delete`, a `McpServer` param or field gives `…McpServer#registerTool` / `#close`, `p: string` gives `String#slice`). Globals (`Object.assign`, `URL#<init>`).
- **Low:** `.toBe`/`.mockImplementation`/`.default` on computed receivers, `GetSumSchema.parse` (a zod value whose type is outside the scan), and `real.readdirSync` (`real` is an arrow parameter with no written type).
- **High:** imported helpers (`helpers.call`, `helpers.textOf`, `path-validation.isPathWithinAllowedDirectories`), file-local functions, and `KnowledgeGraphManager#createEntities` on `= new KnowledgeGraphManager(...)`.
- **Unknown:** `releaseOlder` (a local `let releaseOlder!: () => void` inside a test callback) and `requests` (a local destructured from an untyped helper result).
- **Spec gaps:** #10 (G2), #36 (G3), and #46, #48, #50 (G1).

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/sequentialthinking/__tests__/input-schema.test.ts:36 | `const result = await conn.think(args);` (`let conn: Connected`; `interface Connected { think: (args: …) => Promise<WireResult>; … }`) | input-schema.test → `src/sequentialthinking/__tests__/helpers.Connected#think`, high, method | `think`, unknown, callback. This is a call through a stored property holding a function. | wrong callee / confidence | Function-typed property signature treated as a method (P1) |
| src/filesystem/__tests__/server-tools.test.ts:73 | `await conn.close();` (`interface Connected { close: () => Promise<void> }`) | server-tools.test → `src/filesystem/__tests__/helpers.Connected#close`, high, method | `close`, unknown, callback | wrong callee / confidence | P1 |
| src/memory/__tests__/resource.test.ts:43 | `await conn.close();` (`interface Connection { close: () => Promise<void> }`) | resource.test → `src/memory/__tests__/helpers.Connection#close`, high, method | `close`, unknown, callback | wrong callee / confidence | P1 |
| src/filesystem/server.ts:887 | `options.onCannotOperate?.(error);` (`onCannotOperate?: (error: Error) => void;`) | createServer → `src/filesystem/server.ServerOptions#onCannotOperate`, high, method | `onCannotOperate`, unknown, callback | wrong callee / confidence | P1 |
| src/everything/__tests__/logging.test.ts:26 | `await session.close();` (`let session: Session`; `export type Session = { …; close: () => Promise<void> }`) | logging.test → `src/everything/__tests__/harness.Session#close`, medium, method | `close`, unknown, callback. Under the final5 reading a TS type alias names no type, so `Session#close` is not a valid ID in any case. | wrong callee / confidence | P1, here through a type alias |
| src/everything/__tests__/streamable-http.test.ts:418 | `await app.shutdown();` (`let app: StreamableHttpApp`; `type StreamableHttpApp = { …; shutdown: () => Promise<void> }`) | streamable-http.test → `src/everything/transports/streamableHttp.StreamableHttpApp#shutdown`, medium, method | `shutdown`, unknown, callback. The alias also names no type. | wrong callee / confidence | P1, through a type alias |
| src/everything/__tests__/harness.ts:74 | `options.setup?.(client);` (`export type ConnectOptions = { setup?: (client: Client) => void; … }`) | harness.connect → `ConnectOptions#setup`, medium, method | `setup`, unknown, callback. The tool's ID also drops the module qualifier: `ConnectOptions#setup` is a node with no `src/everything/__tests__/harness.` prefix (C1). | wrong callee / confidence | P1, through a type alias, plus an unqualified ID |
| src/filesystem/path-validation.ts:46 | `return allowedDirectories.some((dir) => {` (param `allowedDirectories: readonly string[]`) | isPathWithinAllowedDirectories → `allowedDirectories.some`, low, method | Typed receiver (decision A): `ReadonlyArray#some` (or `Array#some`; SPEC names neither), medium, method | wrong callee / confidence | `readonly T[]` param not typed (P2) |
| src/filesystem/lib.ts:116 | `.map((directory) => path.resolve(directory))` (on param `allowedDirectories: readonly string[]`) | respellAllowedDirectoryPrefix → `allowedDirectories.map`, low, method | `ReadonlyArray#map` (or `Array#map`), medium, method | wrong callee / confidence | P2 |
| src/filesystem/lib.ts:238 | ``: `Access denied - path outside allowed directories: ${absolute} not in ${allowedDirectories.join(", ")}` `` | validatePath → `allowedDirectories.join`, low, method | `ReadonlyArray#join` (or `Array#join`), medium, method | wrong callee / confidence | P2 |

## Systematic patterns (scripted counts, by count)
1. **P1: function-typed property signatures of scanned interfaces and type aliases are called as `T#prop`. 96 edges.** The construct is `prop: (…) => R` or `prop?: (…) => R` in an `interface` or `type X = {…}`, called through a receiver typed by that interface or alias. SPEC: a call through a stored property holding a function has the property's name as callee, callback, unknown. CAPABILITIES lists the same construct as open defect `typescript/03-known-gap-function-valued-props` (there written as `this.f()`).
   - By callee: `helpers.Connected#think` (sequentialthinking) 62 high; `harness.Session#close` 11 medium; `filesystem helpers.Connected#close` 7 high; `memory helpers.Connection#close` 6 high; `sequentialthinking helpers.Connected#close` 6 high; `StreamableHttpApp#shutdown` 2 medium; `ConnectOptions#setup` 1 medium; `ServerOptions#onCannotOperate` 1 high.
   - 14 of the 96 are typed through a TS type alias (`Session`, `StreamableHttpApp`, `ConnectOptions`). Those are wrong on a second ground too: under the final5 reading a type alias names no type of its own.
   - Hand-checked: input-schema.test.ts:36, server-tools.test.ts:73, resource.test.ts:43, server.ts:887, logging.test.ts:26, streamable-http.test.ts:418, harness.ts:74.
   - The script cross-checks these types' other members: real method declarations, such as class `StdioSession` in filesystem/__tests__/stdio.test.ts, are not counted.
2. **P2: receivers declared `readonly T[]` stay low guesses. 5 edges.** These are params `allowedDirectories: readonly string[]` in filesystem/lib.ts (116, 188, 238, 249) and path-validation.ts:46. Decision A types the receiver. A plain `T[]` declaration is typed correctly elsewhere (`Array#push` 46, `Array#map` 17 and so on). All 5 were checked by hand.

Union of wrong edges: 101. Census precision = 1 − 101/10231 = 0.9901.

## Missed-call patterns (recall)
| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| `src/filesystem/server.readFileAsBase64Stream` (server.ts:134–147) | 10: `new Promise`, `createReadStream`, `stream.on` ×3, `chunks.push`, `Buffer.concat`, `resolve`, `finalBuffer.toString`, `reject` | 10 | 0 | 0 |
| `src/filesystem/path-utils.convertToWindowsPath` (path-utils.ts:9–32) | 8: `startsWith`, `match` ×2, `charAt`, `.toUpperCase`, `slice`, `.replace`, `p.replace` | 8 | 0 | 0 |
| `src/memory.KnowledgeGraphManager#createRelations` (memory/index.ts:534–563) | 17: `withLock`, `loadGraphWithUnreadable`, `new Set`, `graph.entities.map`, `relations.forEach`, `entityNames.has` ×2, `new Error` ×2, `relations.filter`, `graph.relations.some`, `isSameRelation` ×2, `relations.slice`, `.some`, `graph.relations.push`, `saveGraph` | 17 | 0 | 0 |

- Tiers, IDs and lines were all correct. That includes the named nested function `KnowledgeGraphManager#createRelations.isSameRelation` (high) and the callbacks `resolve`/`reject`.
- `entities.map` (537), `relations.some` (552) and `relations.push` (560) are low guesses on `graph`, which is destructured from `this.loadGraphWithUnreadable()`. They fall under spec gap G3 and are not counted wrong.
- No missed-call pattern was found.

## Spec gaps (counted separately, not wrong)
- **G1: names bound from a dynamic `import()`. 36 edges.** Sample #46, #48, #50.
  - The constructs: `const { run, isEntryPoint } = await import("../index.js");` at top level (everything/__tests__/index.test.ts:28; filesystem/__tests__/win32.test.ts:13–15). The same inside functions (everything/index.ts:25 `const { startStdioServer } = await import("./transports/stdio.js");`; sse.test.ts:197; streamable-http.test.ts:472). And `let harness: typeof import("./harness.js")` (gzip-limits.test.ts:21).
  - The tool emits `mod.name` (top level) or a bare `name` (local), unknown, callback, plus `harness.connect` low.
  - Open question: SPEC rules on ESM `import` declarations and on CommonJS `require` bindings ("names bound from it resolve to the defining module"). It does not say whether a dynamic `import("literal")` is an import whose destructured or namespace bindings resolve to the defining module's IDs (C1). The alternative is a call result whose bindings are values with no evidence. It also does not say whether `import()` itself is an edge.
- **G3: receivers bound by object destructuring of a scanned declared type. 28 edges.** This is a scripted lower bound. Sample #36.
  - The constructs: `const { server, cleanup } = createServer();` (return type `ServerFactoryResponse = { server: McpServer; … }`); `const { graph, unreadable } = await this.loadGraphWithUnreadable();` (declared `Promise<{ graph: KnowledgeGraph; unreadable: string[] }>`); `const { excludePatterns = [] } = options;` (`options: SearchOptions`); `const { client } = session;` (`session: Session`).
  - The tool leaves calls on these bindings, and chains through them (`graph.entities.some`), as low guesses.
  - Open question: decision A lists "pattern binding" among typing declarations, and the let-bound and `Promise<T>` rules type a call result. SPEC does not say whether a TS object-destructuring binding takes the declared type of the matching property, including through an object type literal or a TS type alias (which "names no type of its own").
  - Destructuring from untyped helpers or external results (`const { tools } = await client.listTools()`) is not counted. Typing reaches only declarations in the scan, so low is correct there.
- **G2: a typed receiver whose method slot is reassigned in the same scope. 14 edges.** Sample #10.
  - The construct, in filesystem/server.ts:211–224: `const registerTool = server.registerTool.bind(server); server.registerTool = ((name, config, handler) => registerTool(…)) as typeof server.registerTool;`. After that, `server.registerTool(` at lines 255 onward is emitted as `@modelcontextprotocol/sdk/server/mcp.js.McpServer#registerTool`, medium, method.
  - Open question: SPEC rules "`this.x` assigned a value is a callback" only for `this.x`, and decision A types `server` as `McpServer`. It does not say whether assigning a function to `obj.m` on a typed local turns later `obj.m()` calls into calls through a stored property (callback) or leaves them `T#m`.
- **G4: a receiver bound to an `as T` cast. 5 edges.**
  - The construct, in everything/resources/subscriptions.ts:91 and 116: `const subscribers = subscriptions.get(uri) as Set<string>;`, then `subscribers.has` / `.delete` / `.add`, low.
  - Open question: decision A types receivers "by a declaration … or by `= new T(...)`". The JS/TS binding ruling counts an `as` cast only as function-type evidence. SPEC does not say whether `expr as T` gives the binding type T for receiver typing.
