# Blind call-graph review: s-ocaml (OCaml compiler), round 13

precision 37/50; census ≈99.60% (317 wrong of 79741 in-scope); recall: 3 missed of 50 real calls; 0 non-calls

## Scope
- Tool output: `<scans>/ocaml36-A/s-ocaml.v2.json`, 131,784 edges in total.
- In scope: `.ml` edges that are not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment. That is **79,741 edges in 499 files**. Most of the excluded `.ml` edges are under `testsuite/tests/`. `testsuite/tools/`, `boot/menhir/`, `flexdll/`, `manual/` and `stdlib/` are in scope.
- Confidence split: high 76,181, unknown 2,373, medium 1,099, low 88.
- call_type split: direct 77,368, callback 2,373. No method, constructor, macro or implicit edges.
- I ignored the `measured_accuracy` field.
- The scan contains the standard library's own sources, so under Decisions 2026-11-12 the stdlib definitions are the correct targets (`stdlib.raise`, `list.map`).

**Precision sample.** Seed 13, stratified: high 35, unknown 5, medium 5, low 5, spread over 38 files. 37 edges are correct, 9 are wrong and 4 are spec gaps (37/46 among the edges the spec decides). The wrong edges are all in the medium and low tiers (4/5 and 5/5). The 35 high edges and 5 unknown edges have no errors.

**Helper scripts.** All in the fanout folder, prefix `s-ocaml_r13_`: `load`, `sample`, `ctx`, `tiers`, `lows`, `meds`, `medlow`, `nodes`, `soup`, `fparam`, `letmod`, `optdef`, `optdef2`, `unk`, `valuelet`, `recall`, `census`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| utils/strongly_connected_components.ml:161 | `Id.Set.fold (fun dest acc ->` | strongly_connected_components.Make.number → set.fold, medium, direct | `Id` is the functor parameter `Make (Id : Identifiable.S)`. `set.fold` names a member that stdlib `set.ml` does not define at top level (C2, invented ID) | wrong callee | functor parameter resolved to a scanned file of the same lowercased name |
| middle_end/flambda/freshening.ml:376 | `\|\| T.Map.is_empty later` | freshening.Project_var.Compose.compose → map.is_empty, medium, direct | `T` is the parameter of `Compose (T : Identifiable.S)`, not stdlib `map.ml` (C2) | wrong callee | same |
| lambda/switch.ml:673 | `Arg.make_if` | switch.Make.make_if_test → arg.make_if, medium, direct | `Arg` is the parameter of `Make (Arg : S)`, not stdlib `arg.ml` (C2) | wrong callee | same (25 edges in this file) |
| middle_end/flambda/base_types/id_types.ml:73 | `else Compilation_unit.compare x.unit y.unit` | id_types.UnitId.compare → compilation_unit.compare, **high**, direct | `Compilation_unit` is the parameter of `UnitId(Innerid:Id)(Compilation_unit:Identifiable.Thing)`, not middle_end/compilation_unit.ml | wrong callee | same, promoted to high because the file defines `compare` |
| manual/src/html_processing/src/process_api.ml:127 | `prepend_child header (logo_html` | process_api.make_toc → Soup.logo_html, medium, direct | `logo_html` is defined in `common.ml.in` (`open Common` comes after `open Soup` and shadows it) | wrong callee | bare name sent to the first external open instead of the later, shadowing one |
| manual/src/html_processing/src/process_manual.ml:62 | `dbg "%s : %s" name title;` | process_manual.register_toc_entry → Soup.dbg, medium, direct | `dbg` is Common's (`let dbg =`, common.ml.in:16) | wrong callee | same |
| flexdll/create_dll.ml:372 (also :384, :403) | `emit_int32 oc 0l; (* size of initialized data *)` | create_dll.create_dll → emit_int32, low, direct | `coff.emit_int32`, high (`open Coff` at create_dll.ml:13, inside `include (struct … end)`; coff.ml:222) | wrong callee / confidence | opens and definitions inside `include (struct … end)` are not used for resolution |
| typing/persistent_env.ml:143 | `error (Inconsistent_import(name, auth, source))` | persistent_env.check_consistency → error, low, direct | `persistent_env.error`, high. It is defined at :33 inside `include (struct … end)` and is a node in the output | wrong callee / confidence | same (C1: reference does not use the definition's ID) |
| middle_end/compilation_unit.ml:71 | `\| Some cur -> equal cur arg` | compilation_unit.is_current → equal, low, direct | the node `compilation_unit.equal` (defined at :48 in `include Identifiable.Make (struct … end)`), high | wrong callee / confidence | definitions in an anonymous struct argument are named, but calls to them are not resolved (C1) |
| middle_end/flambda/flambda_utils.ml:717 | `Let (var, make_named_key defining_expr, make_expr_key body)` | flambda_utils.make_expr_key → make_expr_key / make_named_key, low, direct | the nodes `flambda_utils.make_expr_key` / `.make_named_key`, high (recursion inside `Switch.Store (struct … end)`) | wrong callee / confidence | same |
| typing/typing_recovery.ml:99 | `if Int.equal (compare_position a_start b_start) 0` | typing_recovery.compare → compare_position, low, direct | the node `typing_recovery.compare_position`, high (`Set.Make (struct … end)`) | wrong callee / confidence | same |
| flexdll/create_dll.ml (34 edges) | `let buf = Buf.create () in` | create_dll.create_dll.treat_sect.mk_sect → Buf.create, medium | `coff.Buf.create`, high (coff.ml:14 `module Buf`) | wrong callee / confidence | `open Coff` inside the include struct is not followed (also `Section.*` 6 and `symbol.*` 3, where the last collides with middle_end/symbol.ml) |
| driver/compenv.ml:656 | `compile_implementation ~start_from ~source_file:name ~output_prefix:opref;` | compenv.process_action.impl → compile_implementation, low, direct | `compile_implementation`, callback, unknown (bound by the record pattern `let { …; compile_implementation; … } = ctx`) | wrong confidence / call_type | function value bound by a record pattern is treated as a bare unresolved function |
| typing/env.ml:385 | `\| Map {f; next} -> f (find_same id next)` | env.IdTbl.find_same → f, low, direct | `f`, callback, unknown | wrong confidence / call_type | same |
| utils/binutils.ml:681 | `defines_symbol symname` (in `let defines_symbol {defines_symbol; _} symname =`) | binutils.defines_symbol → defines_symbol, low, direct | `defines_symbol`, callback, unknown | wrong confidence / call_type | same |
| ocamldoc/odoc_html.ml:1709 | `bp b "<span id=\"%s\">%s</span>&nbsp;: " (gen_name r) r.rf_name;` | odoc_html.Generator.html#html_of_record.print_one → gen_name, low, direct | `gen_name`, callback, unknown (parameter of `method html_of_record … gen_name b l`) | wrong confidence / call_type | method parameter not recognised as a parameter |
| ocamldoc/odoc_html.ml:1091 | `method print_header b ?nav ?comments title = header b ?nav ?comments title` | odoc_html.Generator.html#print_header → header, low, direct | `header`, callback, unknown (`val mutable header = fun …`, a stored property holding a function) | wrong confidence / call_type | instance variable holding a function |
| driver/compenv.ml:763 | `let parse_arguments ?(current=ref 0) argv f program =` | compenv.parse_arguments → ref, unknown, callback | `stdlib.ref`, high, direct | wrong callee / confidence / call_type | a name used in an optional-argument default is treated as a parameter |
| utils/misc.ml:1243 | `let make fn ?(dev = not Config.is_official_release)` | misc.RuntimeID.make → not, unknown, callback | `stdlib.not`, high, direct | wrong callee / confidence / call_type | same (also typing/env.ml:2644 `let shadowed = ref [] in` in the same function, a call outside the default itself) |
| middle_end/flambda/build_export_info.ml:248 | `assert (Closure_id.equal closure_id closure_id');` | build_export_info.descr_of_named → closure_id.equal, medium, direct | the defining ID through the include chain `closure_id → include Closure_element → include Variable → include Identifiable.Make (struct … let equal …)`, high | wrong callee / confidence | open defect ocaml/13 (include chains not followed) |
| toplevel/toploop.ml (process_phrase) | `let phr = preprocess_phrase ppf phr in` | toploop.process_phrase → toploop.preprocess_phrase, medium | `topcommon.preprocess_phrase`, high (`include Topcommon`, topcommon.ml:193) | wrong callee / confidence | open defect ocaml/13 |
| parsing/unit_info.ml:44 | `match Utf8_lexeme.capitalize s with` | unit_info.strict_modulize → utf8_lexeme.capitalize, medium | the same ID at high (utils/utf8_lexeme.ml:244 defines it) | wrong confidence | defined in the scan but rated medium. A same-named file also exists at testsuite/tests/unicode/utf8_lexeme.ml |
| tools/objinfo.ml:498 | `LargeFile.seek_in ic offset;` | objinfo.dump_obj.dump_cmxs → largeFile.seek_in, medium | `stdlib.LargeFile.seek_in`, high (stdlib.ml:516) | wrong callee / confidence | resolved to testsuite/tests/…/largeFile.ml instead of Stdlib's LargeFile (C2) |
| typing/typeclass.ml:1799 | `Format_doc.doc_printf "%a" (Printtyp.Doc.class_declaration id) clty` | typeclass.final_decl → Printtyp.Doc.class_declaration, medium | `printtyp.Doc.class_declaration`, high (printtyp.ml:22/70). The alias `module Printtyp = Printtyp.Doc` comes later, at :2073 | wrong callee / confidence | a later module alias breaks an earlier qualified reference (definition order) |
| bytecomp/bytelink.ml:360 | `output_string outchan (String.trim s);` | bytelink.write_sh_launcher.l.output → .output_string, medium, direct | `stdlib.output_string`, high | wrong callee / confidence | `let open struct type tag = … end in` turns bare names into `.name` |
| ocamldoc/odoc_print.ml:43 | `flush_type_fmt ()` | odoc_print.string_of_type_expr → flush_type_fmt, low | ID `odoc_print.flush_type_fmt` (a module-level binding, `let (type_fmt, flush_type_fmt) = new_fmt ()`, C1); tier is a spec gap | wrong callee | a module-level tuple-pattern binding is not resolved from its own file |
| typing/ctype.ml:1917/1940/1942 | `!unify_var' uenv ~check_occur:true p a` | (no edge) | a dynamic invocation of the function held in the ref `unify_var'` (C3/C4); the ID form is a spec gap | missed call | application of a dereferenced ref is not emitted |
| boot/menhir/parser.ml:38647 | `= Obj.magic _1 in` (inside `let semantic_action = [| … |]`) | parser.Tables.semantic_action → obj.magic, high | callee correct. Is the caller `parser.Tables.semantic_action` or `parser.Tables`? | spec gap | value-let caller (CAPABILITIES ocaml/16) |
| asmcomp/riscv/proc.ml:113 | `Array.append hard_int_reg hard_float_reg` (in `let all_phys_regs =`) | proc.all_phys_regs → array.append, high | callee correct; caller as above | spec gap | value-let caller |
| tools/lintapidiff.ml:205 | `(Filename.quote obj) (Filename.quote tmp) in` | lintapidiff.Git.with_show → filename.quote, medium | `quote` reaches `filename` only through `include Sysdeps`, where `Sysdeps = (val (match Sys.os_type with …))` | spec gap | include of a first-class module |

## Systematic patterns (wrong), by scripted count
Counted by `s-ocaml_r13_census.py`. I enumerated all 88 low edges and all 1,099 medium edges by callee group and checked each group by hand. For every pattern I hand-checked at least two edges.

1. **Definitions and opens inside an anonymous structure are not used for resolution: 102.** This covers `include (struct … end)` and functor arguments `F (struct … end)`.
   - The tool names the definitions as members of the enclosing module (`create_dll.read_int32`, `persistent_env.error`, `typing_recovery.compare_position`, `flambda_utils.make_expr_key` are all nodes). Calls to them, and calls through the struct's own `open Coff`, stay bare low guesses or uppercase medium names (C1).
   - flexdll/create_dll.ml accounts for 44 low edges (`emit_int32` 29, `emit_int16` 8, `read_int32` 2, `align`, `discard_section`, `sect_data`, `split_relocs`, `patch_int32`). It also has 43 medium edges (`Buf.*` 34, `Section.*` 6, `symbol.*` 3), which should be `coff.Buf.*`, `coff.Section.*`, `coff.Symbol.*`.
   - The other 15 are low: persistent_env 3, flambda_utils 4, compilation_unit 1, symbol 1, variable 1, shape 2, typecore `get_type` 1, typing_recovery 2.
2. **Functor parameter resolved to a scanned file of the lowercased name: 66 medium + 1 high.**
   - Medium: `arg.*` 25 (switch.ml `Arg`), `map.*` 15, `set.*` 3 (`T.Map`, `Id.Set`, `Module_name.Set`), `e.*` 6 (pqueue `E`, topcommon `E`), `a.*` 4, `b.*` 3, `d.*` 3, `m.*` 2, `parser.lexer_definition` 1 (lex's own Parser vs boot/menhir/parser.ml), `largeFile.seek_in` 4 (Stdlib.LargeFile vs a testsuite file).
   - High: `compilation_unit.compare` in id_types.ml.
   - The colliding files are often testsuite files (e.g. testsuite/tests/typing-multifile/e.ml). So resolution depends on which other files are present (C2). Parameters with no same-named file keep their written form (`O.size`, `T.instr_size`).
3. **Bare name sent to `open Soup` although the later `open Common` defines it: 55.** Examples: `dbg` 31, `html_file`, `logo_html`, `string_of_opt`, `starts_with`, `wrap_body`, `update_head` and others. All are defined in manual/src/html_processing/src/common.ml.in, and in OCaml the later open shadows the earlier one.
4. **Include chain not followed (open defect ocaml/13): 43 medium.** `closure_id.*` 19, `static_exception.*` 5, `tag.*` 3, `mutable_variable.*` 3, `linkage_name.*` 2, `export_id.*` 2, `set_of_closures_id.*` 2, `var_within_closure.*` 2, `toploop.*` 5. Each module gets these members only through `include X` / `include Identifiable.Make (…)` chains.
5. **Function value bound by a pattern or method parameter, called as a low direct bare name instead of `callback`/unknown: 26.**
   - Record patterns: compenv 2, compmisc 1 (`Clflags.{ parse; … }` parameter), filecompare 1, parmatch `type_row` 3, env `f` 3, signature_matching `{f}`/`{m}` parameters 7, typecore `let { is_self; type_with_constraint; type_without_constraint } =` 3, binutils 2, local_store `Table { ref; init }` 2.
   - Method parameter `gen_name` 1, and instance variable `val mutable header = fun …` 1.
6. **Names in optional-argument defaults treated as parameters (callback, unknown): 12.**
   - `?(x = ref …)`, `?(dev = not …)`, `?(copy=deep_copy ())`, `?(lev=get_current_level ())` all become callbacks of the parameter name.
   - In env.open_signature the effect covers the whole function: `let shadowed = ref [] in` at :2644 is also `ref` callback/unknown.
   - Correct: `stdlib.ref`, `stdlib.not`, `typecore.Error.deep_copy`, `ctype.get_current_level`, high, direct.
7. **Defined in the scan but rated medium: 5.** `utf8_lexeme.capitalize` / `is_valid_identifier`.
8. **Module-level tuple-pattern binding not resolved in its own file: 3.** `odoc_print.flush_type_fmt` / `flush_modtype_fmt` are emitted as bare low names and are missing from `nodes` (C1).
9. **`let open struct … end in` breaks resolution: 2.** bytelink `.output_string`, `.output_char`.
10. **Qualified reference before a later same-named module alias: 2.** typeclass `Printtyp.Doc.*` at :1799/:1802, before `module Printtyp = Printtyp.Doc` at :2073. After the alias, the same calls resolve correctly to `printtyp.Doc.*` high.

Union: 317 wrong of 79,741, so census precision ≈ 99.60%.

Checked and found correct (not wrong):
- local `let module X = …` aliases, including the shadowed `W` in unbox_closures.ml;
- late `open Format_doc` in typecore.ml, respected in definition order;
- `module String = Misc.Stdlib.String` resolving to `string.*`;
- one-level `include` such as `Var_within_closure.unwrap` → `closure_element.unwrap`;
- `external` stdlib primitives (`stdlib.not`, `obj.magic`);
- 25 extra random unknown-tier edges, all parameters or locals holding functions.

## Missed-call patterns (recall)
- ctype.subst: 24 real calls, 21 emitted and correct, 3 missed. The misses are the dynamic invocations `!unify_var' …` at :1917, :1940 and :1942 (a call of the function stored in a ref). No edge is emitted.
- cmi_format.read_cmi: 15 real calls, 15 emitted and correct.
- binutils.ELF.read_symbols (including the nested `mk`): 11 real calls, 11 emitted and correct.
- Total: 3 missed of 50 real calls, 0 non-calls. Operator applications (`<>`, `<`, `:=`, `!`) are not counted because they are undecided (ocaml/15).
- Repo-wide, consistent with open defect ocaml/14: no `obj#m` / `self#m` method-call edge exists anywhere in the output. Every callee containing `#` (127) is a nested function of a method.

## Spec gaps (counted separately, never as wrong)
1. **Caller of calls inside a module-level value binding: ≈9,032 edges** (heuristic count, `s-ocaml_r13_valuelet.py`; 6,069 of them are in `parser.Tables.semantic_action`). Construct: `let semantic_action = [| (fun _menhir_env -> … Obj.magic _1 …) |]` inside `module Tables = struct … end`, and `let all_phys_regs = Array.append hard_int_reg hard_float_reg`. Open question (CAPABILITIES ocaml/16): is the caller the module (`parser.Tables`, `proc`) or the binding (`parser.Tables.semantic_action`, `proc.all_phys_regs`)?
2. **Calls of a functor parameter's members, kept as written: 328 medium.** Examples: `O.size` (genprintval `Make(O : OBJ)`), `T.instr_size`, `H.seeded_hash`, `Ord.compare`, `I.*`, `P.*`, `IT.*`, `My_ir.*`, `Impl.*`, `UH.*` (`module UH = P.Unit_header`), `X.*`, `Log.*` (via `include T`), `Module_name.*`, `MyTexter.*`, `Name.*`, `S.*`, `H1`/`H2`, `Innerid`, `ET`, `EVP`, `TT`, `Params`, `Constr`. Open question: what ID and tier does a call through a functor parameter's signature get? For example, is it `O.size`, a member of the parameter's module type (by analogy with body-less interface members, high), or a low guess?
3. **Members reached only through an `include` of a first-class module: 226 medium.** Construct: `module Sysdeps = (val (match Sys.os_type with "Win32" -> (module Win32: SYSDEPS) | … ))` then `include Sysdeps` in stdlib/filename.ml, giving `Filename.quote`, `check_suffix`, `dirname`, `basename`, `is_relative`, `is_implicit`, `quote_command` (219). It also covers bare `is_dir_sep` inside filename.ml (3), and `include (val …)` in utils/targetint.ml (4). Open question: is the callee `filename.quote` (high or medium), one edge per alternative (`filename.Unix.quote`, …), or a guess?
4. **Bare name with more than one external open: 189 medium.** Soup/Common names not defined in common.ml.in (151), and debugger/command_line.ml with `open Debugger_parser` among several external opens (`Debugger_lexer` is a .mll) (38). Construct: `open Soup` / `open Printf` / `open Common`, then `create_element …`. Open question: SPEC names "the one external open". When two or more opens are external, does a bare name go to one of them (which?) or stay a low guess?
5. **Calls through a module-level binding whose value is a function but not a function literal: 84.** Examples: `let start, end_ = gen loc'` in `odoc_sig.Analyser.Loc` called as `Loc.start` (83, medium direct), and `let make_bytecode = make "…" ~fp:false …` called as `make_bytecode ()` (1, callback). Open question: which tier and call_type does a call through such a binding get, given that OCaml has no ruling like the JS/TS binding ruling?
6. **Calls through a first-class module unpacked locally: 9 medium.** Construct: `let module Backend = (val backend : Backend_intf.S) in … Backend.symbol_for_global'`. Open question: what ID and tier apply when the implementation is a runtime value?
7. **Qualified call of a member the scanned module does not define: 1.** Construct: `orig |> Unit_info.modname_from_source |> …` (tools/lintapidiff.ml:189); unit_info.ml only defines `strict_`/`lax_modname_from_source`. Open question: does a medium `unit_info.modname_from_source` count as an invented ID under C2, or as the written reference preserved under C4?
8. **Operators** (ocaml/15): the tool emits no operator edges (`+`, `|>`, `@@`, `!`, `:=`). The deref-application `!unify_var' …` (a dynamic call) is affected too. Open question, beyond ocaml/15: what is the callee ID of a call to the function held in a ref, `!r x`?
