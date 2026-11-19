# s-spark2014 (OCaml): blind call-graph review, round 7

precision 46/50; census ≈99.33% (388 wrong of 58182 in-scope); recall: 0 missed of 91 real calls; 0 non-calls

## Scope
Tool output: `<scans>/ocaml36-A/s-spark2014.v2.json`, 70,849 edges. Source root: `.../languages/ada/spark2014`. The OCaml in this repo is the vendored Why3 tree (`why3/src`, `why3/plugins`, `why3/bench`, `why3/examples_in_progress`, `why3/misc`). In scope means `source_file` ends in `.ml` and has no path segment named test/tests/spec/examples/docs. That leaves **58,182 edges in 272 files**. The `.py`, `.c`, `.java`, `.js` and `.h` edges are out of scope.
- By confidence: high 38,971; medium 17,413; unknown 1,448; low 350.
- By call_type: direct 56,734 (high 38,971 / medium 17,413 / low 350); callback 1,448 (all unknown). There are no method, constructor, macro or implicit edges. That fits OCaml under SPEC: the classes and objects that would produce `method` edges are open defect ocaml/14.
- I ignored the `measured_accuracy` field.

Sample: seed 20261116; high 27, medium 13, unknown 5, low 5; 43 files. Helper scripts are `s-spark2014_r7_*` in the fanout folder.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| why3/src/tools/why3pp.ml:244 (sample #45) | `fprintf fmt "%a %s %a" pp_term t1 op pp_term t2` | why3pp.LatexInd.pp_term → `fprintf`, low, direct | → `Format.fprintf`, medium. Inside `LatexInd` the only external open is `open Format`. `open Conf` opens the functor parameter, whose signature in the scan (`sig val prefix … val flatten_applies … val comment_macros … end`) has no `fprintf`. | wrong callee / wrong confidence | Format name left as a bare low guess (W1) |
| why3/src/core/pretty.ml:1072 (sample #48) | `pp_print_string fmt "Cannot close theory: some namespaces are still open"` | pretty → `pp_print_string`, low, direct | → `Format.pp_print_string`, medium. Format is the file's only external open. The `include LegacyPrinter` at line 798 is a `(val … : Printer)` whose signature in the scan has no such name. | wrong callee / wrong confidence | open defect ocaml/13 (include not followed) (W1) |
| why3/src/session/session_itp.ml:2022 | `\| Some s -> fprintf fmt "@ %s=\"%a\"" lab pr s` | session_itp.opt → `fprintf`, low | → `Format.fprintf`, medium (`open Format` at lines 536 and 1938; the other opens are scanned modules) | wrong callee / wrong confidence | Format name left low (W1) |
| why3/src/mlw/expr.ml:153 (sample #46) | `mk_rs (id_register id) c RLlemma None` | expr.create_rsymbol → `mk_rs`, low, direct | → `expr.mk_rs`. It is defined in the scan by `let mk_rs, restore_rs =` (line 46), a top-level binding that holds a function (C1). The tier is a spec gap (S1). | wrong callee | tuple-pattern top-level binding not resolved (W2) |
| why3/src/mlw/pmodule.ml:1861 (sample #47) | `(register_module inst intf mimpl.mod_impl, mimpl)` | pmodule.close_module_with_intf → `register_module`, low | → `pmodule.register_module` (`let register_module, restore_module_id, restore_module =`, line 1643) | wrong callee | W2 |
| why3/src/transform/case.ml:47 | `let t_not_decl = Decl.create_prop_decl Decl.Paxiom hnot (Term.t_not t) in` | case → `wstdlib.MakeMSHW.create_prop_decl`, medium | → `decl.create_prop_decl`, high. decl.ml's internal `module Decl = MakeMSHW(…)` (line 395) is not exported by decl.mli, so `Decl.` here is the compilation unit. MakeMSHW defines only submodules T/M/S/H/W. | wrong callee / wrong confidence | invented ID, C2 (W3) |
| why3/src/ide/why3_js.ml:537 | `let parent = Js.Opt.to_option parent in` | → `opt.to_option`, medium | → `Js.Opt.to_option`, medium (external js_of_ocaml path). why3's scanned opt.ml defines no `to_option`. | wrong callee | external path collapsed onto a scanned file module (W4) |
| why3/src/session/session_itp.ml:1272 | `let c = C.input_char ch in` | → `c.input_char`, medium | not `c.*`. `C` is the functor parameter of `module ReadShapes (C:Compress.S)`, not why3/src/extract/c.ml, which has no `input_char`. | wrong callee | functor parameter mapped onto a scanned file module (W4) |
| why3/src/infer/infer_loop.ml:57 | `let cfg = Infer.start_cfg () in` | → `infer.start_cfg`, medium | not bddinfer/infer.ml, which has no `start_cfg`. `Infer` is the local `let module Infer = …` at line 45. | wrong callee | open defect ocaml/13 (local module not followed) (W4) |
| why3/src/infer/reduction_engine.ml:41 | `\| Number.ConstInt i -> Number.compute_int i` | → `number.compute_int`, medium | scanned number.ml defines no `compute_int`. C2 forbids a medium ID naming it, so per C4 it is a low guess. | wrong callee / confidence | invented member ID, C2 (W5) |
| why3/src/core/decl.ml:389 | `\| Dprop (k,pr,f) -> Hashcons.combine (hs_kind k) (hs_prop (pr,f))` | decl.hash → `hs_kind` / `hs_prop`, low | → the definitions at lines 380/376 in the same struct (`decl.hs_kind` / `decl.hs_prop`; the tool lists `decl.hs_prop` as a node), high | wrong callee / confidence | C1, definition in a functor-argument struct not used (W6) |
| why3/src/mlw/pinterp.ml:1662 | `match id.id_loc with Some loc -> add (id, loc) locs \| None -> locs` | pinterp.Sidpos.add_id → `add`, low | the `add` of `include Set.Make (…)` in `module Sidpos` (included external member, medium, as `exthtbl.Make.find` is given) | wrong callee / confidence | open defect ocaml/13 (include) (W6) |
| why3/src/parser/report.ml:77 | `match Parser_messages.message s with` | → `parser_messages.message`, high | medium. The scan has only parser_messages.mli (menhir-generated module, no implementation), a body-less prototype. | wrong confidence | W7 |
| why3/src/ide/gconfig.ml:330 (sample #33) | `let get_main () = (get_main (config ()).config)` | gconfig.get_main → `gconfig.config`, medium | the ID is right. Whether a top-level tuple-pattern binding of closures is high or medium is undecided. | spec gap | S1 |

## Systematic patterns (wrong), by scripted count
Script: `s-spark2014_r7_census.py`. The union of wrong edges is 388.
1. **W1, bare Format names left as low guesses where `Format` is the only external open: 179.** pretty.ml 50 (after `include LegacyPrinter`), why3pp.ml `LatexInd` 101 (`open Format` + `open Conf`), session_itp.ml 28. The correct edge is `Format.<name>`, medium. Hand-checked pretty.ml:809/1072, why3pp.ml:244, session_itp.ml:2022. In pretty.ml the same written `fprintf` before line 798 is `Format.fprintf` medium (165, 171, 176).
2. **W3, `Ty.` / `Decl.` / `Ity.` qualified calls named `wstdlib.MakeMSHW.<f>`, medium: 112.** These are invented IDs. ty.ml, decl.ml and ity.ml each have an internal `module Ty|Decl|Ity = MakeMSHW (…)` that their .mli does not export. The same calls elsewhere resolve correctly (`decl.create_prsymbol` 73, `ty.ty_equal` 89, `ty.ty_inst` 39, all high). Hand-checked case.ml:45–48, pmodule.ml:445, pdriver.ml:161.
3. **W2, calls of structure-level tuple-pattern bindings (`let a, b, c = … (fun …), (fun …)`) left as bare low guesses: 54.** big_real.ml 21, expr.ml 11, pmodule.ml 11, vc.ml 9, termcode.ml (`Checksum`) 2. Other names from the same kind of binding do resolve (`expr.restore_rs`, `big_real.init`, `ity.restore_pv`), which is inconsistent under C1. Hand-checked big_real.ml:20/50, vc.ml:573/700, pmodule.ml:289/318.
4. **W4, external or parameter module paths collapsed onto a scanned file module: 29.** `Js.Opt.*` → `opt.*` 8; `GtkMain.Main.init` / `Db.Main.extend` → `main.*` 2; `Ppxlib.Driver.*` → `driver.*` 2; `Sexplib.Sexp.*` → `sexp.*` 2; functor parameter `C:Compress.S` → `c.*` 6; local `let module Infer` → `infer.*` (bddinfer) 8; Frama-C `Ast.get` → `ast.get` 1.
5. **W5, medium IDs naming a member the scanned module does not define (C2): 9.** `number.compute_int` 5, `number.int_const_dec` 1, `mlw_expr.e_app` / `create_let_pv_defn` 2 (mlw_expr.ml is the scanned examples/use_api file), `loc.report_position` 1.
6. **W6, definitions reached through a functor-argument struct or an external include not resolved: 4.** decl.ml:389 ×2; pinterp.ml `Sidpos` `add`/`mem` ×2.
7. **W7, high for a module with only an .mli in the scan: 1** (`parser_messages.message`).

## Missed-call patterns (recall)
- The three recall functions each have every call covered:
  - `subst.find_equalities` (why3/src/transform/subst.ml:204–268): 47 of 47.
  - `gconfig.load_ide` (why3/src/ide/gconfig.ml:133–203): 28 of 28.
  - `vc.cty_enrich_post` (why3/src/mlw/vc.ml:407–427): 16 of 16.

  Their callers, callees, tiers and lines are all correct, and nothing in them is a non-call. Infix operators (`&&`, `=`, `<>`) get no edges; that is spec gap ocaml/15 and is not counted.
- **Calls through a record field holding a function (`res_parser.prp_model_parser printing_info model_str`, `lang.push env path c`, `spa.spa_callback (…)`, `printer.sanitizer s`): about 65 with no edge.** That is open defect ocaml/04. A regex found 114 head-position `r.f arg` candidates with no edge on the line (`s-spark2014_r7_recfield.py`). In a 30-candidate hand check, 17 were real calls; the rest were argument continuation lines. The ≈65 is an estimate from that ratio, not an exact count.

## Spec gaps (not counted as wrong)
- **ocaml/16, caller of calls inside top-level non-function value lets: ≈2,988.** 2,853 edges take the binding as caller (`gconfig.set_attr_flag`, `subst.get_decls`, `main.input`). 135 take the module (mostly tuple-pattern value lets such as `let provers, prover_ce, prover_warn, config, env =`, gnat_config.ml:366). Open question: is the caller of a call inside a top-level non-function binding the module or `module.binding`? And what is it for a tuple pattern, which has no single name?
- **ocaml/15, operators and application operators: 92 edges plus 4 operator-named callers.** The tool emits edges for the function applied by `|>` (66) and `@@` (26); for example `tac @@ t_implies g (t_neg h)` → `tac` (coma_logic.ml:105), and `… |> Mvs.of_list` (subregion_analysis.ml:335). Callers named after operator definitions: `jsmain.(<|)` ×3, `forward_propagation.(<=.)` ×1. Open question: does `x |> f` / `f @@ x` call f, and what is the definition ID of `let ( <| ) …`?
- **S1, tier of a top-level tuple-pattern binding of closures: 55.** For example `gconfig.config` from `let config,load_config = let config = ref None in (fun () -> …), (fun conf -> …)` is given medium (also `ity.restore_pv` 22, `expr.restore_rs` 13, `ity.restore_its` 9, `debug.Args.option_list` / `loc.Args.option_list` 3). Open question: is a function bound by a tuple pattern whose components are function literals a named function (high), a binding (medium), or a call through a value (callback, unknown)?
- **S6, module implementation chosen at configure time: 91.** `mlmpfr_wrapper.*` is high, but the scan holds only `mlmpfr_wrapper.mli` plus the alternative implementations `mlmpfr_real.ml` / `mlmpfr_dummy.ml` / `mlmpfr_old.ml`, which Makefile.in copies into place. Open question: is a module whose implementation file is one of several configure-selected sources under other names "defined in the scan" (high), and under which ID?
- **S2, several external top-level opens: 67.**
  - ity.ml: `open Mysexplib.Std` + `open Format` (55; Mysexplib exists only as mysexplib-real.ml / mysexplib-dummy.ml).
  - bindings.ml: `open Js_of_ocaml` + `open Js` (6).
  - bigInt.ml: `open Mysexplib.Std_big_int` + `open Big_int_Z` (1).
  - examples_in_progress/bigInt: `open Why3extract` / `Format` / `BigInt__N` (5).

  The tool leaves these bare names low. Open question: SPEC names "the innermost external local open" and "the one external open". With two or more external top-level opens, does the last one opened win (`Format.fprintf`), or does the name stay low?
- **S3, names reached through `include` of a first-class module: 7** (ity.ml `print_ts` / `print_tv` / `print_vs` / `forget_var` via `open Pretty`, where pretty.ml has `include LegacyPrinter` and `module LegacyPrinter = (val (… create …) : Printer)`). Open question: what ID do members of an unpacked first-class module get? Is it the definition inside `create`'s `(module struct … end)`, or `pretty.<name>`?
- **S4, name defined nowhere in the scan, in a file with one external open: 4** (uf_domain0.ml `t_push_negation` / `t_inline_all`; opens `Domain`, `Apron`, `Term`). Open question: does the "one external open (medium)" rule apply (`Apron.t_push_negation`) when the name is in neither the scan nor, evidently, the library (dead, uncompiled file), or does it stay a low guess?
- **S5, members of a function-local `let module M = struct … end`: 2** (gnat_ast_to_ptree.ml:501–502, the recursive `map` inside `let module M = struct let rec map …`). The tool gives caller `gnat_ast_to_ptree.map` and callee bare `map`, low. Open question: what is the ID of a definition inside a function-local structure (`outer.M.map`?), and is its self-call high?
- **S7, member path through a functor parameter's submodule: 2** (`S.Infer_why3.t_push_negation` → `infer_why3.t_push_negation`, medium, quant_domain.ml:95). Open question: does a functor parameter's submodule name the scanned module of that name?

## Sample verdicts (seed 20261116)
- Correct (45): #0–#32, #34–#44 and #49.
  - Callbacks #40–#44 are parameters (`merge`, `fe`, `fn`, `sep`, `lsmap`).
  - #49 `t_label_copy` is defined nowhere in the scan, and reduction_engine.ml's only open is the scanned `Term`, so the low guess is correct.
- Spec gap (1): #33 (S1).
- Wrong (4): #45 and #48 (W1); #46 and #47 (W2).
