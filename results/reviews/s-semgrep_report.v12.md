# Blind call-graph review: s-semgrep (OCaml), round 12

precision 48/50; census ≈99.20% (1430 wrong of 177901 in-scope); recall: 0 missed of 60 real calls; 0 non-calls

(Of the 48 sample edges that are not wrong, 2 are spec gaps (rows 48, 49). Spec-gap edges are counted separately below: 1954 in the census.)

## Scope
Tool output: `<scans>/ocaml36-A/s-semgrep.v2.json` (289,640 edges in all languages). In scope: edges whose `source_file` is `.ml` and has no path segment named `test`, `tests`, `spec`, `examples` or `docs`. That leaves **177,901 edges in 752 files**. By confidence: high 134,199, medium 40,949, unknown 2,558, low 195. By call_type: direct 175,343, callback 2,558, and no method, constructor, macro or implicit edges. The C and Go builders failed on this repo (coverage `builder_failed`), but that does not touch OCaml. I ignored the `measured_accuracy` field.

Sample: seed `20261116`, Python `random.shuffle` within each tier, at most one edge per file per tier. Quotas: high 32, medium 8, unknown 5, low 5, the 5-per-tier minimum for the small tiers. The 50 edges come from 49 files. Helper scripts are in the fanout folder with the prefix `s-semgrep_r12_`.

## Precision sample (50)
48 edges are not wrong. The 2 wrong edges are rows 34 and 47. Rows 48 and 49 are spec gaps.

Other rows I checked and found correct:
- **Stdlib calls at medium:** row 32 `Stdlib.not`. The scan contains no stdlib sources.
- **Partial applications:** rows 18 and 26, `token env` passed to `List.map` / `Option.map`.
- **Callback parameters at unknown:** rows 40–44 (`handler`, `m`, `f`).
- **Bare names left low:** rows 45 and 46 (`eprintf`, `printf`). The file has two external opens (`Printf` and `Cmdliner`, or `Printf` and `Tree_sitter_bindings.Tree_sitter_output_t`), so SPEC's "the one external open" does not apply.
- **Callees through scanned module aliases and dune wrappers:** for example `G.e` → `AST_generic.e`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| libs/ocaml-tree-sitter-semgrep/core/src/gen/bin/Ocaml_tree_sitter_main.ml:156 (sample 34) | `Cmd.v info cmdline_term` (file has `open Cmdliner`) | Ocaml_tree_sitter_main.simplify_cmd → `Cmd.v`, medium, direct | `Cmdliner.Cmd.v`, medium (the caller is a value let, a spec gap) | wrong callee | `open Cmdliner` shadows the scanned `libs/commons/Cmd.ml`; the tool names the scanned module, which does not define `v` (C2) |
| libs/commons/Cmd.ml:48 (sample 47) | `let to_cmd (Name str, args) = Bos.Cmd.(v str %% of_list args)` | Cmd.to_cmd → `v`, low, direct | `Bos.Cmd.v`, medium (innermost external local open) | wrong callee / confidence | local open `M.( … )` of an external module is not applied |
| src/osemgrep/cli_scan/Scan_CLI.ml:388 | `Arg.info [ "x-mem-policy" ]` (`module Arg = Cmdliner.Arg`) | Scan_CLI.… → `Arg.info`, medium | `Cmdliner.Arg.info`, medium | wrong callee | file-level alias to an external module not followed |
| src/analyzing/Constant_propagation.ml:165 | `Log.debug (fun m ->` (`module Log = Log_analyzing.Log`) | → `Log.debug`, medium | `Log_analyzing.Log.debug`, medium | wrong callee | alias not followed; `Log` collides with the scanned `src/prefiltering/Log.ml` |
| src/analyzing/Dataflow_core.ml:96 | `NodeiSet.…` (`module NodeiSet = Sets.Int_set`) | → `NodeiSet.add`, medium | `Sets.Int_set.add`, medium | wrong callee | alias to a scanned functor instance not followed |
| languages/hack/generic/Parse_hack_tree_sitter.ml:74 | `Log.warn (fun m -> m "weird string literal: %s" s);` (file defines `module Log = (val Logs.src_log src : Logs.LOG)`) | → `Log.warn`, medium | `Parse_hack_tree_sitter.Log.warn`, medium | wrong callee | file-local first-class-module unpack named as the scanned top-level `Log` |
| libs/commons/Glom.ml:20 | `try Ok (str, Yojson.Basic.from_file ~fname:str str) with` | Glom.cli.parser → `basic.from_file`, medium | `Yojson.Basic.from_file`, medium | wrong callee | external path `Yojson.Basic` truncated to the scanned `libs/telemetry/ppx/ppx_tests/basic.ml` |
| src/osemgrep/cli_ci/Ci_subcommand.ml:292 | `let argv = [\| "empty" \|] and info_ = Cmdliner.Cmd.info "" in` | → `Cmd.info`, medium | `Cmdliner.Cmd.info`, medium | wrong callee | fully qualified external path truncated to a scanned module |
| src/lsp_legacy/Legacy_unit_ls.ml:27 | `\| _ -> failwith (Common.spf "Error running cmd: %s" (Bos.Cmd.to_string cmd))` | → `Cmd.to_string`, **high** | `Bos.Cmd.to_string`, medium | wrong callee / confidence | same truncation; it lands on a scanned definition of the same name |
| src/lsp_legacy/server/Legacy_lsp_.ml:169 | `let error = Response.Error.of_exn e in` | → `Error.of_exn`, medium | `Response.Error.of_exn` (via `open Jsonrpc`), medium | wrong callee | truncated to the scanned `src/osemgrep/core/Error.ml` |
| src/lsp_legacy/util/Legacy_convert_utils.ml:18 | `Range.create` (`open Lsp`, `open Types`) | → `Range.create`, medium | `Lsp.Types.Range.create`, medium | wrong callee | external open shadows the scanned `src/core/Range.ml` |
| languages/cpp/tree-sitter/Parse_cpp_tree_sitter.ml:2909 | `let t = dt (tvoid (ii_of_name n)) in` | → `dt`, low, direct | `dt`, unknown, callback | wrong confidence / call_type | function-valued record field bound by a pattern |
| libs/telemetry/Ometrics.ml:373 | `?attributes ?flags (metric_value_of_value v)` | → `metric_value_of_value`, low, direct | unknown, callback | wrong confidence / call_type | typed parameter of `let make_gauge_kind (type a) (metric_value_of_value : a -> metric_value)` |
| src/osemgrep/cli_scan/Scan_subcommand.ml:487 | `run ?file_match_hook conf.core_runner_conf conf.targeting_conf` | → `run`, low, direct | unknown, callback | wrong confidence / call_type | bound by `let { run } : Core_runner.func = …` |
| src/fixing/Hybrid_print.ml:74 | `with_fallback (primary (G.Ar arg))` | Hybrid_print.Make.printer#print_argument → `primary`, low | unknown, callback | wrong confidence / call_type | class/functor parameter |
| src/analyzing/Visit_class_defs.ml:24 | `f (Some ent) cdef;` | visitor#visit_definition → `f`, low | unknown, callback | wrong confidence / call_type | method parameter |
| src/ast_generic/AST_generic_helpers.ml:738 | `handle_any info (T type_) (fun () -> super#visit_type_ info type_)` | any_range_visitor#visit_type_ → `handle_any`, low | the named nested function of the class's `let … in` (high) | wrong callee / confidence | `class c = let f … in object … end`: the class-level lets are not named (classes are open defect ocaml/14) |
| src/ast_generic/AST_generic_helpers.ml:719 | `if pos_within charpos range then info.any := Some (any, range)` | caller `AST_generic_helpers.set_any_range` → `pos_within`, low | caller and callee are class-level lets (not top level) | wrong caller / callee | same |
| languages/go/menhir/parse_go.ml:42 | `let token lexbuf = Lexer.token lexbuf in` (`module Lexer = Lexer_go`) | → `Lexer.token`, **high** | `Lexer_go.token`, medium (generated from `.mll`, not scanned) | wrong callee / confidence | alias not followed; resolved to the declaration in another directory's `Lexer.mli` |
| libs/ocaml-tree-sitter-semgrep/core/src/gen/lib/Type_name.ml:72 | `match Pattern_name.infer pat with` | → `Pattern_name.infer`, **high** | medium (only `Pattern_name.mli` / `.mll` are in the scan) | wrong confidence | a prototype whose definition is not in the scan is medium (Decisions 2026-11-09) |
| src/prefiltering/Predicate.ml:26 | `let pat = Search_pattern.create ~case_sensitive needle in` (`let module Search_pattern = Base.String.Search_pattern in`) | → `Search_pattern.create`, medium | `Base.String.Search_pattern.create`, medium | wrong callee | open defect ocaml/13 (local module alias) |
| src/analyzing/Eval_il_partial.ml:201 | `&& (not @@ Int.equal (sign_bit r) (sign_bit i1))` (under `let open Int64_ in`) | → `Int64_.not`, medium | `Stdlib.not`, medium | wrong callee | an unresolved name under a local open of a module with `include Int64` is attributed to that module, but neither `Int64_` nor `Int64` defines `not` |
| src/analyzing/Visit_class_defs.ml:33 (sample 48) | `let visitor_instance = lazy_safe (new visitor)` | Visit_class_defs.visitor_instance → `lazy_safe`, low | — | spec gap | ppx special function, inside a top-level value let |
| src/sca/Dependency.ml:55 (sample 49) | `let format_kind f kind = Format.fprintf f "%s" (show_kind kind) in` | Dependency.kind_testable.format_kind → `show_kind`, low | — | spec gap | `[@@deriving show]`-generated function, inside a function nested in a top-level value let |

## Systematic patterns (scripted counts; union 1430)
The census script is `s-semgrep_r12_census.py`. I checked each pattern by hand on 3–8 edges.
1. **W1, file-level module alias to an external module or functor instance not followed: 1305.** `module X = A.B` gives callee `X.f` (medium) instead of `A.B.f`. By alias target: Cmdliner.* 594 (`Arg`, `Cmd`, `Term`, `Cmdl`, `XCmd`); `Log_*.Log` 289; other 422 (`C = Configurator.V1`, `F = Format`, `Otel = Opentelemetry`, `Sarif = Sarif.Sarif_v_2_1_0_v`, `YS = Yojson.Safe`, `NodeiSet = Sets.Int_set`, `VarMap = Var_env.VarMap`, `Lexer = Lexer_python`, `E = Easy_format`, …). Aliases to scanned top-level modules are followed (for example `G.e` → `AST_generic.e`). Where the alias name is also a scanned module (`Log`, `Cmd`), the ID names a member that the scanned module does not define (C2).
2. **W5, call through a function-valued variable emitted as low direct instead of callback unknown: 32.** The variables are pattern-bound record fields (`dt`, `run`, `hook`), method and class parameters (`f`, `fix`, `error`, `primary`), and a parameter after `(type a)`. Plain function parameters are handled correctly: 2,558 unknown callbacks.
3. **W2, qualified external path truncated to a scanned module's name: 23.** `Yojson.Basic.x` / `Y.x` → `basic.x` (20); `Cmdliner.Cmd.info` → `Cmd.info`; `Bos.Cmd.to_string` → `Cmd.to_string` (high); `Response.Error.of_exn` → `Error.of_exn`.
4. **W3/W3b, top-level external open shadows a scanned module name: 24.** `open Cmdliner` with `Cmd.*` (20); `open Lsp` / `open Types` with `Range.*` (4).
5. **W1b, `Log.*` where the file defines its own `module Log = (val …)`: 14.**
6. **W6, class-level `let … in` functions: 14.** The caller is named as a top-level function, and the callee is a low bare name. This is output under open defect ocaml/14.
7. **W4, bare name under an external local open `M.( … )` left low: 7.** `Bos.Cmd.(v …)`, `Cmdliner.Cmd.(eval_value … (v …))`.
8. **W9, Stdlib name attributed to a locally opened module (`Int64_.not`): 5.**
9. **W7, high edge to a module with no scanned `.ml`: 4.** These are `Lexer.token` (3, aliases to generated lexers, matched to another directory's `Lexer.mli`) and `Pattern_name.infer` (1, `.mli` only).
10. **W8, `let module X = … in` alias not followed (open defect ocaml/13): 2.**

## Missed-call patterns (recall)
I traced three functions, each against the tool's edges with that caller:
- `Rule_fetching.parse_rule` (src/osemgrep/networking/Rule_fetching.ml:322): 12 calls, 12 found.
- `Find_targets.git_list_files` (src/targeting/Find_targets.ml:610): 20 calls, 20 found. Its 4 `Log.*` edges have the wrong callee (W1).
- `Spacegrep_main.run_all` (src/spacegrep/src/bin/Spacegrep_main.ml:84): 28 calls, 28 found.

That is 0 missed of 60 and 0 non-calls. Two constructs get no edges and are not counted as misses:
- **Operators.** `|>`, `@@`, `!!`, `:=`, `!`, `let/` and arithmetic get no edges. This is the undecided item ocaml/15.
- **Object method sends.** `obj#m`, `self#m` and `super#m` get no edges anywhere: there are 0 edges whose callee contains `#`. A text grep finds about 480 such sends in in-scope `.ml` files (self 189, super 123, …). This is open defect ocaml/14; the edges are absent, not wrong.

## Spec gaps (union 1954 edges, not counted as wrong)
- **G2, caller of a call inside a top-level non-function binding: 1615.** Example: `let empty_env = { …; eval_plus_object = (fun _ _ _ _ -> failwith "…") }` (libs/ojsonnet/Value_jsonnet.ml:151), where the tool gives the caller `Value_jsonnet.empty_env`. This is CAPABILITIES ocaml/16. SPEC leaves open whether the caller is the module (`Value_jsonnet`) or the binding (`Value_jsonnet.empty_env`). The same question applies to functions nested in such a binding (`Dependency.kind_testable.format_kind`).
- **G1, functions generated by `[@@deriving show, eq, ord, yojson]`: 182.** Examples: `AST_generic.show_expr` at medium; a bare `show_kind` / `to_yojson` in the deriving file at low. SPEC's "Generated functions have no written body" ruling covers scanned macros (Elixir, C/C++). SPEC leaves open whether a function generated by an external ppx from a scanned type declaration is named `Module.f` and at which tier (medium as generated, high as "defined in the scan", or low).
- **G4, member of an external module brought in by `include` into a scanned module: 119.** Examples: `module List = struct include List … end` followed by `List.map` (languages/csharp/generic/Parse_csharp_tree_sitter.ml), giving `Parse_csharp_tree_sitter.List.map`, medium; `Int64_.abs` (libs/commons/Int64_.ml has `include Int64`); bare `equal` / `mul` inside Int64_.ml at low. SPEC leaves open whether the callee is the including module's ID or the included external definition's (`List.map`, `Int64.abs`), and whether names reached through an external `include` count as resolved.
- **G3, `lazy_safe e`, a ppx special function rewritten by the scanned `libs/commons/ppx/ppx_commons.ml`: 31.** SPEC leaves open whether this is an invocation of `lazy_safe` (low bare name), a macro, or no edge.
- **G5, functions bound by a top-level tuple pattern: 6.** The binding is `let is_fake, set_fake = make_flag bitmask_FAKE` (src/ast_generic/IdFlags.ml:27), and calls give `IdFlags.is_fake`, medium. SPEC leaves open whether such a pattern-bound module-level function is a defined function (high) or a binding (medium).
- **G6, call into a functor's module parameter: 1.** `module Make (Token : Matcher.Token) … Token.kind tok` gives `Token.kind`, medium, which names the scanned `Token.ml`. SPEC leaves open the ID and tier for a call through a functor parameter (the module parameter, unknown? the signature `Matcher.Token#kind`?).
