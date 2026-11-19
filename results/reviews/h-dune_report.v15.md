# h-dune (OCaml) blind call-graph review, round 15

precision 39/50; census ≈98.7% (770 wrong of 58444 in-scope); recall: 0 missed of 48 real calls; 0 non-calls

## Scope
Tool output: `ocaml36-A/h-dune.v2.json`, 71,900 edges. In scope: 58,444 edges whose `source_file` is `.ml`/`.mli` and has no path segment `test`, `tests`, `spec`, `examples` or `docs`. They come from 760 files under `src/` (44,624), `otherlibs/` (7,025), `bin/` (5,299), `boot/` (889), `bench/` (399), `doc/` (175; the singular `doc` is in scope), `plugin/`, `ci/` and `example/`. I ignored the C, Python, header, JS and C++ edges (2,055).

- Confidence: high 46,160, medium 10,347, unknown 1,648, low 289.
- call_type: direct 56,796, callback 1,648 (every unknown edge is a callback).

The tool skipped `vendor/` (cmdliner, pp, re, opam, notty and others) as a coverage note, which CAPABILITIES lists as unsupported by design. Those libraries are therefore external.

I ignored `measured_accuracy`. Helper scripts are `fanout/h-dune_r15_*.py`.

**Sample.** Seed 15, stratified high 31, medium 9, unknown 5 and low 5, spread over 47 files. Results:
- 39 correct.
- 5 wrong: #4, #39, #47, #48, #49.
- 6 spec gaps. In five of them the caller is a non-function `let` binding (CAPABILITIES ocaml/16): #10, #22, #23, #30, #36. Their callee, tier and line are correct. The sixth, #50, is a member of a functor parameter.
- #48 is wrong on its callee, and its caller is also an ocaml/16 gap.
- Of the 44 edges SPEC decides, 39 are correct (88.6%).

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| bin/lock_dev_tool.ml:252 (sample #4) | `(Package_version.to_string version)` | lock_dev_tool.lock_dev_tool_at_version → string.to_string, high, direct | The `to_string` of the later `include (Dune_util.Stringlike.Make (struct … let to_string x = x … end) …)` in dune_lang/package_version.ml. The later include shadows `include String`. By the tool's own convention elsewhere (`lib_name.to_string`) the ID is `package_version.to_string`, high | wrong callee | W1: the earlier include wins over a later shadowing include |
| src/dune_rules/jsoo/jsoo_rules.ml:293 (sample #39) | `(match String.drop_prefix maybe_disable ~prefix:"--disable=" with` | jsoo_rules.Config.remove_config_flags.loop → string.drop_prefix, medium | `string.Cased_functions.drop_prefix`, high. It is defined in functor `Cased_functions`, reached through `module Case_sensitive = Cased_functions (…)` and `include Case_sensitive`. Stdlib.StringLabels has no `drop_prefix` | wrong callee + confidence | W6: include of an aliased functor application not followed (open defect ocaml/13); invented ID |
| src/dune_tui/drawing.ml:97 (sample #47) | `\| Success -> A.(st bold ++ fg green)` | drawing.attr_of_user_message_style → st, low | `Notty.A.st`, medium. `A` is `module A = Notty.A` (dune_tui/import.ml); notty is vendored and skipped. Rule: "the innermost external local open … (medium)" | wrong callee + confidence | W8: an external local open is not used |
| bin/arg.ml:147 (sample #48) | `let lib_name = conv Lib_name.conv` | arg.lib_name → conv, low | `Cmdliner.Arg.conv`, medium, through `include Cmdliner.Arg` of the enclosing structure. The tool itself gives `Arg.conv` from other files as `arg.conv` medium. The caller is an ocaml/16 gap | wrong callee + confidence | W10: an external include of the enclosing structure is not used for bare names |
| src/dune_lang/module_name.ml:140 (sample #49) | `match of_string_opt t with` | module_name.Unique.to_name → of_string_opt, low | The `of_string_opt` of `include Site.Modulelike (…)`, defined at site.ml:64 inside Modulelike's argument struct: high | wrong callee + confidence | W11: include of a scanned functor application not followed (open defect ocaml/13) |
| otherlibs/stdune/src/io.ml:265 | `let fn = Path.to_string p in` | io.Make.open_in → path.to_string, high | `Path` is the functor parameter `module Make (Path : sig … val to_string … end)`, not stdune's path.ml. The callee is the parameter's member (form undecided, see gaps). It is not `path.to_string` high | wrong callee + confidence | W2: functor parameter named as a same-named scanned module (C2, C5) |
| otherlibs/stdune/src/set.ml:78 | `let singleton x = Map.singleton x ()` | set.Of_map.singleton → map.singleton, medium | `Map` is the parameter of `Of_map (Key) (Map : Map_intf.S …)` | wrong callee | W2 |
| src/dune_tui/widgets/scrollbox.ml:21 | `let scrollbar_bg = Notty.A.gray 4` | scrollbox.scrollbar_bg → a.gray, medium | `Notty.A.gray`, medium (external). `a` is a test-fixture file (`test/…/a.ml`) | wrong callee | W3: module name resolved to an unrelated test-only file module (C2) |
| otherlibs/stdune/src/path.ml:454 | `\| _ when not (Filename.is_relative fn) -> external_ (External.of_string fn)` | path.relative → path.external_, medium | `path.T.external_`, high. It is defined at line 388 in `module T`, then `include T` at line 397 | wrong callee + confidence | W4: include of a local module not followed; ID invented at medium |
| src/dune_lang/package_variable_name.ml:34 | `let arch = of_string "arch"` | package_variable_name.arch → package_variable_name.of_string, medium | `stringlike.Make.of_string`, high, as the tool gives for every qualified `X.of_string` | wrong callee + confidence | W4 (also C2: the same definition gets two IDs) |
| src/dune_rules/lib.ml:467 | `\| Found t -> variant "Found" [ to_dyn t ]` | lib.Status.to_dyn → lib.to_dyn, medium | `lib.T.to_dyn`, high (`module T` … `include T` at line 418) | wrong callee + confidence | W4 |
| src/dune_scheduler/inotify.ml:54 | `let hash t = Int.hash (Inotify.int_of_watch t)` | inotify.Inotify_watch.hash → inotify.int_of_watch, medium | `Inotify.int_of_watch`, medium. This is the vendored ocaml-inotify library; the scanned inotify.ml defines no `int_of_watch` | wrong callee | W5: an external module with the file's own name is named as the file (invented ID, C2) |
| src/dune_pkg/fetch.ml:496 | `with_temp_dir "somedir" (fun dir ->` | fetch → with_temp_dir, low | `fetch.with_temp_dir`, high: the tool's own ID for the definition at line 470 of the same `let%test_module` struct (C1) | wrong callee + confidence (caller: spec gap) | W7: references inside `let%test_module`/`let%expect_test` are not resolved |
| src/memo/parallel.ml:17 | `Fiber.fork_and_join (fun () -> run ~f:x ()) (fun () -> run ~f:y ()))` | parallel.fork_and_join → run, low, direct (×2) | `run`, callback, unknown. It is bound by the record pattern `Some { Deps_collector.run }` | wrong confidence + call_type | W9: a function bound by a record pattern is treated as a bare name |
| src/rpc/server.ml:376 | `let req = encode_req req in` | server.Session.request → encode_req, low, direct | callback, unknown. It is bound by `Ok { Versioned_intf.Staged.encode_req; decode_resp }` | wrong confidence + call_type | W9 |
| src/dune_lang/site.ml:54 | `\|\| (valid_char (String.unsafe_get name i) && has_only_valid_chars name len (i + 1))` | site.has_only_valid_chars → valid_char, low; → has_only_valid_chars, low | Siblings in the same struct (a `let[@inline always] valid_char` and the `let rec has_only_valid_chars` being defined): high, under their own IDs | wrong callee + confidence | W11: struct-local and recursive references are not resolved inside a functor-argument struct |
| otherlibs/stdune/src/string_split.ml:12 | `\| -1 -> [ sub s ~pos:i ~len:(len - i) ]` | string_split.split.loop → sub, low | `Stdlib.StringLabels.sub`, medium. The file has `module String = Stdlib.StringLabels` and `open String`, its one external open | wrong callee + confidence | W12: the one external open (through an alias) is not used |
| src/dune_trace/alloc.ml:38 | `[%%if ocaml_version >= (5, 4, 0) && not_defined_permissive oxcaml]` | alloc → not_defined_permissive, low | no edge: this is a ppx_optcomp preprocessor condition, not a runtime call | not a call | W13 |
| src/dune_rules/install_rules.ml:1330 | `Fpath.traverse` | install_rules.read_dir_recursively → fpath.traverse, high | caller `install_rules.Spec.read_dir_recursively`. The function is in `module Spec`, inside `include (struct module Spec = struct … end … end : sig … end)` | wrong caller | W14: a nested module's name is dropped inside an anonymous included struct |
| src/dune_lang/format_config.ml:42 (sample #22) | `let in_ext_1_1 = Set.add in_ext_1_0 Dune` | format_config.Language.in_ext_1_1 → set.Make.add, high | callee correct; the caller is undecided (ocaml/16) | spec gap | value let inside a nested structure |
| otherlibs/stdune/src/monad.ml:97 (sample #50) | `if pred then for_all xs ~f else return false` | monad.List.for_all → return, low | undecided: `return` comes from `open M`, where `M : S` is the functor parameter | spec gap | functor-parameter member |

The sampled callers #10 (dune_config_file.ml:298 `let to_dyn = Dyn.option Dune_cache.Mode.to_dyn`), #23 (workspace_cache.ml:14), #30 (lib_dep.ml:140 `let repr =`) and #36 (menhir_rules.ml:209, `let stanzas : … = …`) are the same ocaml/16 gap. Their callees are correct.

## Systematic patterns (scripted census, `h-dune_r15_census.py`; union 770 distinct edges)
1. **W1, 258 edges, high: `Stringlike.Make`'s `to_string` resolves to an earlier `include String`.** Modules that `include String` and then include `Stringlike.Make`/`Site.Modulelike` with a struct defining `to_string`:
   - `Package.Name.to_string` 89
   - `Package_name.` 50
   - `Context_name.` 49
   - `Package_version.` 28
   - `Dune_lang.Package_name.` 11
   - `Dune_engine.Context_name.` 7
   - `Site.` 5
   - `(Workspace.)Repository.Name.` 4
   - `Name.` (warning.ml) 1
   - bare `to_string` in context_name.ml, package_name.ml and dune_pkg/package_name.ml 5
   - lines that mix two such qualifiers 9

   At runtime the later include shadows `String.to_string`. `Syntax.Name.to_string` (only `include String`) is excluded and correct.
   - Hand-checked: package_version.ml, package_name.ml, context_name.ml, site.ml:67-77, dune_pkg/workspace.ml:3-20.
   - Contrast: the tool names the same construct `lib_name.to_string`, `external_lib_name.to_string` and `checksum.to_string` where no `include String` comes first.
2. **W2, 99 edges, medium/high: a functor or first-class-module parameter is named as the scanned module of the same name.**
   - set.ml `Of_map (… Map …)` → `map.*` 25
   - io.ml `Make (Path …)` → `path.to_string` high 9
   - string_with_vars.ml `A` 8
   - combinators.ml `(module A)`/`(module B)` 14
   - comparator.ml `X` 5
   - string.ml `Cased_functions (X …)` → `x.normalize` 4
   - monoid.ml 5
   - lock_dir.ml `Make_load (Io …)` 4
   - substs.ml `Monad` 1
   - applicative.ml 1
   - glob_files_expand.ml 1
   - duneboot.ml `Make (Map : Map.S)` → `duneboot.Map.*` 7
   - module_trie.ml `module Map = S.Map` → `map.*` 15

   The functor body checks were scripted (`h-dune_r15_fparam2.py`, call line within the functor's span). Hand-checked: io.ml:256-265, set.ml:72-90, duneboot.ml:136-177.
   - Several targets (`a`, `b`, `c`, `x`) are test-fixture files.
   - Which ID such a call should get is the spec gap G2. Naming a different scanned module breaks C2/C5.
3. **W4, 77 edges, medium: a name reached through a scanned `include`, `module rec`, later `open` or functor-argument struct gets `<including module>.name` at medium instead of the definition's ID at high.** Groups:
   - `path.external_` 11 and `path.is_dir_sep` 3 (path.ml; `include T`, `include Path0`)
   - `package_variable_name.of_string` 16
   - `lib.to_dyn` 8 and `lib.compare` 4
   - `scheduler.t` 8 (`include Types.Scheduler`)
   - `dep.file`/`file_selector` 3
   - `load_rules.load_dir` 3 (`module rec Load_rules` … `include Load_rules`)
   - `sub_system_name.to_string` 3
   - `pform.to_dyn` 2 (`open With_versioning_info`)
   - `package_version.of_string` 2
   - `module_name.of_string_opt` 2
   - `alloc.Memprof.*` 2
   - one each: `which.which` (`module rec Rec`), `dir_contents.get` (`include Load`), `relop.equal`/`toggle.equal` (`include Repr.Poly`), `action_builder.record`, `package_name.Opam_compatible.of_string_opt`, `fiber.return` (`include Core`), `dune_init.Public_name.to_string` (`include Lib_name`), `opamUrl0.to_string` (`include Dune_lang.Url`), `string.split` (`include String_split`)

   Matches open defect ocaml/13.
4. **W7, 71 edges, low: references inside `let%test_module` / `let%expect_test` bodies to bindings of the same test struct, or of its enclosing struct, stay bare.** The definitions themselves get IDs (`fetch.with_temp_dir`, `file_watcher.Watch_trie.insert_exn`) (C1). Locations: fetch.ml 45, roots.ml 11, file_watcher.ml 15.
5. **W8, 60 edges, low: a call inside the external local open `A.( … )` stays bare (`fg`, `bg`, `st`).** drawing.ml 57, dune_tui.ml 3. Inconsistent with qualified `A.fg`, which the tool gives as medium `a.fg` (itself W3).
6. **W6, 40 edges, medium: `String.drop_prefix` / `drop_suffix` / `drop_prefix_if_exists` / `drop_suffix_if_exists` → `string.drop_*`.** The definition is `string.Cased_functions.drop_*`. The tool uses that ID, high, inside string.ml itself.
7. **W9, 39 edges, low/direct: a function bound by a record pattern (`{ run }`, `{ get; … }`, `View { repr; to_ }`, `{ ui; vscroll; hscroll }`, `{ encode_req; decode_resp }`) or by a labelled parameter (env_stanza_db.ml `~root`, `~f` inside a `let module … module rec`) is applied.** SPEC: callback, unknown. Files:
   - parallel.ml 10
   - repr.ml and digest.ml 8
   - dune_tui.ml 4
   - fs_memo.ml 3
   - js_of_ocaml.ml, long_poll.ml, spec.ml, env_stanza_db.ml 2 each
   - rpc/server.ml 3
   - dep_rules.ml, dune_load.ml, dune_rpc_impl/server.ml 1 each
8. **W10, 35 edges, low: a bare name supplied by an external `include` of the enclosing structure stays bare.** Locations:
   - bin/arg.ml `include Cmdliner.Arg`: `conv`, `conv'`, `pair` 11
   - hashtbl.ml `Make` 7
   - array.ml `T` (`include ArrayLabels`) 7
   - bin/import.ml `Cmd` (`include Cmdliner.Cmd`): `info` 1
   - map.ml 2
   - duneboot.ml `Map.Make` / `String.Map` 7

   I read the OCaml note as listing "enclosing structures and their opens/includes" as a resolution step. If the maintainer reads "the one external open" as excluding includes, these 35 move to spec gaps.
9. **W11, 32 edges, low: scanned definitions reachable lexically or through a scanned include stay bare.**
   - site.ml, lib_name.ml and context_name.ml sibling or recursive members of functor-argument structs: 12
   - `of_string_opt` / `to_string` through Modulelike/Stringlike includes: 6
   - `module rec` members (`resolve`, pkg_rules.ml and rocq_lib.ml): 3
   - `include O.Set` / `include O.Map` (`of_list`, `singleton`): 3
   - lock_dir.ml `include Memo` (`return`): 2
   - client.ml `include Csexp_rpc.Session` (`write`): 1
   - inline_tests.ml struct sibling `gen_rules`: 1
   - install_rules.ml Spec siblings: 3
   - local-module sibling `start` (dune_threaded_console.ml): 1
10. **W14, 26 edges: the `Spec` module name is dropped from callers inside `include (struct module Spec = struct … end … end : sig … end)`.** This occurs only in install_rules.ml, at lines 1312-1362.
11. **W5, 15 edges, medium: an external module that shares its file's name is named as that file.** Cases:
    - `Inotify.*` in inotify.ml (vendored) 8
    - `module Format = Stdlib.Format` in dune_lang/format.ml 3
    - `Stdlib.List.sort_uniq` → `list.sort_uniq` 1 (a definition that exists in list.ml, so the callee is the wrong function)
    - `Scanf.ksscanf` in stdune scanf.ml 1
    - outer `Path` named `arg.Path.*` inside `module Path = struct` in bin/arg.ml 2
12. **W3, 12 edges, medium: `A` (`module A = Notty.A`, and install_rules' `module A = Action_ext.Make (Spec)`) resolves to a test-fixture `a.ml`, including fully qualified `Notty.A.gray`.** Locations: drawing.ml 7, scrollbox.ml 4, install_rules.ml 1 (correct: `action_ext.Make.action`, high).
13. **W12, 6 edges, low:** string_split.ml `sub`/`length` under `open String` (= `Stdlib.StringLabels`), the one external open.
14. **W13, 2 edges:** `not_defined_permissive` inside ppx_optcomp `[%%if …]` directives in alloc.ml and runtime.ml is emitted as a call.

I found no wrong pattern in the unknown tier. The 5 sampled edges and 12 extra edges (seed 1515) were all calls through parameters or locals.

Other low edges I judged correct: 25 printf-family calls in boot/ and the toplevel linker. Those files have several external opens (`open Stdlib`, `StdLabels`, `MoreLabels`, `Printf`; `open Topdirs`, `open Toploop`), so a low bare name is the honest result.

One low edge is unverified and not counted: action.ml:545 `combine`.

## Missed-call patterns (recall)
| function | real calls | tool edges with that caller | missed | non-calls |
|---|---|---|---|---|
| src/dune_rules/cram/cram_exec.ml `sanitize` (383-412, incl. nested `rewrite`) | 7 | 7 | 0 | 0 |
| src/dune_pkg/opam_solver.ml `Context.create` (114-174, incl. nested `packages`) | 17 | 17 | 0 | 0 |
| src/dune_tui/drawing.ml `attr_of_user_message_style` (84-103) | 24 | 24 | 0 | 0 |

Every call was present on the right line. Function references passed as arguments (`~f:Package_dependency.to_opam_filtered_formula`) and the alias `let to_dyn = Opam_dyn.package` correctly have no edge.

In the third function, 21 of the 24 edges are W8 (wrong callee and tier, not missing). Its eleven `++` operator applications have no edge; operators are undecided (ocaml/15).

None of the recall functions exercised open defect ocaml/04 (record-field function calls `t.f x` get no edge), so its frequency here is not measured.

## Spec gaps (counted separately, never as wrong)
- **G1, about 4,197 to 8,519 edges: caller of calls inside a non-function `let`.** Examples: `let in_ext_1_1 = Set.add in_ext_1_0 Dune` (format_config.ml:42), `let lib_name = conv Lib_name.conv` (arg.ml:147). The tool names the binding (`format_config.Language.in_ext_1_1`). The lower count covers bindings whose right-hand side does not start with `let`, `fun` or `function`. The upper count adds `let x = let … in …` bindings such as `let formatter_diff_action = let … in fun …` (`h-dune_r15_valuelet.py`, heuristic). SPEC leaves open whether the caller of a call in a top-level or nested-structure value binding is the module (as for `let () = …`) or the binding name (CAPABILITIES ocaml/16).
- **G2, 16 edges (low), plus the target form for W2's 99: members of functor parameters and first-class-module parameters.** Example: `if pred then for_all xs ~f else return false` (monad.ml:97, `return` from `open M` with `module List (M : S)`). Other low edges: applicative.ml, combinators.ml `include Backend`, dune_threaded_console.ml `include (val Console.Backend.progress_no_flush)`. SPEC gives no ID or tier for a call to a member of a functor parameter, or of an unpacked first-class module whose signature is a scanned module type: a low bare guess, `M.return`, or the signature's declaration as for a body-less interface member.
- **G3, about 168 edges: caller of code in `let%expect_test` / `let%test` bodies.** Example: `let%expect_test "no symlink no change" = with_temp_dir "somedir" (fun dir -> …)` (fetch.ml:495). The tool uses the file module (`fetch`). SPEC leaves open what the caller of a ppx inline-test body is, and what the IDs of bindings inside `let%test_module "…" = (module struct … end)` are.
- **G4, about 242 edges: IDs of definitions inside an anonymous `struct` passed as a functor argument.** Example: `include Site.Modulelike (struct … let to_string s = s … end)` (module_name.ml:5); site.ml:20-65 inside `Modulelike`. The tool flattens these to the file module (`module_name.to_string`, `site.has_only_valid_chars`). SPEC leaves open the definition ID for members of such structs (heuristic count of edges inside them, `h-dune_r15_anonstruct.py`).
- **G5, 2 edges: functions bound by a top-level tuple pattern.** Example: `let find_checksum, find_url = … find_checksum, find_url` (fetch_rules.ml:161-212), then `find_checksum checksum` (line 278), low. SPEC leaves open whether a call through a top-level tuple-bound function value is a named function, a callback/unknown call, or a low bare name.
- **G6, not counted (no edges emitted): operators.** Examples: `A.(st bold ++ fg red)` and the `let+` / `>>=` / `|>` applications. This is CAPABILITIES ocaml/15: whether operator applications are invocation edges, and what their IDs are.
