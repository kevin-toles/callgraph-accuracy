# s-rust-gpu call-graph review (round 13, blind)

precision 49/50; census ≈99.46% (54 wrong of 10044 in-scope); recall: 0 missed of 38 real calls; 0 non-calls

## Scope
Tool output `<scans>/final18-A/s-rust-gpu.v2.json` has 11787 edges, all from `.rs` files. In scope are 10044 edges in 71 files: the `.rs` edges not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment. 1743 edges are excluded, all under `tests/` or `examples/`. By confidence: low 4061, medium 3525, high 2429, unknown 29. By call_type: method 8074, macro 1169, direct 772, callback 29. No constructor or implicit edges are present. The in-scope edges come from `crates/rustc_codegen_spirv` (8950), `crates/spirv-std` (759), `crates/spirv-builder` (293) and `crates/rustc_codegen_spirv-types` (42). I ignored the `measured_accuracy` field. Judged against SPEC.md, including every Decisions section through 2026-11-12 and the readings applied at the 2026-11-12 final5 gate. SPEC.md has no section dated 2026-11-13, so none was applied. CAPABILITIES.md (rust) lists three open defects: fn-pointer field calls, enum-variant receivers and pattern-bound receivers.

**Sample.** Seed 13, 50 edges: low 19, medium 16, high 10, unknown 5, from 25 files. The one wrong edge is #25 (abi.rs:973). Six sampled edges are spec gaps, not wrong: #15 and #17 (slice-typed receivers, G1), #21 and #28 (associated-type projection, G2), #35 (macro in an impl body, G3) and #49 (code inside `quote!`, G4). All 50 lines are correct, and a script confirms that the callee's name appears on the reported line for every in-scope edge (0 mismatches).

**Recall.** I checked three functions:
- `compact_ids` (linker/simple_passes.rs:103-128): 13 calls, all present, including the let-bound closure `compact_ids.insert` (high, direct) ×3.
- `Builder#emit_access_chain` (builder/mod.rs:186-217): 14 calls, all present.
- `leaf_deps` with its nested `fn recurse` (spirv-builder/src/lib.rs:795-818): 11 calls, all present, including `leaf_deps.recurse` (high), `handle` (callback, unknown) and the closure folded into `leaf_deps`.

None of the three functions has a missed call or a non-call edge.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| rustc_codegen_spirv/src/abi.rs:973 (sample #25) | `.note(format!("field type is {}", ty.debug(elem_type, cx)))` | trans_intrinsic_type → `TyAndLayout#debug`, medium, method | `ty` is re-bound by the arm `ty => {` of `match cx.lookup_type(elem_type)` (a `SpirvType`, scanned): `SpirvType#debug`, high. As an untyped pattern binding it would be at most `ty.debug` low. | wrong callee | outer parameter type used despite match-arm shadowing |
| rustc_codegen_spirv/src/builder/builder_methods.rs:656 | `let int_max = self.cx().const_uint_big(int_ty, int_max(signed, int_width));` | Builder#fptoint_sat → `int_max`, unknown, callback | `int_max` is `let int_max = \|signed: bool, int_width: u64\| -> u128 {` (line 580): `Builder#fptoint_sat.int_max`, high, direct | wrong callee | let-bound closure not resolved as a named nested function |
| rustc_codegen_spirv/src/lib.rs:451 | `with_no_trimmed_paths!(do_codegen());` | SpirvCodegenBackend#compile_codegen_unit → `do_codegen`, unknown, callback | `let do_codegen = \|\| {` (line 415): `SpirvCodegenBackend#compile_codegen_unit.do_codegen`, high, direct | wrong callee | same |
| rustc_codegen_spirv/src/linker/specializer.rs:808 | `Self::Var(v) => write!(f, "{}", var_with_value(*v)),` | InferOperand#display_with_infer_var_values → `var_with_value`, unknown, callback | `InferOperand#display_with_infer_var_values.var_with_value`, high, direct. The tool itself uses this ID as a caller (line 799). | wrong callee | same |
| rustc_codegen_spirv/src/linker/import_export_link.rs:190 | `format_ty_(&ty_defs, import_type)` | check_tys_equal → `format_ty_`, low, direct | nested `fn format_ty_` (line 181): `check_tys_equal.format_ty_`, high, direct | wrong callee / confidence | nested `fn` item not resolved |
| spirv-std/macros/src/lib.rs:207 | `let output = quote::quote! {` | gpu_only → `quote::quote::quote!`, medium, macro | `quote::quote!` (the same macro is `quote::quote!` in other edges), medium, macro | wrong callee | path doubled through `use quote::{quote, …}` |
| spirv-std/macros/src/lib.rs:588 | `let ident = quote::format_ident!("_{}", i);` | debug_printf_inner → `quote::quote::format_ident!`, medium | `quote::format_ident!`, medium, macro | wrong callee | same |
| rustc_codegen_spirv/src/abi.rs:412 | `let b_offset = a.primitive().size(cx).align_to(b.primitive().align(cx).abi);` | TyAndLayout#spirv_type → `str#primitive`, medium | `a` comes from the pattern `Abi::ScalarPair(a, b)` and is untyped: `a.primitive`, low. `b.primitive` on the same line is low. | wrong callee / confidence | undeclared `a` given type `str` (C2: `a` and `b` resolve differently) |
| rustc_codegen_spirv/src/linker/specializer.rs:1494 | `(Ok(a), Ok(b)) => Ok(a.or(b)),` | InferCx#match_inst_sigs → `str#or`, medium | `a.or`, low (pattern binding) | wrong callee / confidence | same |
| rustc_codegen_spirv/src/builder/builder_methods.rs:990 | `int(a, b) => a.wrapping_add(b)` | crate::builder::builder_methods → `str#wrapping_add`, medium | `a.wrapping_add`, low (macro metavariable token in a `simple_op!` argument) | wrong callee / confidence | same |
| rustc_codegen_spirv/src/builder/builder_methods.rs:643 | `32 => bx.cx().const_u32(bits as u32),` | Builder#fptoint_sat.float_bits_to_llval → `Self#cx`, medium | `bx: &mut Self` in `impl … for Builder`: `Builder#cx` (defined at builder_methods.rs:742), high | wrong callee / confidence | `Self` in a closure-parameter type not expanded to the impl type |
| rustc_codegen_spirv/src/linker/inline.rs:873 | `*id = this.id();` | …instantiate_debuginfo → `Self#id`, medium | `this: &mut Self` in `impl Inliner`: `Inliner#id` (inline.rs:496), high | wrong callee / confidence | same |
| rustc_codegen_spirv/src/custom_decorations.rs:164 | `let (s, col_end) = s.rsplit_once(':').ok_or(err).unwrap();` | SrcLocDecoration#decode → `std::str#rsplit_once`, medium | `s: &'a str` is the primitive: `str#rsplit_once`, medium (other files emit `str#…`) | wrong callee | primitive `str` named through `use std::{…, str}` (C1: two IDs for one method) |
| rustc_codegen_spirv/src/link.rs:583 | `let file_name = std::str::from_utf8(entry.header().identifier()).unwrap();` | do_link → `std::str#from_utf8`, medium, method | module function: `std::str::from_utf8`, medium, direct | wrong callee / call_type | module path `std::str::f` treated as type `std::str` |
| rustc_codegen_spirv/src/linker/specializer.rs:76 | `self.0(f)` | FmtBy#fmt → `FmtBy#0`, medium, method | call through the closure-typed tuple field `F`: callee `0`, callback, unknown | wrong callee / call_type / confidence | fn-valued field call emitted as a method of the struct (CAPABILITIES open defect rust/05 area) |
| rustc_codegen_spirv/src/custom_insts.rs:51 | `let (lo, hi) = hasher.finalize();` | crate::custom_insts → `hasher.finalize`, low | `let mut hasher = StableHasher::new();` (line 49) types the binding: `StableHasher#finalize`, medium | wrong callee / confidence | constructor-typed binding not applied (inside `lazy_static!` argument) |
| crates/rustc_codegen_spirv/src/builder/libm_intrinsics.rs:250 (sample #17) | `assert_eq!(args.len(), 1);` | Builder#call_libm_intrinsic → `args.len`, low | `args: &[SpirvValue]` is declared; SPEC gives no ID form for a slice type | spec gap (G1) | — |
| crates/spirv-std/src/image.rs:1362 (sample #21) | `let mut result = SampledType::Vec4::default();` | → `Vec4#default`, medium | associated-type projection of a type parameter | spec gap (G2) | — |
| crates/rustc_codegen_spirv/src/builder/builder_methods.rs:1012 (sample #35) | `simple_op! {sdiv, s_div}` | `crate::builder::builder_methods` → `simple_op!`, high, macro | invocation inside `impl … for Builder`, outside any fn | spec gap (G3) | — |
| crates/spirv-std/macros/src/lib.rs:602 (sample #49) | `#ident = in(reg) &#assert_fn(#variable),` | debug_printf_inner → `assert_fn`, unknown, callback | tokens inside `quote::quote! { … }` | spec gap (G4) | — |

## Systematic patterns (scripted census, `s-rust-gpu_r13_census.py`; union 54)
1. **`quote!` / `format_ident!` path doubled** (15): `quote::quote::quote!` ×14 and `quote::quote::format_ident!` ×1. Both are in spirv-std/macros (lib.rs, image.rs) and are written `quote::quote!` / `quote::format_ident!` in files that `use quote::{quote, …}`. The same construct is `quote::quote!` in 32 other edges. Hand-checked lib.rs:207, 452, 588 and image.rs:404.
2. **Let-bound closures and nested `fn` items not resolved** (12). These are callback/unknown edges to let-bound closures:
   - `int_max` and `int_min` (builder_methods.rs:656, 659)
   - `expected_mutbl_for` (entry.rs:300)
   - `do_codegen` ×2 (lib.rs:451, 454)
   - `var_with_value` (specializer.rs:808)
   - `name_from_attrs` (diagnostics.rs:333)
   - `id_to_name` ×3 (zombies.rs:258, 263, 267)

   There are also 2 low/direct edges to the nested `fn format_ty_` (import_export_link.rs:190, 194). Elsewhere the same construct resolves: 256 high/direct `outer.f` edges, including `UseOrigin#note.name_from_attrs` at diagnostics.rs:368. The resolution therefore differs for the same written reference (C2). Found by script (a callback callee whose nearest binding is `let name = |…|` or `fn name`). Every hit was hand-checked.
3. **`Self` in a closure-parameter type left unexpanded** (8): `Self#cx` ×3, `Self#bitcast`, `Self#vector_splat`, `Self#vector_length` (builder_methods.rs:643-667), and `Self#id` ×2 (inline.rs:873, 881). All are medium. Correct are `Builder#cx`/`Builder#bitcast`/`Builder#vector_splat` (high), `CodegenCx#vector_length` (through Builder's Deref) and `Inliner#id` (high).
4. **`std::str#…` IDs** (8):
   - **Primitive `str` methods.** `std::str#rsplit_once` ×4 and `std::str#into` ×1 (custom_decorations.rs:123, 164-167) should be `str#…`, as in the 31 `str#…` edges in other files (C1).
   - **Module function.** `std::str#from_utf8` ×3 (builder_spirv.rs:786, diagnostics.rs:122, link.rs:583) is the module function `std::str::from_utf8`, direct.
5. **Undeclared `a` typed as `str`** (6): `str#primitive` ×3 (abi.rs:412, 475; builder_methods.rs:1256), `str#wrapping_add`, `str#wrapping_mul` (builder_methods.rs:990, 1003) and `str#or` (specializer.rs:1494). In each case `a` is a pattern binding or a macro metavariable with no `str` declaration. The parallel `b.primitive()` on the same lines is low. A script of every typed edge whose receiver is `a` finds exactly these 6 among 10. The other 4 are correctly typed `InferVar` / `InferOperand`.
6. **Call through a closure-typed tuple field emitted as a struct method** (3): `FmtBy#0` ×2 (specializer.rs:70, 76) and `ReplaceValueWith#0` (spirt_passes/mod.rs:356).
7. **Match-arm shadowing ignored** (1): abi.rs:973 `TyAndLayout#debug`. A script comparing every typed edge's receiver with its nearest binding found no other instance. Flagged candidates at entry.rs:290/757, symbols.rs:542/556, target_feature.rs:18 and specializer.rs:1566/1629 were hand-checked and are correct.
8. **Constructor-typed binding not applied** (1): custom_insts.rs:51 `hasher.finalize`. A script found 6 other candidates (link.rs:648, linker/mod.rs:321/377/675, specializer.rs:122, reduce.rs:191). All are field chains or re-bound names and are correct.

Checks with no findings:
- Every high callee is in `nodes`.
- No caller or callee is empty.
- No line is wrong.
- No `method` edge lacks `#` or a receiver.
- Medium callees on scanned types that are not defined there are trait default methods of external traits or macro-generated functions (`simple_op!` → `Builder#lshr` etc.; `SpvSpecWithExtras#get`; `CustomOp#decode`). These are medium per the generated-functions ruling.

## Missed-call patterns (recall)
None in the three recall functions (0 of 38). Pattern 2 above has a recall side: each let-bound closure call it lists lacks its `outer.f` high edge. Those edges are already counted as wrong edges, not as missed calls.

## Spec gaps (not counted as wrong)
- **G1. Slice-typed receivers (≥49 edges, lower bound by script `s-rust-gpu_r13_slice.py`).** Example: `args: &[SpirvValue]` … `assert_eq!(args.len(), 1);` → `args.len`, low. The methods involved are `len` 20, `iter` 19, `is_empty` 3 and 7 others. Decision A says a declared parameter type gives `T#m`. SPEC does not say what ID names a slice or array type (`[T]`, `[T; N]`) or a slice's inherent methods, or whether such a receiver counts as typed. The tool spells scanned impls `[T]#get_unchecked`. The same question covers `const SCHEMA: &[(u32, &str, &[&str])]` (`SCHEMA.hash`).
- **G2. Associated-type projection of a type parameter (30 edges).** Example: `let mut result = SampledType::Vec4::default();` → `Vec4#default` ×16, then `result.truncate_into()` → `Vec4#truncate_into` ×14. The declaration is `type Vec4: Default + VectorTruncateInto<Self::SampleResult>;` in spirv-std/src/image/params.rs:17. SPEC resolves "a type variable … to its declared bound". It does not say whether an associated-type projection `T::Assoc` is a type variable, nor which bound names the call when there are several (`Default#default` vs `VectorTruncateInto#truncate_into`).
- **G3. Macro invocations in an impl body, outside any fn (30 edges).** Example: `simple_op! {sdiv, s_div}` inside `impl<'a, 'tcx> BuilderMethods<'a, 'tcx> for Builder<'a, 'tcx>` → caller `crate::builder::builder_methods`. These are `simple_op!` ×25, `simple_op_unchecked_type!` ×3 and `simple_uni_op!` ×2. SPEC gives the module ID only for code "outside any function or type" and gives Python's class-body caller. It does not say what the caller is for Rust code in an `impl` block outside any method.
- **G4. Code inside `quote!` bodies (7 edges).** Example: `#ident = in(reg) &#assert_fn(#variable),` inside `quote::quote! { … }` gives `assert_fn` (unknown) and `in` (low). The others are `cfg_attr`, `unimplemented!`, `concat!`, `stringify!` and `::core::arch::asm!`. SPEC says "calls written inside macro arguments are separate ordinary edges". It does not say whether that applies to token-quoting macros, whose argument is emitted code that the enclosing function does not run.
- **G5. Associated constant with a declared type (1 edge).** `const ENCODING_PREFIX: &'static str;` (trait item), then `Self::ENCODING_PREFIX.to_string()` → `.to_string`, low (custom_decorations.rs:41). Decision A lists locals, parameters, fields and file-scope statics. SPEC does not say whether a trait or impl associated constant's declared type types its receiver.

Helper scripts: `<fanout>/s-rust-gpu_r13_*.py`
