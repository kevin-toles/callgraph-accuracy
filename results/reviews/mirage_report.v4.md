# mirage (OCaml) call-graph review, v4

precision 45/50; census ≈99.4% (18 wrong of 3197 in-scope); recall: 1 missed of 45 real calls; 0 non-calls

**Scope and input.** The output has 3,907 edges. 3,197 of them are in non-test `.ml` files: 1,839 high, 1,250 medium, 3 low and 105 unknown, made up of 3,092 direct and 105 callback edges. These are the same counts as in v2 and v3. `mirage.v2.json` (Oct 28 09:34) is not byte-identical to `mirage.v2a.json`, but its edge set and node set are identical to v2a's when compared as sets. The output still shows no change in behaviour on this repo.

**Precision sample.** The sample is 50 edges: 25 high, 17 medium, 3 low (every low edge in scope) and 5 unknown. They come from 23 files, drawn with seed 4104 by `mirage_v4_sample.py`. Results:
- 45 edges are correct.
- 2 are wrong: #38 `Key.Arg.opt` and #43 `cast`.
- 3 are spec gaps, not counted as errors: #27 `Tbl.create`, #44 `mem` and #45 `find`.

Some of the correct edges cover harder cases:
- Nested local functions: `engine.packages.aux.aux` for a `let aux` inside `let aux = function`, `lib.Make.describe.with_fmt`, `impl.Dot.as_dot_graph.add` and `key.value.v`.
- A file-local nested module: `package.Set.union`, high.
- Definition order: `sleep.default_sleep -> sleep.impl` correctly picks the file's own `impl` (sleep.ml:8) over `Functoria.DSL.impl`.
- A second `let main` calling the first one: `target.Unikraft.dune -> target.Unikraft.main`.
- `Arg.vflag` / `Arg.list` under `Arg.( … )` with `open Cmdliner`, medium.
- `Stdlib.not`, `Stdlib.snd` and `Stdlib.open_out`, medium.
- Callbacks: `f`, `l` and `v` (the local `let v = Runtime_arg.v in`), unknown.

**Census.** `mirage_v4_patterns.py`, `mirage_v4_selfcall.py` and `mirage_v4_callbacks.py` count 18 wrong edges:
- 8 from first-class module receivers.
- 7 false self-calls from non-recursive lets.
- 2 from cross-file `include` paths rated medium.
- 1 from a local open lost inside a default argument.

That gives 1 − 18/3197 = 99.44%. Missed calls are not in this count, because they are not edges. `mirage_v4_apply_ops.py` finds at least 61 of them by script: 44 sites of `f @@ x` and 17 of `x |> f`, where `f` is a bare identifier or path. None of the 61 has an edge.

**Recall.** I checked three functions. Operators (`let*`, `@@`, `|>`, `@`, `^`) and values passed without being applied (`meta_init`, `pp_pos`, `Runtime_arg.call`, `nop`) are not counted as calls.
- `lib.Make.configure` (lib.ml:363-393): 25 calls, 25 found. This includes `Filegen.write` resolved to `filegen.Make.write`, high, through `module Filegen = Filegen.Make (P)`, and `P.name_of_target` at medium.
- `engine.emit_connect` (engine.ml:194-210): 12 calls, 12 found. The callers `engine.emit_connect.bind` and `.bind_key` are correct, and `connect_code` (a tuple-pattern parameter) is a callback.
- `opam.guess_src` (opam.ml:102-133): 8 calls, 7 found. `Action.run` applied with `@@` is missing.

## Mismatch table

| file:line | source line | tool said (caller -> callee, conf, type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/devices/target.ml:560 (#43) | `Target.(packages (cast target))` | target.packages -> cast, low, direct | `Target.cast`, medium (`let (module Target) = choose target in`) | wrong callee / wrong confidence | first-class module unpack not tracked as a local open |
| lib/devices/target.ml:560, 527, 535, 546, 551, 556, 565 | e.g. `Target.context_name i` | target.X -> target.X, high | `Target.X`, medium | wrong callee / wrong confidence | `Target` (unpacked module) resolved to the current file `target` → false self-call |
| lib/devices/block.ml:282 (#38), 274 | `let key = Key.Arg.opt Cmdliner.Arg.string "disk.img" doc in` | block.disk_output -> Key.Arg.opt, medium | `key.Arg.opt`, high (devices/key.ml:171 `include Key`, `module Key = Functoria.Key`) | wrong callee / wrong confidence | module path through cross-file `include` not followed (the same line's `Key.create` does resolve to `key.create`, high) |
| lib/devices/sleep.ml:12 (also argv.ml:16, mtime.ml:12, ptime.ml:12) | `impl ~packages "Mirage_sleep" sleep` inside `let impl sublib =` | sleep.impl -> sleep.impl, high | `DSL.impl`, high (non-recursive `let`: `impl` in its own body is `Functoria.DSL.impl`, as the tool gives at sleep.ml:6) | wrong callee | non-`rec` binding treated as in scope in its own body |
| lib/mirage.ml:425 | `register ?init ?src name jobs` inside `let register ?(argv = …)` (mirage.ml:404) | mirage.register -> mirage.register, high | `lib.Make.register`, high (from `include Functoria.Lib.Make (Project)` at mirage.ml:377; lib.ml:500) | wrong callee | non-`rec` self-shadowing + include |
| lib/functoria/key.ml:124; runtime_arg.ml:45 | `else add k set` inside `let add k set =` after `include Set.Make (M)` | key.Set.add -> key.Set.add, high | the included Stdlib `Set.Make` `add`, medium (exact ID is the spec gap below, but it is not a self-call) | wrong callee / wrong confidence | non-`rec` self-shadowing |
| lib/devices/block.ml:99 | `let generic_block ?group ?(key = Key.(value @@ block ?group ())) name =` | block.generic_block -> block, unknown, callback | `key.block`, high, direct (devices/key.ml:124 `let block ?group () =`, reached through the `Key.( … )` local open) | wrong callee / wrong confidence | local open ignored; the bare name was matched to the file's value `let block = typ BLOCK` |
| lib/functoria/opam.ml:104 (recall) | `match Action.run @@ find_git () with` | (no edge for `Action.run`; `opam.find_git` found) | `opam.guess_src -> action.run`, high (action.ml:209 `and run`) | missed call | left operand of `@@` with no own arguments gets no edge |
| lib/functoria/impl.ml:331 (#27) | `let tbl = Tbl.create 50 in` | impl.map -> Tbl.create, medium | `Tbl` is `module Tbl = Hashtbl.Make (…)` at impl.ml:201. Medium is right, but the spec gives no ID rule for members of a local functor-application module (`impl.Tbl.create`? `Hashtbl.Make.create`?) | spec gap | — |
| lib/functoria/key.ml:120, 121 (#44, #45) | `if mem k set then` / `if k != find k set then` | key.Set.add -> mem / find, low | members of `include Set.Make (M)` (Stdlib functor). No ID rule. The identical code in runtime_arg.ml:41-42 comes out as `Set.Make.mem` / `Set.Make.find`, medium, so the tool is inconsistent | spec gap | — |
| lib/functoria/action.ml:619, 625; lib/mirage.ml:404 (unsampled) | `let dry_run ?(env = env ()) t = …` (`let env = Env.v` at action.ml:429); `?(reporter = default_reporter ())` (`let default_reporter = Reporter.default_reporter`) | -> env / default_reporter, unknown, callback | The spec covers callbacks through parameters, locals and stored properties, but not a top-level value bound to another module's function. `action.env` (high) or `Env.v` would also be defensible | spec gap | — |
| lib/devices/block.ml:341; ip.ml:82 (unsampled) | `Fmt.(parens (Dump.option int))` | -> Dump.option / Dump.list, medium | qualified path under an external local open (`Fmt.Dump.option`?) | spec gap | — |

## Systematic patterns

1. **`f @@ x` and `x |> f` with a bare `f` produce no edge (missed calls, 61 sites, lower bound).** `mirage_v4_apply_ops.py` matches 44 `@@` sites and 17 `|>` sites, and none of the 61 has an edge for the applied function. The biggest group is the 16 `wrap @@ …` sites in action.ml (lines 80-104). Others:
   - `Key.value @@ Key.kv_ro ?group ()` (kv.ml:83, stack.ml:105-106, tcp.ml:28)
   - `run @@ configure t …` (tool.ml:364-368)
   - `Action.run @@ …` (opam.ml:104, devices/key.ml:62)
   - `Typeid.to_bool @@ equal x y` (impl.ml:187)
   - `|> List.rev` (engine.ml:243, package.ml:133)
   - `|> Option.get` (lib.ml:508)

   Calls with arguments before `@@` (`Impl.collect (module Dune) @@ function`) are found. The `@@` regex misses chain middles such as `Impl.abstract` in `Engine.keys @@ Impl.abstract @@ P.create []` (tool.ml:226), so 44 is a lower bound.
2. **First-class module receivers resolve to the current file: 8 wrong.** `let (module Target) = choose target in Target.f …` gives `target.f`, high, which is a false self-call. That covers 7 edges at target.ml:527-565, plus 1 low bare `cast` under `Target.( … )`.
3. **Non-recursive `let` treated as recursive (false self-calls): 7 wrong.** `mirage_v4_selfcall.py` checks all 55 in-scope self-edges outside pattern 2 against their binding. 15 come from a non-`rec` binding:
   - 8 of these are correct. A second top-level binding with the same name calls the first one and the two share an ID: block.ml:287 and 291, kv.ml:63, action.ml:619, cli.ml:116, info.ml:60, and target.ml:362 and 488.
   - 7 are wrong:
     - `impl` in argv.ml:16, mtime.ml:12, ptime.ml:12 and sleep.ml:12, which should be `DSL.impl`.
     - `register` in mirage.ml:425, which should be `lib.Make.register`.
     - `add` in key.ml:124 and runtime_arg.ml:45, which should be the included Stdlib `Set.add`.
4. **Module paths through a cross-file `include` are rated medium: 2 wrong.** These are `Key.Arg.opt` at block.ml:274 and 282.
5. **Local open lost inside an optional-argument default: 1 wrong.** block.ml:99 `Key.(value @@ block ?group ())` gives a `block` callback. The other top-level value-alias callbacks (`env` ×2, `default_reporter`) are spec gaps; see below.

## Spec gaps (counted separately, not as wrong)

- **Members of a local functor-application module (25 edges).** `mirage_v4_patterns.py` counts `Tbl.*` 12, `Map.*` 6 (context.ml:32 `module Map = Map.Make (String)`), `IdTbl.*` 3, `IntSet.*` 2 and `Names.*` 2. The OCaml note gives no ID rule for these. The tool leaves them unqualified, while `key.Set.*` and `package.Set.*` (structures defined in the file) get the file qualifier.
- **Members of an `include Set.Make (M)` inside a local structure (4 edges).** At key.ml:120-121 the tool gives a bare `mem` / `find`, low. At runtime_arg.ml:41-42 it gives `Set.Make.mem` / `Set.Make.find`, medium. The tool handles the same code two different ways, and the spec has no rule for either.
- **Top-level value aliases of functions called as callbacks (3 edges).** These are `env ()` at action.ml:619 and 625 and `default_reporter ()` at mirage.ml:404.
- **Qualified paths under an external local open (3 edges).** These are `Dump.option` ×2 and `Dump.list`.
- **Calls through a functor parameter, `P.name_of_target` and similar (8 edges, medium).** The spec does not name this case. Medium seems right, but I am noting it as unspecified.
- **A `let` inside `let module M = struct … end`.** At typeid.ml:49 the caller is `typeid.id` and the enclosing function is `typeid.gen`. 1 edge, unchanged.

## Previous findings

| v3 item | status | v3 count | v4 count |
|---|---|---|---|
| Mismatch row: target.ml:560 `cast` (low, should be `Target.cast` medium) | **still present** (sampled again as #43) | 1 | 1 |
| Mismatch row: target.ml:560 `target.packages` false self-call | **still present** | 1 | 1 |
| Mismatch row: target.ml:527/535/546/551/556/565 false self-calls | **still present** | 6 | 6 |
| Mismatch row: block.ml:274/282 `Key.Arg.opt` medium (should be `key.Arg.opt` high) | **still present** (sampled again as #38) | 2 | 2 |
| Mismatch row: dune.ml:72 missed `\|> String.Set.elements` | **still present** | 1 | 1 |
| Mismatch row: dune.ml:79 missed `\|> Fpath.to_string` | **still present** | 1 | 1 |
| Mismatch row (spec gap): key.ml:208 `Names.of_list` unqualified | **unchanged** (spec gap). The v4 census widens the class to 25 local functor-module edges | 2 | 2 (`Names`), 25 (class) |
| Mismatch row (spec gap): key.ml:120/121 `mem`/`find` | **unchanged** (sampled again as #44, #45). New: runtime_arg.ml:41-42 renders the same construct differently | 2 | 2 (+2 inconsistent) |
| Mismatch row (spec gap): `Dump.option` / `Dump.list` | **unchanged** | 3 | 3 |
| Pattern 1: first-class module receivers resolve to the current file | **still present** | 7 + 1 low | 7 + 1 low |
| Pattern 2: module paths through a cross-file `include` rated medium | **still present** | 2 | 2 |
| Pattern 3: functions applied with `\|>` get no edge | **still present** | 17 | 17. v4 also finds the same defect for `@@` (44+ sites), which v3 did not check |
| Pattern 4 (spec gap): local functor-application modules not file-qualified | **unchanged** | 2 | 25 (all local functor modules counted) |
| typeid.ml:49 `let module` caller (spec gap, carried from v2) | **unchanged** | 1 | 1 |

None of the v3 findings is fixed or partly fixed. As sets, the edges and nodes are identical to the v2a data that v2 and v3 reviewed. The new findings in v4 come from the larger sample and the scripted census, and they were already present in that same data:
- non-recursive self-shadowing, 7 wrong
- the local-open loss at block.ml:99, 1 wrong
- the `@@` misses, 44+
- the value-alias and functor-parameter spec gaps

Helper scripts are in <fanout>/:
- `mirage_v4_sample.py`
- `mirage_v4_recall.py`
- `mirage_v4_patterns.py`
- `mirage_v4_selfcall.py`
- `mirage_v4_callbacks.py`
- `mirage_v4_apply_ops.py`
