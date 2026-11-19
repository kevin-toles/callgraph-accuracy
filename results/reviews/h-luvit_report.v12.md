# h-luvit (lua): blind call-graph review, round 12

precision 50/50; census ≈100% (0 wrong of 2896 in-scope); recall: 0 missed of 19 real calls; 0 non-calls

## Scope
Tool output: `<scans>/final13-A/h-luvit.v2.json`, 7845 edges (7819 `.lua`, 26 `.c`). I ignored the `measured_accuracy` field. In scope means `.lua` edges whose path below the scan root has no `test`/`tests`/`spec`/`examples`/`docs` segment. That leaves **2896 edges** in 48 files: deps/ 2743, bench/ 54, main.lua 45, init.lua 41, tools/ 13. Excluded: tests/ 4318 and examples/ 631.
- Confidence: medium 1299, high 930, low 557, unknown 110.
- call_type: direct 2012, method 774, callback 110.
- Split: medium/direct 1297, high/direct 639, low/method 481, high/method 291, unknown/callback 110, low/direct 76, medium/method 2.

CAPABILITIES.md (lua) lists no open defects and no unsupported constructs apart from skipped vendor/build directories. It lists two undecided questions: lua/14 (superclass extend, `X.super.new`) and lua/15 (module ID of a file no `require` names).

## Method
- **Precision sample:** seed 12, stratified by tier: medium 21, high 15, low 9, unknown 5. The sample covers 27 files. Script: `fanout/h-luvit_r12_sample.py`.
- **Census scripts** (all in fanout/, prefix `h-luvit_r12_`):
  - `calltype.py`: the Lua `:` vs `.` rule for method/direct. 0 mismatches; 74 lines with both forms skipped.
  - `line.py`: the callee name appears on the edge's line. The 71 lines where it does not are all alias calls (`strsub`, `pathJoin`, `c`, `recvStart`, `clearTimeout`); each was checked and each resolves correctly.
  - `highdef.py`: every high callee has a definition in the source, and every high callee is in `nodes`. 0 failures.
  - `override.py`: `self:m()` resolved to an ancestor while the caller's own type defines `m`. 0 cases.
  - `shadow.py`: high bare calls shadowed by a parameter or a non-function local. 0 cases; all hits were aliases or forward-declared local functions.
  - `miss.py`: per line, written call sites (identifier followed by `(`, a string or `{`) against edges. 2896 candidates matched 2896 edges, line by line.
  - `lowreq.py`: low guesses whose receiver is bound by `require`. All are `pcall(require, …)` bindings, dynamic module tables, or non-literal returns, and all are correct as low.
  - `gaps.py`: spec-gap counts.
- **Recall:** 3 functions in different files. Script: `recall.py`.

## Precision sample (50 edges)
All 50 are correct per SPEC: a real call, the right caller and callee IDs, the right tier and call_type, and the right line. The 50 include:
- **Builtins and standard library:** `_G#type`, `_G#load`, `table#insert`.
- **External require bindings:** `uv#…`, `env#get`, `luvi.bundle#readdir`.
- **Function-local `require` binding:** `lpeg#P` via `local P = g.P` (deps/json.lua:653).
- **Superclass resolution:** `Error:new` gives `core.Object#new` high (deps/dns.lua:658). `self:destroy()` gives `fs.ReadStream#destroy`.
- **Named nested functions** (forward-declared `local onData, incoming` and `local function reallyShutdown`), including a call inside an anonymous callback folded into `TLSSocket#destroy.shutdown`.
- **Low guesses:**
  - on untyped locals and parameters: `em.emit`, `bytes.byte`, `line.match`, `stream.on`;
  - on `pcall(require,'uv')` and `pcall(require,'openssl')` bindings: `uv.new_pipe`, `openssl.random`;
  - on the global `process.nextTick`.
- **Callbacks** through parameters and locals: `callback`, `cb`, `handledKey`.

## Mismatch table
No edge was judged wrong. The rows below are missed calls (recall) and representative spec-gap edges.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| deps/timer.lua:128 | `queue[i]()` | no edge | a call through an indexed value (C4: never dropped) | missed call | call through a computed callee is not emitted |
| deps/stream/stream_writable.lua:418 | `cbs[i](err)` | no edge | as above | missed call | same |
| deps/path/init.lua:28 | `return path._internal[key](path._internal, ...)` | no edge | as above | missed call | same |
| deps/readline.lua:488 | `return coroutine.wrap(onKey)(...)` | only `→ coroutine#wrap` | plus a call of the wrap result | missed call | call of a call result is not emitted |
| deps/repl.lua:193 | `end)()` (closes `coroutine.wrap(function () … end)()` at line 185) | only `→ coroutine#wrap` | plus a call of the wrap result | missed call | same |
| deps/repl.lua:47 | `local req, mod = require('require')(pathJoin(uv.cwd(), "repl"))` | `_G#require`, `luvi.path#join`, `uv#cwd` | plus a call of the module's returned function (deps/require.lua `return generator`) | missed call | same |
| main.lua:20 | `return require('./init')(function (...)` | only `_G#require` | plus a call of init.lua's returned function | missed call | same |
| main.lua:75 | `local repl = require('repl')(utils.stdin, utils.stdout)` | only `_G#require` | plus a call of repl.lua's returned function | missed call | same |
| main.lua:147 | `require('repl')(utils.stdin, utils.stdout, greeting, ...).start(lines, saveHistory)` | `_G#require`, `.start` | plus a call of repl.lua's returned function | missed call | same |
| deps/path/base.lua:46 | `filename = self:normalizeSeparators(filename)` | Path#_splitPath → `self.normalizeSeparators`, low, method | undecided | spec gap | method defined only on subclasses |
| deps/core.lua:184 | `return self.callback(...)` | core.onceMeta#__call → `self.callback`, low, direct | undecided | spec gap | function-valued instance field |
| deps/path/base.lua:367 | `return self.meta.super.getRoot(self, filepath)` | WindowsPath#getRoot → `super.getRoot`, low, direct | undecided (lua/14) | spec gap | luvit `meta.super` chain |
| deps/timer.lua:194 | `local now = Timer.now()` | timer.expiration → `timer.Timer#now`, medium, direct | undecided | spec gap | `Timer.now = uv.now` table-field alias |
| deps/dns.lua:156 | `local bytes = crypto.randomBytes(2)` | dns._gen_id → `crypto.randomBytes`, low, direct | undecided | spec gap | the required module has two conditional returns |
| deps/process.lua:232 | `process.stdin = require('fs').ReadStream:new(nil, {fd=0})` | process.globalProcess → `.new`, low, method | undecided | spec gap | in-place `require(...)` member chain |

## Systematic patterns (wrong edges)
None found. The census union of wrong edges is 0 of 2896.

## Missed-call patterns (recall)
- **Recall functions:**

  | Function | Real calls | Matched | Missed | Non-calls |
  |---|---|---|---|---|
  | `http.ServerResponse#finish` with nested `maybeClose` (deps/http.lua:178–201) | 8 | 8 | 0 | 0 |
  | `timer._insert` (deps/timer.lua:221–239) | 6 | 6 | 0 | 0 |
  | `childprocess.normalizeExecArgs` (deps/childprocess.lua:171–195) | 5 | 5 | 0 | 0 |

  Total: 19 real calls, 0 missed, 0 non-calls.
- **Call through a computed callee is not emitted** (scope-wide grep for `)(` and `](`): **9** missed calls, listed in the table above. They take two forms:
  - indexed callees: `queue[i]()`, `cbs[i](err)`, `path._internal[key](…)`;
  - calls of call results: `coroutine.wrap(f)(…)` twice, and `require('m')(…)` four times.

  C4 says an unresolved call is never dropped. SPEC gives no ID form for a callee without a name, so I report these as recall only. In deps/repl.lua:47 the target could be named: deps/require.lua returns `generator`.

## Spec gaps (counted separately, not wrong)
The union of the gap edges below is 138 of 2896.

1. **Module ID of a file no `require` names** (lua/15, still undecided): **112** edges. These are all edges in main.lua, bench/http-cluster/*.lua and tools/convert.lua. The tool uses `main`, `bench.http-cluster.worker` and `tools.convert`. Example: `main.lua:143 local lines = fs.readFileSync(historyFile) or ""` with caller `main`.
   - Open question: what is the module ID of an entry script that no require string names?
   - The callees on these edges were judged and are correct.
2. **`self:m()` where `m` is defined on no scanned ancestor:** **11** edges, all low `self.m`. These are 9 in deps/path/base.lua, 1 in core.lua and 1 in buffer.lua:
   - Path's template methods call `normalizeSeparators`, `isAbsolute` and `isDriveRelative`, which only PosixPath and WindowsPath define. Example: `self:isAbsolute(filename)`.
   - `self:addHandlerType(name)` in `Emitter:on`. It is guarded by `if self.addHandlerType`, and only subclasses define it.
   - `self:toString()` in `function Buffer.meta:__tostring()`.

   Open question: the ID rule says `self.m()` → `Type#m`, and C2 forbids medium/high IDs that are not defined. Should such a call be `Type#m` low, or the receiver guess `self.m` low?
3. **In-place `require('m').f()` / `require('m').T:f()` chains:** **9** edges. Examples:
   - `require("los").type()` gives `los.type`, high (3×);
   - `require('process').globalProcess()` gives `process.globalProcess`, high;
   - `require('fs').writeFileSync`;
   - `require('uv').run()` and `require('luvibundle').commonBundle` (2×), medium;
   - `require('fs').ReadStream:new(nil, {fd=0})` gives `.new`, low, while the bound form `fs.ReadStream:new` at deps/fs.lua:685 gives `core.Object#new`, high.

   Open question: SPEC resolves names *bound* from `require`. Does an unbound, in-place `require('m')` receiver resolve the same way, including through a field (`.ReadStream`)?
4. **Table-field alias of an external function:** **3** edges. `Timer.now = uv.now` (deps/timer.lua:81), then `Timer.now()` gives `timer.Timer#now`, medium. A table-field alias of a *scanned* local (`Socket.recvStart = start_listening`) resolves to its target.
   - Open question: the Lua alias ruling covers `local`/`const` aliases. Does `T.f = ext.g` resolve to `ext.g`'s ID (`uv#now`), or keep `mod.T#f`?
5. **`self.f(...)` dot-call of a function-valued instance field** (a field, not a method): **3** edges, low direct `self.x`:
   - `self.callback(...)`, where the field is set in a `setmetatable({callback = callback}, onceMeta)` constructor;
   - `self.completionCallback(...)`, set in `Editor.new`'s table constructor;
   - `self._flush(...)`, never assigned in the scan.

   By contrast, `self.encode(...)` with `self.encode = encode` gives `encode`, unknown, callback.
   - Open question: is a dot-call through a field that a table constructor sets (or that is never assigned) a stored-property callback (callback, unknown), `Type#f`, or the receiver guess `self.f`?
6. **`self.meta.super.m(self, …)`** (luvit's superclass call): **1** edge, deps/path/base.lua:367 → `super.getRoot`, low.
   - Open question (related to lua/14): is this `path.base.Path#getRoot` (the superclass is scanned), or `super.getRoot` low?
7. **A required module with conditional returns:** **1** edge. deps/tls/lcrypto.lua ends with `if … then return { randomBytes = randomBytesOpenSSL } else return { randomBytes = randomBytesInsecure } end`, and `crypto.randomBytes(2)` in dns.lua gives `crypto.randomBytes`, low.
   - Open question: the C2 reading makes a returned table's fields module members. Which target, or both, when two returns bind the same field to different functions?

## Unscored observation
`nodes` contains inherited-name IDs with no definition behind them, for example `net.Socket#push`, `net.Socket#emit` and `fs.WriteStreamSync#destroy`. No in-scope edge targets them, so I did not score them.
