# just (rust) call-graph review, v3

Summary: precision 50/50; recall: 0 missed of 70 real calls; 0 non-calls

The 50/50 figure treats 2 sample edges (#5 and #12) as a spec gap: calls to Rust nested `fn` items. If those items fall under the generic local-function rule (`outer.f`), precision is 48/50.

## Scope

- **Edges.** 19,839 in total (v2: 20,111). 8,357 are judged (`src/` and `crates/`; `tests/` and `build.rs` excluded).
- **Confidence split of the judged edges.** low 4604, high 2095, medium 1653, unknown 5.
- **Call types.** method 6308, macro 1538, direct 506, callback 5.

## Precision sample

I drew 50 edges with seed 3033 from 32 files: 12 high, 9 medium, 24 low, and all 5 unknown.
- The draw excluded callers named `crate::…::tests`.
- 4 sampled edges are still `#[test]` functions inside in-file test modules (#3, #5, #6, #12). The other 46 are production code.

Results:
- **48 are correct on every field** (real call, caller, callee, confidence, call_type and line). Examples:
  - #26 `.collect::<PathBuf>()` → `.collect`, low, reported on its own chain line.
  - #16 `Stdio::inherit()` → `Stdio#inherit`, medium.
  - #7 `constants()` → `constants`, high.
  - #46–50: parameter function values `error`, `f` and `handler` → callback/unknown. #50 is called inside a `move ||` closure, which correctly folds into `Platform#install_signal_handler`.
- **#5 and #12 are spec gaps.** `check(...)` → `check` and `case(...)` → `case` are calls to `fn` items nested inside another function body. See pattern S1.

With 50/50 observed, the 95% Wilson lower bound on precision is about 92.9%. The sample alone cannot separate 95% from 99%, so the scripted whole-output counts below are the better guide. Edges that follow a confirmed wrong pattern: 22 of 8,357 judged edges (0.26%), which gives ≈ 99.7%. Counting the nested-`fn` spec gap as wrong adds about 283 edges, which gives ≈ 96.4%.

## Recall

I checked 3 functions in different files. None of the 70 calls is missed, and no edge is a non-call. In all 3, every caller, callee, confidence and line matches the spec.

- **`Evaluator#run_command`** (src/evaluator.rs:677-722): 21 calls. Examples:
  - `ShellKind#from` high.
  - `Environment#new` high.
  - `Stdio#inherit`, `#null` and `#piped` medium.
  - A chain on lines 707-715 with each link on its own line: `cmd.current_dir`, `.stdin`, `.stderr`, `.stdout`.
- **`Command#resolve`** (src/command_ext.rs:42-91): 33 calls. Examples:
  - `Self::new` on std `Command` → `Command#new`, medium.
  - Calls inside `matches!`/`vec!` arguments are present.
  - `Some(Component::Normal(_))` is correctly not emitted.
- **`Search#init`** (src/search.rs:193-242): 16 calls, including a `let`-bound closure. The closure body (5 calls) has caller `Search#init.default_justfile_name`. The 2 calls to it are `Search#init.default_justfile_name`, high, direct. `String::as_str` passed as a method reference is correctly not emitted.

## Mismatch table

None of these rows came from the precision sample except #5 and #12. The others were found by the whole-output scans described under Systematic patterns.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category / root cause |
|---|---|---|---|---|
| src/shebang.rs:81 (sample #5) | `check("#!\t\t/bin/bash    ", Some(("/bin/bash", None)));` | `split_shebang → check`, high, direct | `check` is `fn check` nested in `fn split_shebang` (:47). Under the generic rule ("local `fun`/`def`/`func` … `outer.f`") it would be `split_shebang.check`. The Rust note only covers `let` closures. | spec gap. Root cause: nested `fn` items are named bare. |
| src/value.rs:284 (sample #12) | `case(&["a", "b"], &["c", "d", "e"], Concatenate, None);` | `apply → case`, high, direct | `apply.case` under the generic rule. value.rs has 4 distinct nested `fn case` (:172, :188, :213, :237), and all collapse into one node `case`. | spec gap. Root cause: nested `fn` items are named bare, so same-named items collide. |
| src/evaluator.rs:341 | `Function::Nullary(f) => f(context).map(Value::from),` | `Evaluator#evaluate_builtin_function → f`, low, direct | `f`, unknown, callback. `f` is a local bound by a match pattern to a fn pointer. | wrong confidence / call_type. Root cause: match-pattern bindings holding functions are not treated as function-value locals. |
| src/evaluator.rs:393 | `f(context, &a, &b, &c).map(Value::from)` | same, low, direct | `f`, unknown, callback | wrong confidence / call_type (same root cause, 17 edges in total) |
| src/function.rs:613 | `` crate::which(&context, name)?.ok_or_else(\|\| format!("could not find executable `{name}`")) `` | `which → crate::which`, medium, direct | `which`, high (defined at src/which.rs:3) | wrong callee / wrong confidence. Root cause: `crate::` path prefix not resolved. |
| src/function.rs:882 | `Ok(match crate::which(&context, name)? {` | `which → crate::which`, medium | `which`, high | wrong callee / wrong confidence (same root cause) |
| src/platform/unix.rs:47 | `let signals = crate::signals::Signals::new()?;` | `→ crate::signals::Signals#new`, medium | `Signals#new`, high (src/signals.rs:83 `impl Signals`) | wrong callee / wrong confidence (same root cause) |
| src/main.rs:23 | `if let Err(code) = just::run(env::args_os()) {` | `main → just::run`, medium | `run`, high. `just` is this package's own library crate (Cargo.toml `name = "just"`), and `pub fn run` is at src/run.rs:5. | wrong callee / wrong confidence. Root cause: the own-crate name is not recognised as a scanned path. |
| crates/generate-book/src/main.rs:77 | `cmark(self.events.iter(), &mut markdown)?;` | `Chapter#markdown → cmark`, low, direct | medium: the name comes from an import, `use pulldown_cmark_to_cmark::cmark` (:3) | wrong confidence. Root cause: a `use`-imported external free function is treated as an unknown bare name. |
| src/config.rs:1014 | `test! {` (module level inside `mod tests`) | caller `crate::config::tests` | The spec does not define the caller ID for Rust module-level code. | spec gap (unchanged from v2) |

## Systematic patterns

Counts are scripted over the 8,357 judged edges.

1. **Fn pointers bound by match patterns are low/direct instead of unknown/callback.** 17 edges, all `→ f` in `Evaluator#evaluate_builtin_function` (src/evaluator.rs:341-439), each from a `Function::Xxx(f) => f(...)` arm. Parameter function values are already handled correctly (5 unknown edges). Fixing this is the largest strict-spec gain: 17 of the 22 wrong edges.
2. **In-crate absolute paths are not resolved.** 4 edges: `crate::which` ×2, `crate::signals::Signals#new` ×1, `just::run` ×1. They should be `which`, `Signals#new` and `run`, all high. Relative module paths (`testing::compile` etc.) are fixed (see Previous findings), so only the `crate::` and own-crate-name prefixes remain.
3. **A `use`-imported external free function called bare gets low.** 1 edge (`cmark`). It should be medium per the tier definition ("an import"). The only other bare low callees are `drop` (a prelude function, low is acceptable) and the 17 `f` edges from pattern 1.
4. **Spec gap S1: nested `fn` items.**
   - There are 18 `fn` items defined inside function bodies: 13 named `case`, plus `check`, `layer` (inside `style`, production code), and `print_doc_and_aliases` (inside `Subcommand#list_module`, production code).
   - They are named bare. That covers 133 call edges to them (high/direct) and 150 edges from their bodies, 283 edges in all.
   - The 13 `case` functions in 9 files merge into one node `case`. So the high-confidence `case` callee does not identify a definition, and caller `case` mixes 13 bodies.
   - A closure inside a nested fn inherits the bare name: `print_doc_and_aliases.print_aliases`.
   - If the spec adopts `outer.f` for Rust nested `fn` items, this becomes the dominant error: about 283 edges, or 3.4% of judged edges.
5. **Spec gap S2: module-level code callers.** 649 edges have callers of the form `crate::<mod>::tests`, `crate::<mod>` or `crate`. These are mostly `test!`/`error!` macro invocations at test-module level. The spec still does not define this caller ID for Rust.

Other scans came back clean:
- 0 IDs containing `<`, `&`, spaces or `'`.
- 0 direct or method edges whose name is not followed by `(` (or a turbofish and `(`) on the reported line.
- 0 medium edges whose callee is a function defined in the scan.
- 0 high non-macro edges whose name has no `fn` definition, other than closure IDs.

## Previous findings

Mismatch-table rows from v2:

| v2 row / category | Status | Evidence (counts) |
|---|---|---|
| parser.rs:2605 s-expression in `test!` emitted as a call (not a call) | **fixed** | 0 edges at :2605. Edges with caller `crate::parser::tests` are now only `test!` 155, `error!` 22 and `vec!` 1, all macro. 0 direct edges anywhere whose name is not followed by `(` (v2 had 256 DSL edges). |
| variable_resolver.rs:158, invocation_parser.rs:581, compiler.rs:166: module-path calls to scanned functions are medium (wrong confidence) | **fixed** | All 27 now high/direct with bare names: `compile` 12, `config` 7, `is_file` 3, `exists` 2, `get` 2, `tempdir` 1. Residue: the 4 `crate::`/`just::` paths in pattern 2, which v2 did not count. |
| analyzer.rs:267, parser.rs:586, subcommand.rs:418, signals.rs:36: calls to `let` closures were unknown/callback (wrong callee / wrong confidence) | **fixed** | All 27 now `outer.f`, high, direct: `take_attributes` 11, `collect_references` 4, `append` 3, `format_overrides` 2, `error` (`style.error`) 2, `default_justfile_name` 2, `print_aliases` 2, `context` 1. The `cache.rs`/`cache_lock.rs` `context` closures are only passed to `map_err` and correctly have no call edges. |
| parser.rs:521, subcommand.rs:364, signals.rs:29-32: closure bodies attributed to the enclosing function (wrong caller) | **fixed** | Bodies now have callers `Parser#parse_item.take_attributes`, `Subcommand#clean.context`, `die.append`, `Cache#status.context`, `CacheLock#save.context`, and so on. |
| generate-book main.rs:142 `let slug = slug(..)`, unindent.rs:16 `let blank = blank(..)` (wrong confidence) | **fixed** | Both now high/direct. 0 unknown edges remain for `slug` or `blank`. |
| compiler.rs:184 turbofish callee `BTreeMap::<…>::new` (wrong callee) | **fixed** | Now `BTreeMap#new`, medium. 0 callee IDs contain `<` (v2: 13). The 14 turbofish call lines resolve to `Type#assoc`, e.g. `Table#default` high, `HashMap#new` medium. |
| clean.rs:13 `&Path#clean → &Path#components`, attribute_set.rs:142 `&'a AttributeSet<'src>#into_iter` (wrong caller / callee) | **fixed** | Now `Path#clean → Path#components` and `AttributeSet#into_iter → .keys`. 0 caller IDs contain `&` or `<` (v2: 14). |
| indentation.rs:43/47/51 `Err("…")` → `&'static str` (not a call) | **fixed** | 0 edges on those lines. 0 callees containing `static` (v2: 3). |
| signals.rs:48 `u8::try_from` kept as a path (wrong callee) | **fixed** | Now `u8#try_from`, medium. 0 primitive-type `::` callees (v2: 11). Now `u8#try_from` 5, `u32#from_str_radix` 2, `u64#try_from` 2, `u16#from_str_radix` 1, `char#from_u32` 1, `str#from_utf8` 2, and so on. |
| config.rs:1014 module-level caller `crate::config::tests` (spec gap) | **still present** (spec still silent) | 649 judged edges have `crate…` callers (pattern S2). |

Systematic patterns from v2:

| v2 pattern | Status | Count now (v2) |
|---|---|---|
| 1. `let`-bound closures not named nested functions | **fixed** | 0 unknown closure calls (27). 27 high `outer.f` call edges; closure bodies attributed to `outer.f`. |
| 2. S-expression DSL in `test!` emitted as calls | **fixed** | 0 (256) |
| 3. Module-path calls to in-scan functions get medium | **fixed** for `mod::f`; `crate::`/own-crate paths remain | 0 of the 27 v2 edges. 4 `crate::`/`just::` edges were not counted in v2. |
| 4. Generic arguments kept in IDs (turbofish callees; `&T`/`&'a T<'x>` impl callers) | **fixed** | 0 (13 + 14) |
| 5. Primitive-type associated functions kept as paths | **fixed** | 0 (11) |
| 6. `let` binding shadowing a function hides the call on its right-hand side | **fixed** | 0 (2) |
| 7. `Err("literal")` resolved through the `type Err` alias | **fixed** | 0 (3). Associated types are no longer treated as type aliases. |

New since v2 (present in v2 but not reported then): pattern 1 (17 `f` match-binding edges), pattern 2's `crate::`/`just::` residue (4), pattern 3 (1 `cmark`), and spec gap S1 (nested `fn` items, about 283 edges).
