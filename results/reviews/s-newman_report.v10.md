# Blind call-graph review: s-newman (javascript), round 10

precision 50/50; census ≈97.9% (25 wrong of 1171 in-scope); recall: 1 missed of 63 real calls; 0 non-calls

## Scope
Tool output `<scans>/final12-A/s-newman.v2.json` has 4064 edges, all `.js`. The in-scope edges are the ones whose source file has no `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment: **1171 edges** across 30 files (`lib/`, `bin/`, `npm/`, `index.js`, `.nycrc.js`).
- Confidence: medium 656, low 306, high 110, unknown 99.
- call_type: direct 671, method 351, callback 99, constructor 50.

I ignored the `measured_accuracy` field. Helper scripts are in the fanout folder:
- `s-newman_r10_load.py`
- `s-newman_r10_sample.py` (seed 10)
- `s-newman_r10_dump.py`
- `s-newman_r10_ctx.py`
- `s-newman_r10_census.py`

## Precision sample (seed 10)
The sample has 50 edges: medium 27, low 13, high 5, unknown 5. They span 18 files. None of the 50 is wrong.

12 sample edges touch a spec gap. They are counted as not wrong.
- **Var-assign binding (G1), 11 edges:** samples 11, 17, 21, 27, 29, 30, 39, 40, 41, 43 and 45. Each has a caller or callee that is a `var X; X = function` binding, the undecided case `javascript/16`.
- **`tty` require binding (G4), 1 edge:** sample 32.

The other sample edges match SPEC on caller, callee, tier, call_type and line. They cover these kinds of call:
- `require` loader calls
- lodash and other external calls named by the specifier
- globals (`console.warn`, `Date.now`, `globalThis.Boolean`)
- typed receivers (`events#emit`, `cli-progress.Bar#<init>`)
- receiver guesses (`query.get`, `.option` in a chain)
- in-scan calls (`lib/util.prettyms`, `lib/run/secure-fs.stripTrailingSep`)
- callbacks through parameters

## Mismatch table (every wrong edge pattern; the census found all of them, none came from the sample)
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/reporters/cli/index.js:98 | `print(LF + PostmanCLIReporter.parseStatistics(run.stats, …) + LF);` | PostmanCLIReporter → `lib/reporters/cli.parseStatistics`, medium, direct | `PostmanCLIReporter.parseStatistics`, low, method. The member is added through `_.assignIn(PostmanCLIReporter, {…})`. That object literal is anonymous, so its methods fold into the module, and no `mod.parseStatistics` definition exists (C2) | wrong callee | members added by `_.assign`/`_.assignIn` get an invented module ID |
| lib/run/summary.js:192 | `RunSummary.attachTimingTrackers(this, emitter);` | RunSummary → `lib/run/summary.attachTimingTrackers`, medium, direct | `RunSummary.attachTimingTrackers`, low, method (`_.assign(RunSummary, {…})`) | wrong callee | same as the row above |
| lib/reporters/cli/index.js:324 | `pad(this.summary.run.failures.length, 3, SPC)` with `pad = cliUtils.padLeft` at the top level | → `lib/reporters/cli.pad`, unknown, callback | `lib/reporters/cli/cli-utils.padLeft`, high, direct. Under the Alias rule the binding names a scanned function | wrong callee/confidence/call_type | the alias of a member of a required scanned object is not resolved |
| lib/run/index.js:179 | `fileResolver: new SecureFS(options.workingDir, …)` | default → `lib/run/secure-fs#<init>`, medium, constructor | `lib/run/secure-fs.SecureFS#<init>`, high. `module.exports = SecureFS` exports the declared binding (C1; golden javascript/17) | wrong callee/confidence | `module.exports = Name` is collapsed into the module ID |
| lib/run/index.js:153 | `emitter.summary = new RunSummary(emitter, options);` | default → `lib/run/summary#<init>`, medium, constructor | `lib/run/summary.RunSummary#<init>`, high. Both readings of the var-assign question give the binding ID `mod.RunSummary` | wrong callee/confidence | same as the row above |
| npm/test-cli.js:49 | `!module.parent && module.exports(process.exit);` | npm/test-cli → `module.exports`, low, method | `npm/test-cli.default`, high, direct. `module.exports = function (exit)` in the same file is `mod.default` (C1) | wrong callee | a self-reference through `module.exports` is not resolved |
| npm/test-integration.js:15 | `echoServer = require('./server').createRawEchoServer(),` | npm/test-integration → `.createRawEchoServer`, low, method | `npm/server.createRawEchoServer`, high, direct. The literal `require` of a scanned module resolves to its IDs | wrong callee | a member call made in place on a literal `require(...)` is not resolved |
| bin/newman.js:77 | `newman.run(options, …)` with `newman = require('../')` | bin/newman → `newman.run`, medium, direct | `lib/run.default`, high, direct. The chain is `index.js` `module.exports = require('./lib')`, then `lib/index.js` `{ run: require('./run') }`, then `lib/run` `module.exports = function` | wrong callee/confidence | the re-export chain is not followed, and the ID is invented (C2) |
| lib/run/secure-fs.js:175 | `this.emit('error', new Error(PPERM_ERR));` inside `const ErrorReadStream = function () {…}` | ErrorReadStream → `lib/run/secure-fs.SecureFS#emit`, medium, method | not SecureFS. `this` is the new ErrorReadStream, which inherits Readable through `util.inherits`. SecureFS defines no `emit`, so the ID is invented (C2). The correct callee is a receiver guess, low | wrong callee | `this` inside a nested constructor function is bound to the outer prototype type |
| lib/run/secure-fs.js:178 | `(options && !options.autoClose) \|\| this.destroy();` | → `lib/run/secure-fs.SecureFS#destroy`, medium, method | same as the row above | wrong callee | same as the row above |
| lib/run/secure-fs.js:183 | `return new ErrorReadStream();` | → `lib/run/secure-fs.SecureFS#createReadStream.ErrorReadStream`, high, constructor | `…ErrorReadStream#<init>` (a constructor call is `Type#<init>`) | wrong callee | `#<init>` is missing from the ID |

## Systematic patterns (scripted counts; each validated by hand against the source lines listed by `s-newman_r10_census.py`)
1. **P1, 7 edges.** Statics added by `_.assign`/`_.assignIn(Fn, {…})` get the invented ID `mod.member` at medium: `parseStatistics`, `parseFailures` and the five `RunSummary.attach*` calls.
2. **P4, 6 edges.** `module.exports(process.exit)` in the six `npm/test-*.js` scripts is left as the low guess `module.exports`, where it should be `mod.default`, high.
3. **P2, 4 edges.** The top-level alias `pad = cliUtils.padLeft` is emitted as `lib/reporters/cli.pad`, callback, unknown, where it should be `lib/reporters/cli/cli-utils.padLeft`, high, direct.
4. **P3, 2 edges.** `new X()` of a scanned `module.exports = X` constructor becomes `mod#<init>`, medium, where it should be `mod.X#<init>`, high.
5. **P5, 2 edges.** In-place `require('./server').f()` is left as the low guess `.f`.
6. **P7, 2 edges.** `this.m()` inside the nested constructor `ErrorReadStream` becomes `SecureFS#m`.
7. **P6, 1 edge.** `newman.run` uses a module ID that is not in the scan (the root `index.js`) instead of following the re-export to `lib/run.default`.
8. **P8, 1 edge.** A constructor callee is missing `#<init>`.

The union is 25 wrong edges. Census = 1 − 25/1171 = **97.9%**.

## Missed-call patterns (recall)
I checked three functions:

| Function | Real calls | Missed | Non-calls |
|---|---|---|---|
| `lib/util.fetchJson` (lib/util.js:155-224) | 41 | 0 | 0 |
| `lib/run/secure-fs.SecureFS#createReadStream` (lib/run/secure-fs.js:164-185) | 8 | 0 | 0 |
| `lib/config.get` (lib/config/index.js:21-64) | 14 | 1 | 0 |

`createReadStream` has all 8 edges, with the calls inside `ErrorReadStream` correctly given that nested function as caller. Two of them are wrong (P7), and the constructor edge is wrong (P8).

The miss in `lib/config.get` is a call through a computed callee: `loaders[name](value, commonOptions, cb)` (line 61) gets no edge at all, which goes against C4. A grep of the in-scope sources finds no other computed-callee call, so the total is **1 missed call**. In total: 1 missed of 63 real calls, and 0 non-calls.

## Spec gaps (counted separately, not wrong; 316 edges in the union)
- **G1, 286 edges.** The construct is `var PostmanCLIReporter, …; PostmanCLIReporter = function (emitter, …) {…}`. The same form is used by `print`, `SmileyReporter`, `ProgressReporter`, `RunSummary`, `JunitReporter`, `extractSNR` and `symbols`, and by the members stored on `print` (`print.lf = function`, `print.print = function`).
  - CAPABILITIES lists this as undecided (`javascript/16-known-gap-var-assign`). The open question: is such a binding a function-literal binding, with calls inside it having caller `mod.X`, or a no-evidence binding whose body folds into the module?
  - Further question: are functions stored on it (`print.lf = function`) `mod.print#lf` or something else? This also decides whether `print.print.apply(this, arguments)` is `Function#apply` plus a target, or a receiver guess.
  - The 286 edges have a caller, or a callee, that is one of these bindings or members.
- **G7, 15 edges.** The construct is an external CommonJS export that is itself a function, called directly: `prettyms = require('pretty-ms'); prettyms(ms)` and `_(…)`, `parseCsv(…)`, `wrap(…)`, `shipit({…})`. The tool names the callee by the bare specifier (`pretty-ms`). SPEC names scanned `module.exports = fn` as `mod.default` and external members "as written". It does not say what ID the external module's own callable export takes.
- **G10, 6 edges.** The construct is `format.apply(this, arguments)` with `format = require('util').format`, and also `Readable.call(this, …)` and `_.merge.apply(this, files)`. The tool gives `util.format.apply`, medium, direct. The open question: does an imported external function count as "function evidence" for the `.call`/`.apply` ruling, which would give `Function#apply` plus `util.format`? Or does it stay a receiver guess, or a name written out in full?
- **G5, 4 edges.** The construct is `new Date().toLocaleTimeString()` and `(new Date()).toISOString()`, a method called in place on a `new` expression in JS. Decision A types `= new T()` bindings. The open question: does the in-place `new T().m()` give `T#m` in JS, as the Rust in-place chain rule does?
- **G6, 4 edges.** The construct is `var summaryTable, …; summaryTable = new Table({…}); summaryTable.push([…])`. The open question: does decision A's "`= new T(...)`" cover an assignment after a declaration with no initializer?
- **G4, 4 edges.** The construct is `var tty, …; try { tty = require('tty'); } catch (e) { tty = null; }` followed by `tty.isatty(1)`. The open question: is a local that a literal `require` assigns, and that is later reassigned, a `require` binding (`tty.isatty`, medium, direct) or a receiver guess?
- **G3, 2 edges.** The construct is `server.on('listening', function () { server.port = this.address().port; })`. The open question: what is the ID form for `this.m()` in a function with no enclosing type: `.address`, `this.address`, or something else?
- **G2, 1 edge.** The construct is the root `index.js`, which holds `module.exports = require('./lib');`. The tool calls the module `newman`. The open question: SPEC strips a trailing `/index`, which leaves nothing for an `index.js` at the scan root, so what is that module's ID?
- **G8, 1 edge.** The construct is `cliUtils = { symbols: symbols, … }` with `symbols = require('./cli-utils-symbols')`, called as `cliUtils.symbols(…)`. The open question: does an object-literal property that aliases an imported function resolve to the target's ID, as the top-level Alias rule does, or keep `mod.symbols`? The target is itself a G1 binding.
- **G9, 1 edge.** The construct is `Reporter = require(…computed…); new Reporter(emitter, …)`. The open question: is a `new` through a local variable a `callback`/unknown edge named `Reporter`, or a constructor edge?
