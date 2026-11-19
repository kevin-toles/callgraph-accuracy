# h-rtic (Rust): blind call-graph review, round 15

precision 49/50; census ≈98.8% (47 wrong of 3905 in-scope); recall: 0 missed of 43 real calls; 0 non-calls

## Scope
Tool output `final15-A/h-rtic.v2.json` has 5235 edges. In scope: 3905 edges whose `source_file` is `.rs` and has no `test/ tests/ spec/ examples/ docs/` path segment. Out of scope: 1319 `.rs` edges (1130 under `examples/`, 172 under `rtic-time/tests/`, 15 under `rtic/tests/`, 2 under `rtic-macros/tests/`), plus 10 `.py` edges and 1 `.js` edge. `build.rs`, `ui/` and `#[cfg(test)]` modules inside `src/` are in scope. By crate, the in-scope edges are: rtic-macros 1743, xtask 630, rtic-sync 573, rtic-monotonics 375, rtic 299, rtic-common 144, rtic-time 141. There are 97 files.
- Confidence: high 666, medium 1614, low 1600, unknown 25.
- call_type: method 2699, macro 732, direct 449, callback 25. By tier and type: low/method 1580, medium/method 816, medium/macro 641, high/method 303, high/direct 272, medium/direct 157, high/macro 91, unknown/callback 25, low/direct 20.

Method notes: the sample uses seed 15015, stratified high 9 / medium 18 / low 18 / unknown 5, and covers 31 files. I ignored `measured_accuracy`. The helper scripts are `h-rtic_r15_*.py` in the fanout folder.

## Precision sample (50)
48 edges are correct, 1 is wrong and 1 is a spec gap (it is not counted as wrong).
- Wrong: #26 `rtic-macros/src/syntax/analyze.rs:247`. See the table.
- Spec gap: #47 `rtic-macros/src/codegen/main.rs:23`, `quote!(#name(#name::Context::new()))` → `codegen → name`, unknown/callback. This is a quote interpolation (see Spec gaps).
- Spot-checked as correct: nested fn `CargoCommand#fmt.details` (high); `Channel#size_check` via `const { Self::size_check() }`; `Receiver#try_recv → Channel#read_slot` through the tuple field `self.0: &Channel`; `RacyCell#get_mut → core::cell::UnsafeCell#get` (scan defines its own `UnsafeCell`, so the path is kept); `IndexMap#get` through `type Map<T> = IndexMap<Ident,T>`; `log::error!`, `anyhow::anyhow!`, `quote::quote!` medium macros; `new_n_args!` high macro with module caller `crate::export::executor`; closure-bound `handle_results.log_stdout_stderr`; low guesses on pattern, closure and external-call-result receivers; callbacks `f()` on `F: FnOnce` parameters.

## Mismatch table
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| rtic-macros/src/syntax/analyze.rs:247 | `used_local_resource.insert(local.clone());` | app → Vec#clone, medium, method | `local.clone`, low (for-pattern `(local, _)` over an IndexMap shadows `let local: Vec<&Ident>` at :136) | wrong callee | outer typed declaration used through a shadowing pattern binding |
| xtask/src/cargo_command.rs:153 | `let path = path.to_str().unwrap_or(..)` | CargoCommand#fmt.details → Option#to_str, medium | `if let Some(path) = path` rebinds `path` to `&PathBuf`; Option has no `to_str`. Correct: `path.to_str` low (the if-let binding has no declared type) | wrong callee | shadowing pattern binding |
| xtask/src/run.rs:188 (also :197, :275) | `package: Some(package.name()),` | cargo → PackageOpt#name, medium | closure pattern `move \|(package, target, features)\|` rebinds `package` (a `Package` item); PackageOpt has no `name`. Correct: `package.name` low | wrong callee | shadowing closure-tuple pattern (`\|package\|` at :179 is handled) |
| rtic-macros/src/codegen/bindings/esp32c3.rs:192 (and 23 more) | `if rtic::export::read_sp() <= ebss {` (in `quote!`) | check_stack_overflow_before_init → read_sp, medium, direct | `read_sp`, high (`rtic` is a workspace crate and `export` a scanned module; defined at rtic/src/export/riscv_common.rs:5) | wrong confidence | workspace-crate path not resolved to the scanned definition |
| rtic-macros/src/codegen/local_resources.rs:72 | `... = rtic::RacyCell::new(#expr);` | codegen → RacyCell#new, medium | RacyCell#new, high (rtic/src/lib.rs, node present) | wrong confidence | same |
| xtask/src/run.rs:177 (also :267, :293) | `.flat_map(\|package\| {` after `package.packages()` | cargo → ParallelIterator#flat_map, medium | `.flat_map`, low: `PackageOpt#packages` has two cfg-gated declarations returning `impl Iterator` and `impl ParallelIterator` (overload-ambiguous reading) | wrong callee | ambiguous return types not detected |
| rtic-macros/src/syntax/accessors.rs:42 (also :82, syntax.rs:88) | `.local_resources .iter()` | App#local_resource_accesses → LocalResources#iter, medium | IndexMap#iter, medium (`type LocalResources = Map<TaskLocal>`, `type Map<T> = IndexMap<Ident,T>`) | wrong callee | alias not expanded (`SharedResources` is expanded; an out-of-scope `struct LocalResources {}` in examples/ shares the name) |
| xtask/src/cargo_command.rs:201 (also :260, :278) | `details(false, target, Some(mode), ...)` inside `write!(` | CargoCommand#fmt → details, low, direct | CargoCommand#fmt.details, high, direct (as at :288 outside a macro) | wrong callee / confidence (C2) | nested fn not resolved inside macro arguments |
| rtic-time/src/timer_queue.rs:219 (also :276) | `let this = unsafe { self.get_unchecked_mut() };` with `self: Pin<&mut Self>` | Delay#poll → Delay#get_unchecked_mut, medium | Pin#get_unchecked_mut, medium (the wrapper defines `m`) | wrong callee | Pin receiver treated as Self |
| rtic-monotonics/src/esp32c3.rs:131 (also esp32c6.rs:132) | `unsafe { interrupt31() };` with `extern "C" { fn interrupt31(); }` in the fn | TimerBackend#pend_interrupt → interrupt31, low | interrupt31, medium (a declared prototype whose definition is outside the scan) | wrong confidence | extern block declaration ignored |
| rtic-sync/src/watch.rs:104 | `unsafe { self.parent.store.get().read() }` | WatchReader#get_inner → UnsafeCell#get, medium | core::cell::UnsafeCell#get, medium (`Signal.store: UnsafeCell<..>` with `use core::cell::UnsafeCell` in signal.rs; the same reference at signal.rs:90 gets the core path) | wrong callee (C1/C2) | cross-file field type loses its import path |
| rtic-time/src/half_period_counter.rs:210 (also :212) | `let half_periods = O::from(half_periods());` with `O: From<P> + From<T> + TimerOps` | calculate_now → O#from, medium | `O.from`/low guess: a type variable with no single pinning bound stays low | wrong callee/confidence | multi-bound type parameter named as a type |
| rtic-macros/src/codegen/module.rs:70 (also :86) | `values.push(quote!(local: #name::LocalResources::new()));` | codegen → `local: #name::LocalResources#new`, medium | no reading yields an ID that contains the field label `local: ` | wrong callee (malformed ID) | struct-field label parsed into the path |
| rtic-macros/src/codegen/main.rs:23 | `quote!(#name(#name::Context::new()))` | codegen → name, unknown, callback | undecided | spec gap | quote interpolation |

## Systematic patterns (scripted census, union 47)
1. **Workspace-crate paths in generated code left at medium: 24.** `rtic::export::{pend, run, lock, create_mask, compute_mask_chunks, cortex_logical2hw, read_sp, unpend, enable}`, `rtic::RacyCell::new` and `rtic::export::executor::AsyncTaskExecutorPtr::new` are written in rtic-macros and resolve to definitions in `rtic/src`. All should be high. Script: `h-rtic_r15_wsquote.py`. Hand-checked: read_sp, pend, create_mask, RacyCell#new, AsyncTaskExecutorPtr#new. Two `rtic::export::interrupt::{enable,disable}` edges are excluded because they are cfg-ambiguous (see Spec gaps).
2. **Shadowing pattern binding typed with the outer declaration: 5** (analyze.rs:247; cargo_command.rs:153; run.rs:188, 197, 275). Script: `h-rtic_r15_shadow.py`. It found 43 candidates; I checked each by hand and 38 are correct (typed closure parameters `|input: ParseStream<'_>|` and `|ident: &Ident|`, and an if-let scope that had already closed).
3. **Overload-ambiguous return typed: 3** (`ParallelIterator#flat_map` ×2, `ParallelIterator#map` ×1 on `PackageOpt::packages()`).
4. **Scanned type alias not expanded: 3** (`LocalResources#iter` ×2, `LocalResources#is_empty`). Script: `h-rtic_r15_alias.py`. Every other alias seen (`Map`, `SharedResources`, `Channels`, `Ownerships`, `Set`) is expanded.
5. **Nested fn unresolved inside macro arguments: 3** (`details` in `write!`).
6. **`self: Pin<&mut Self>` treated as Self: 2** (script `h-rtic_r15_pin.py`; these are all such edges).
7. **extern "C" prototype at low: 2.**
8. **Multi-bound type parameter named as a type: 2** (`O#from`).
9. **Malformed IDs from quote field labels: 2.**
10. **Cross-file core UnsafeCell loses its path: 1** (all 35 `UnsafeCell#` edges listed and checked).

Census precision = 1 − 47/3905 ≈ 98.8%.

Checks that found nothing wrong: callee member name present on the reported line (0 failures); high callee missing from `nodes` (0); medium macro whose `macro_rules!` is in the scan (0); `Ok`/`Some`/`Err`/`Box` constructions emitted as calls (0); low receivers whose parameter or `let` has a declared type (15 candidates, all shadowed or untyped, so correct); low `self.f.m()` with a typed field (1, an array `[T; N]` receiver, correct).

## Recall (3 functions)
- `Receiver#try_recv` (rtic-sync/src/channel.rs:595–619): 6 real calls (`critical_section::with`, `Channel#readyq`, `q.pop_front`, `Channel#read_slot`, `Channel#return_free_slot`, `Receiver#is_closed`). All 6 emitted; `Ok`/`Err` correctly not emitted.
- `run_command` (xtask/src/run.rs:484–530): 26 real calls (log macros, `Command::new`, `CargoCommand#{executable,args,chdir,extra_env,print_stdout_intermediate}`, `Command#{args,current_dir,env,output}`, `.stdout`, `.stderr`, `Stdio::piped`, `canonicalize`, `String::from_utf8` ×2, `unwrap_or` ×2, `into` ×2, `success` ×2). All 26 emitted.
- `LinkedList#delete` (rtic-time/src/linked_list.rs:50–92): 11 real calls (`cs::with` → `critical_section::with` through the alias, `fence`, `AtomicPtr#load`, `AtomicPtr#store`, `as_ref` ×2, `load` ×4, `store`). All 11 emitted.

Missed: 0 of 43. Non-calls: 0. Missed-call patterns: none observed. CAPABILITIES.md lists the open defect "fn-pointer field calls get no edge", but none of these functions contains one.

## Spec gaps (counted separately, never as wrong): 52 edges
1. **quote!/quote_spanned! interpolation: 26** (script `h-rtic_r15_quote.py`, list in `h-rtic_r15_interp.json`; excludes the 2 malformed IDs above). Constructs: `quote!(#name(#name::Context::new()))`, `rtic::export::executor::AsyncTaskExecutor::#from_ptr_n_args(#name, &#exec_name)`, `#mangled_name.get_mut()`, `#dispatcher();`. Tool output: `name` (callback/unknown or low/direct), `name::Context#new` (medium), `AsyncTaskExecutor#from_ptr_n_args` (medium, an ID with no definition), `mangled_name.get_mut` (low). Question SPEC leaves open: inside a quasi-quote macro argument, what is the callee when the callee name, its path or its receiver is an interpolated variable `#x`? Is `#x(...)` a call at all?
2. **Associated-type projection receivers: 6.** Construct: `T::Backend::timer_queue()` with `type Backend: TimerQueueBackend;` (timer_queue_based_monotonic.rs:29/33/37/44/53), and `self.release_at.compare(..)` with `release_at: Backend::Ticks` (timer_queue.rs:41). Tool: `Backend#timer_queue` / `Ticks#compare`, medium. Question: does an associated type with one trait bound resolve to that bound, the way a generic parameter's single bound does, or does it stay a guess?
3. **Mutually exclusive `#[cfg]` imports or definitions: 5.** Construct: `#[cfg(loom)] use loom::cell::UnsafeCell as InnerUnsafeCell;` beside `#[cfg(not(loom))] use core::cell::UnsafeCell as InnerUnsafeCell;`. Tool: `loom::cell::UnsafeCell#{new,get,get_mut}` also in `#[cfg(not(loom))]` code (unsafecell.rs:21, 35, 41). Also `rtic::export::interrupt::{enable,disable}`, which is `riscv::interrupt` under one cfg and the scanned `slic::interrupt` module under another (post_init.rs:44, pre_init.rs:12). Question: which cfg configuration (or all of them) decides resolution when one name has several cfg-gated bindings?
4. **cfg predicates inside macro arguments: 3.** Construct: `make_rtc!(Rtc2Backend, RTC2, ..., doc: (any(feature = "nrf52810", ...)))` (nrf/rtc.rs:319, nrf/timer.rs:337/339). Tool: `any`, low, direct. Question: is a token tree that the macro expands into an attribute predicate a "call written inside macro arguments"?
5. **Rust prelude free functions: 9.** Construct: `drop(dropper);`, `drop((tx, rx));`. Tool: `drop`, low, direct. Question: is a prelude function (`core::mem::drop`) a bare name not found in the scan (low), or a statically named external like Python `builtins.len` / Ruby `Kernel#puts` (medium, and under which ID)?

## Obsolete files
None identified.
