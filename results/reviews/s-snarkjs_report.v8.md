# s-snarkjs (javascript) blind call-graph review, round 8

precision 49/50; census ≈99.45% (31 wrong of 5620 in-scope); recall: 0 missed of 40 real calls; 0 non-calls

## Scope
Tool output `<scans>/final13-A/s-snarkjs.v2.json` has 6488 edges. 5620 are in scope: JavaScript (`.js`/`.cjs`) source files that are not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment. The 868 out-of-scope edges sit under `test/`, `smart_contract_tests/test/` and `browser_tests/test/`. In-scope edges come from 73 files: src/ 5258, cli.js 214, scripts/ 131, config/ 16, smart_contract_tests/hardhat.config.cjs 1. The tool skipped `build/` (5 files, coverage note "skipped"). Under CAPABILITIES that is an unsupported construct, so it counts as a recall gap and not as wrong edges.
- By confidence: low 2979, high 1355, medium 1219, unknown 67.
- By call_type: method 3504, direct 1639, constructor 410, callback 67.
- By tier and call_type: low/method 2979, high/direct 853, medium/direct 786, high/method 414, medium/constructor 322, medium/method 111, high/constructor 88, unknown/callback 67.

Sample: seed 20261113. Per tier: low 24, high 11, medium 10, unknown 5 (raised to the minimum of 5). The sample spans 27 files. I ignored the `measured_accuracy` field.

Recall functions:
- `src/polynomial/polynomial.Polynomial#divByMonic`: 14 calls
- `src/clprocessor.clProcessor.calculateMatch`: 13 calls
- `src/zkey_export_verificationkey.groth16Vk`: 13 calls

Every call in all three was emitted with the right caller, callee form, tier and line.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/powersoftau_verify.js:101 (sample #47) | `sr = await sameRatio(curve,  cur.key.tau.g1_s, cur.key.tau.g1_sx, prev.tauG2, cur.tauG2);` | src/powersoftau_verify.verifyContribution → src/powersoftau_verify.sameRatio, unknown, callback | → src/misc.sameRatio, high, direct (Alias rule: `const sameRatio = misc.sameRatio;` at line 26 is a member path naming the scanned `export async function sameRatio` in src/misc.js:129, so the call resolves to the target at the target's tier) | wrong callee / wrong confidence / wrong call_type | top-level alias of a namespace-import member not treated as an Alias |
| src/zkey_verify_frominit.js:63 (census) | `sr = await sameRatio(curve, c.delta.g1_s, c.delta.g1_sx, delta_g2_sp, c.delta.g2_spx);` | src/zkey_verify_frominit.phase2verifyFromInit → src/zkey_verify_frominit.sameRatio, unknown, callback | → src/misc.sameRatio, high, direct (same alias at line 26) | wrong callee / wrong confidence / wrong call_type | same as above |
| src/fflonk_setup.js:163 (census) | `plonkConstraints.push(getFFlonkConstantConstraint(i + 1, Fr));` | src/fflonk_setup.fflonkSetup.computeFFConstraints → src/bigarray.BigArray#push, medium, method | not `BigArray#push`. Class `BigArray` (src/bigarray.js:91) defines only a constructor and has no superclass, so this ID is invented (C2). At runtime the constructor returns `new Proxy(new _BigArray(..), …)`. | wrong callee (C2 violation) | typed receiver's method named on a scanned type that does not define it |
| src/bigarray.js:82 (census) | `newA.push(i*SUBARRAY_SIZE+j);` | src/bigarray._BigArray#getKeys → src/bigarray.BigArray#push, medium, method | as above | wrong callee (C2 violation) | same |
| src/taskmanager.js:209 (census) | `deferral.resolve();` | src/taskmanager.buildTaskManager → src/taskmanager.Deferred#resolve, medium, method | `resolve`, callback, unknown. `Deferred` has no method `resolve`; the constructor stores a function in `this.resolve = resolve` (line 30). A call through a stored property holding a function is a callback, and `Deferred#resolve` is an invented ID under C2. | wrong callee / call_type / confidence | function-valued property called as a method |
| src/taskmanager.js:164 (census) | `` const worker = new NodeWorker(`(${thread.toString()})(require('worker_threads').parentPort, ${fn.toString()},${S});`, {eval: true}); `` | src/taskmanager.buildTaskManager → src/taskmanager.thread#toString, medium, method | not `src/taskmanager.thread#toString`. `thread` is a scanned function with no member `toString` (it is `Function.prototype.toString`), so the ID is invented (C2). | wrong callee (C2 violation) | Function.prototype member named as a member of the scanned function |
| src/taskmanager.js:164 | same line | src/taskmanager.buildTaskManager → src/taskmanager.NodeWorker#<init>, medium, constructor | undecided (see Spec gaps) | spec gap | `let NodeWorker;` assigned later from `require("worker_threads").Worker` |

The other 49 sample edges are correct.
- The low edges are receiver guesses on parameters, untyped locals and expando properties: `Fr.mul` with `const Fr = curve.Fr`, `logger.info`, `G2.eq` from `curve.G2.eq`, `L.subScalar` from `polynomials.L.subScalar`, and `.forEach` on an array literal.
- The high edges are nested named functions, `this.` methods, and `new`-typed locals (`proof = new Proof`, `transcript = new Keccak256Transcript`).
- The medium edges are external package members named as written (`@iden3/binfileutils.copySection`, `@noble/hashes/blake2b.blake2b.create`, `ffjavascript.BigBuffer#<init>`, `logplease.setLogLevel`), globals, and `DataView#setUint32` on `new DataView`.
- The unknown edges are callbacks: `fn`, `this.fnGetAdditionConstraint`, and top-level destructured bindings from external `ffjavascript` `utils` (`cli.stringifyBigInts`). For those bindings I applied the No-evidence rule, because the initializer is neither a function literal nor a member path naming a scanned function.

## Systematic patterns (scripted counts, `s-snarkjs_r8_census.py`)
| # | pattern | count | hand checks |
|---|---|---|---|
| 1 | Top-level alias `const sameRatio = misc.sameRatio;` (powersoftau_verify.js:26, zkey_verify_frominit.js:26) gives calls `mod.sameRatio`, callback, unknown. They should resolve to `src/misc.sameRatio`, direct, high. | 17 (12 + 5) | 77, 101 (powersoftau_verify); 63, 344 (zkey_verify_frominit) |
| 2 | `src/bigarray.BigArray#push`, medium, on receivers typed `new BigArray()`. BigArray does not define `push`, so the ID is invented (C2). | 12 | bigarray.js:82, fflonk_setup.js:163/177/178 |
| 3 | A function-valued property called as a method: `deferral.resolve()` → `Deferred#resolve`. | 1 | taskmanager.js:209 |
| 4 | A `Function.prototype` member named as a member of a scanned function: `thread.toString()` → `src/taskmanager.thread#toString`. | 1 | taskmanager.js:164 |

The union is 31 wrong of 5620, so census precision ≈ 99.45%.

Patterns I checked by script that came out clean:
- High edges whose callee is missing from `nodes`: 0.
- Low edges on a receiver bound by an import or `require` in the same file: 0.
- Medium callees naming a scanned module (`src/…`): only the four IDs above.
- Edges whose line does not contain the callee name: 61. On hand check, all are correct imports, re-exports or aliases (`r1cs.info` → `src/r1cs_info.r1csInfo` via `export {default as info}`; `getCurve` → `src/curves.getCurveFromQ`) or external default imports (`replace(` → `@rollup/plugin-replace.default`).
- `.call`/`.bind`: `Array.prototype.map.call` gives `Function#call` and `Array#map`, and `stringifyBigIntsWithField.bind` gives `Function#bind`. Both are correct.

## Missed-call patterns (recall)
- In the three functions: none (0 of 40).
- The skipped `build/` directory (5 files) has no edges. CAPABILITIES lists it as unsupported by design, so it is a recall gap only.

## Spec gaps
| construct | count | open question |
|---|---|---|
| `let NodeWorker;` at the top level, then `NodeWorker = require("worker_threads").Worker;` inside `if (!inBrowser)`, then `new NodeWorker(...)` (src/taskmanager.js:21–23, 164). Tool: `src/taskmanager.NodeWorker#<init>`, medium, constructor. | 1 | When a binding is declared without an initializer and assigned later at the top level (CAPABILITIES `javascript/16-known-gap-var-assign`, undecided), and its value is a member of an external module's `require` result, what does SPEC require for a `new` through it? Options include `mod.NodeWorker#<init>`, `worker_threads.Worker#<init>`, or a constructor edge at all. |
| Typed receiver whose class does not define the method and has no base (pattern 2): `BigArray`'s constructor returns a `Proxy` over `_BigArray`. | (12, counted as wrong above under C2) | C2 rules out `BigArray#push`. SPEC does not say what replaces it when a constructor returns another object: a low guess `plonkConstraints.push`, or the proxied `_BigArray#push`. |
| `thread.toString()` on a scanned function (pattern 4) | (1, counted as wrong above under C2) | SPEC names `Function#call`/`#apply`/`#bind` for function receivers. It does not say whether other `Function.prototype` members (`toString`) become `Function#toString`, medium, or stay a receiver guess. |

Helper scripts are in `<fanout>/`: `s-snarkjs_r8_load.py`, `s-snarkjs_r8_sample.py`, `s-snarkjs_r8_recall.py`, `s-snarkjs_r8_scan.py`, `s-snarkjs_r8_lines.py`, `s-snarkjs_r8_nsimport.py`, `s-snarkjs_r8_this.py`, `s-snarkjs_r8_propnew.py`, `s-snarkjs_r8_census.py`.
