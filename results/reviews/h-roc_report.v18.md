# h-roc (zig): blind call-graph review, round 18

precision 48/50; census ≈98.6% (2531 wrong of 184528 in-scope); recall: 0 missed of 27 real calls; 0 non-calls

## Scope
Tool output: `final23-A/h-roc.v2.json`, 204,495 edges. In scope are the edges whose `source_file` is `.zig` and has no `test/`, `tests/`, `spec/`, `examples/` or `docs/` directory segment. That leaves **184,528 edges** in 409 files. The other languages (rs/js/c/py/cpp/h/mjs, 3,449 edges) are ignored. The tool skipped `vendor/` (22 files) by design; CAPABILITIES lists that as unsupported. The `measured_accuracy` field was ignored.

| | edges |
|---|---|
| high | 129,463 (direct 65,727 / method 63,736) |
| medium | 33,536 (method 22,990 / direct 10,546) |
| low | 21,154 (method 20,938 / direct 216) |
| unknown | 375 (callback 375) |

**Sample.** Seed 18, `random.Random(18)`. The 50 edges are 31 high, 9 medium, 5 low and 5 unknown, spread over 31 files. Every edge's source line was opened and the receiver's declaration traced.

- **48 not wrong.** 42 are correct and 6 are spec gaps.
- **2 wrong:**
  - #33, an alias that was not expanded.
  - #43, an open defect (zig/12).
- **Spec gaps:**
  - #13: zig/18.
  - #40 and #44: zig/16.
  - #41: zig/18.
  - #46 and #48: zig/14.

**Conventions the tool follows consistently, not counted as errors.** A file whose top level is a struct (has top-level fields) puts its functions at `file.fn` (`WasmCodeGen.currentCode`, `NodeStore.scratchWhereClauseTop`), and the call is `direct` because the ID has no `#`. Members of a struct returned by an in-scan generic type function are `file.fn` (`DenseMap.get`, `safe_list.clone`); that is zig/18, counted as a gap. File qualifiers are basenames, so 33 basenames collide (`ast`, `type`, `mod`, `main`, `lower`, `solve`, …). That is zig/17, a spec gap; 37,887 high/medium edges name a colliding basename.

## Mismatch table
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/check/unify.zig:3209 (sample #33) | `.only_in_a = scratch.only_in_a_tags.rangeToEnd(a_tags_start),` | unify.Unifier#partitionTags → `types.Tag.SafeList#rangeToEnd`, medium, method | field `only_in_a_tags: TagSafeList`, which is `Tag.SafeList`, which is `MkSafeList(@This())`, which is `collections.SafeList(Tag)`. The alias expands to the in-scan generic, whose `rangeToEnd` is defined (safe_list.zig:336). So the ID is the generic's member, high. `types.Tag.SafeList` defines no `rangeToEnd` (C2) | wrong callee / wrong confidence | Zig `const X = Generic(..)` alias not expanded (ID-format alias rule) |
| src/cli/cli_args.zig:1383 (sample #43) | `var app_args = try std.array_list.Managed([]const u8).initCapacity(alloc, 16);` | cli_args.parseRun → `.initCapacity`, low, method | `std.array_list.Managed#initCapacity`, medium, method | wrong callee / wrong confidence | open defect zig/12: a static call on an instantiated generic type becomes `.m` |
| src/base/url.zig:268 (recall) | `if (!occ.version.isPresent()) return error.InvalidVersion;` | url.parseUrlPath → `version.isPresent`, low, method | `occurrence` is bound to `findVersionOccurrence(..)`, declared `!?VersionOccurrence`. `occ` is its optional capture, and field `version: Version` has a declared type, so the callee is `url.Version#isPresent`, high | wrong callee / wrong confidence | open defect zig/05 (optional capture) on top of the let-bound call result |
| src/postcheck/monotype/ast.zig:1959 | `return self.locals.unsafeRawItemsForView()[@intFromEnum(id)];` | → `ast.unsafeRawItemsForView`, medium, direct | field typed `ProgramList(..)`, which returns `GuardedList.List(..)`, which defines the method (GuardedList.zig:229). The ID is not `ast.*` | wrong callee / wrong confidence | invented file-member ID (C2); the member is credited to the file that holds the wrapper generic |
| src/cli/main.zig:9780 | `try renderProblem(ctx, .{` | → `CliCtx.CliCtx#renderProblem`, medium, method | `const renderProblem = cli_context.renderProblem;` points to the file-level `CliCtx.renderProblem` (CliCtx.zig:461), high, direct | wrong callee | Zig const alias of a function resolved to a struct member that does not exist |
| src/builtins/list.zig:1894 | `context.inc(context.inc_context, context.args);` | → `list.SortWithContext#inc`, medium, method | `inc: Inc` is a function-pointer field: callee `inc`, callback, unknown | wrong call_type / confidence | open defect zig/07 |
| src/postcheck/lambda_solved/solve.zig:2898 | `.tuple => \|items\| for (store.span(items)) \|item\| …` | → `solve.Walk#span`, medium, method | `store: @TypeOf(types)` is a parameter; `Walk` defines no `span` | wrong callee | `@TypeOf` receiver credited to the enclosing struct |
| src/cli/main.zig:1057 | `const result = c.link(source_c, dest_c);` | → `main.c#link`, medium, method | `pub const link = std.c.link;` resolves to `std.c.link`, medium, direct (Zig alias decision) | wrong callee | member const alias not resolved |
| src/builtins/num.zig:69 | `var lo: u128 = wide(a_lo, b_lo);` | → `wide`, unknown, callback | `const wide = i128h.mul_u64_wide;` resolves to its target, direct | wrong callee / call_type | open defect zig/04 |
| src/build/test_harness.zig:999 | `if (cfg.onTestStarted) \|cb\| cb(specs[test_idx]);` | → `cb`, low, direct | `cb`, callback, unknown (call through a capture holding a function) | wrong call_type / confidence | fn-valued capture/local/param emitted as a bare low guess |
| src/postcheck/monotype/type.zig:687 | `requireEpochRange(source, begin, end);` | → `requireEpochRange`, low, direct | an outer-struct member declared in the same file (type.zig:830): `type.Store#requireEpochRange`, high | wrong callee / confidence | lexical lookup into the enclosing outer struct is missing |
| src/snapshot_tool/main.zig:3959 | `const imported_artifacts = try build_env.collectImportedArtifactViews(` | → `build_env.collectImportedArtifactViews`, low | `build_env = try BuildEnv.init(..)` is declared `InitError!BuildEnv`, so the callee is `compile_build.BuildEnv#collectImportedArtifactViews`, high | wrong callee / confidence | 2026-11-12 let-bound call-result ruling not applied in this form (the tool applies it elsewhere, e.g. sample #6) |
| src/bundle/bundle.zig:578 | `const file = try self.dir.createFile(self.io, path, .{});` | → `dir.createFile`, low | field `dir: std.Io.Dir`, so `std.Io.Dir#createFile`, medium | wrong callee / confidence | decision-A field type not used |
| src/collections/safe_list.zig / NodeStore.zig:670 (sample #13) | `.interpolation_data = try self.interpolation_data.clone(gpa),` | → `safe_list.clone`, high, direct | open | spec gap (zig/18) | ID of a member of an in-scan generic type function |
| src/check/checked_artifact.zig:134 (sample #40) | `env_alloc.destroy(module_env);` | → `env_alloc.destroy`, low | open | spec gap (zig/16) | local without annotation bound to a field (`module_env.gpa`) |
| src/canonicalize/ModuleEnv.zig:4021 (sample #41) | `.provided_low_level_defs = self.provided_low_level_defs.deserializeInto(base_addr),` | → `provided_low_level_defs.deserializeInto`, low | open | spec gap (zig/18) | field typed by a nested type of an in-scan generic instance |
| src/eval/compile_time_finalization.zig:1503 (sample #44) | `job.progress.store(@intFromEnum(DevRootProgressState.running), .release);` | → `progress.store`, low | open | spec gap (zig/16) | `const job = &context.jobs[item_id];` is a local bound to an index |
| src/watch/watch.zig:1485, src/lir/arc_solve.zig:1370 (samples #46, #48) | `const result = ReadDirectoryChangesW(` / `try pushNext(&stack, …)` | → `ReadDirectoryChangesW` / `pushNext`, unknown, callback | open | spec gap (zig/14) | `const g = struct { fn g(..) }.g;` idiom |

## Systematic patterns (scripted census, `h-roc_r18_census.py` + `h-roc_r18_optcap.py`)
Each pattern was hand-checked on at least 6 edges, listed in the table above and in the census run output.

| # | pattern | edges |
|---|---|---|
| W5 | `Generic(..).m(..)` static call (`std.AutoHashMap(K,V).init`, `std.array_list.Managed(..).initCapacity`, `SafeList(T).initCapacity`) emitted as `.m` low. Open defect zig/12 | 1,095 |
| W1 | Invented file-member ID, medium: `ast.unsafeRawItemsForView` (169), `ast.deinit` (101), `ast.len` (100), `type.len` (65), `ast.append` (59), … The method lives in `GuardedList.List`, reached through the file's `ProgramList(..)` wrapper. Also `safe_list.serializedSize`, `DenseMap.clone`, `eval.test_helpers.*` (unresolved module path), `builtins.builtin_registry.core_root_symbols.has`. Violates C2 | 838 |
| W2 | Type alias not expanded: the ID names the alias. `types.Tag.SafeList#sliceRange`, `types.StaticDispatchConstraint.SafeList.Range#len`, `layout.StructField.SafeMultiList#field`, `import_mapping.ImportMapping#init` (that is `std.AutoHashMap`), `interpreter.Interpreter.BoxyTables#fromResult`, `parallel.AtomicUsize#load` (that is `std.atomic.Value`). Medium | 353 |
| W9 | Local bound to a call of a scanned function with a declared concrete return type, left as a low guess (`BuildEnv`, `RocList`, `RocStr`, `SharedMemoryAllocator`, `base.Ident.Idx`, `StepResult`, …). 2026-11-12 let-bound ruling | 64 |
| W8 | Decision-A typed receiver left low: params `*lir.LirStore`, `*TypoSuggestion.ArrayList`; locals `*const NodeStore`, `*Env`, `RocTarget`; fields `std.Io.Dir`, `std.mem.Allocator`, `std.atomic.Value(u64)`, `std.StringHashMap(..)`, `Token.List` (that is `std.MultiArrayList`), `ImportMapping`, `*@import("can").ModuleEnv` | 59 |
| W7 | Call through a function-valued capture/local/param/const pointer emitted as a bare low `direct` instead of callback/unknown (`cb`, `post`, `hook`, `on_drop`, `getOps`, `setjmpFn`, `roc_default_start_main`, …) | 57 |
| W4 | Medium `Struct#m` where the struct defines no function `m`: function-pointer fields (`ctx.callback`, `self.finalize`, `handler.dispatch`), `@TypeOf`/generic-parameter receivers (`solve.Walk#span`, `lir_image.h#fromArrayList`), std member aliases (`main.c#link`), `CIR.ExternalDecl#initCapacity` (`.SafeList` dropped) | 21 |
| W3 | Function-pointer field called as method/direct (`CoreCtx.VTable#queryEnvVar`, `package_resolution.Fetcher#loadLocalFn`, `bundle.ExtractWriter#makeDirFn`, `parallel.worker_fn`). Open defect zig/07 | 15 |
| W11 | Optional capture `if (x) \|v\|` of a declared `?T` (field/param/local), with calls on `v` left low. Open defect zig/05 | 14 |
| W10 | Function-local const alias of a function (`const wide = i128h.mul_u64_wide;`) emitted as callback/unknown. Open defect zig/04 | 12 |
| W6 | Bare call of an outer-struct member from a nested struct left as a low guess (`requireEpochRange`, `builtinOwnerLayout`) | 2 |
| — | recall finding (url.zig:268, capture plus let-bound chain) | 1 |
| | **union of wrong edges** | **2,531** |

Not censused: 3,019 low edges whose receiver is a multi-segment chain (`a.b.c.m()`), and 544 low edges whose local declaration the script could not find. A hand check of those found the same causes as above (e.g. url.zig:268) but did not count them, so the census is a lower bound on wrong edges.

## Missed-call patterns (recall)
| function | real calls | emitted | missed | notes |
|---|---|---|---|---|
| `diff.diff` (src/bump/diff.zig:115–183) | 13 | 13 | 0 | `magnitude.combine` low: `magnitude` is bound to the enum literal `Magnitude.patch` (zig/16 gap). Plus 1 edge `std.ArrayListUnmanaged` for `std.ArrayListUnmanaged(Change).empty`, a type instantiation (gap G8) |
| `DenseMap.getOrPut` (src/collections/DenseMap.zig:114–132) | 7 | 7 | 0 | IDs follow the zig/18 convention (`DenseMap.keyIndex`) |
| `url.parseUrlPath` (src/base/url.zig:238–281) | 7 | 7 | 0 | 1 wrong callee (`version.isPresent`, see table) |

No missed calls in these three functions. Open defects zig/10 (file-level const initializers) and zig/11 (decl-literal calls) produce no edges by construction; none of the three functions contains those constructs.

## Spec gaps (counted separately, never as wrong)
| gap | construct (quoted) | question SPEC leaves open | edges |
|---|---|---|---|
| G4 (zig/16) | `const ls = self.layout_store;` · `const job = &context.jobs[item_id];` · `var arena = std.heap.ArenaAllocator.init(gpa);` · `var magnitude = Magnitude.patch;` | Does a Zig local without a type annotation take its type from an initializer that is a field, an index, a literal/enum constant, or a call whose return type is external? (The 2026-11-12 ruling covers only calls with a declared return type in the scan.) | 10,915 |
| G1 (zig/18) | `pub fn DenseMap(comptime K: type, comptime V: type) type { return struct { pub fn get … } }`, called as `DenseMap.get` (high); `const Emitter = struct {…}` declared inside a function | What ID does a member of a struct returned by an in-scan generic type function, or declared inside a function body, get? | 9,309 |
| G8 (zig/18) | `var changes = std.ArrayListUnmanaged(Change).empty;` produces an edge `→ std.ArrayListUnmanaged` (medium, direct); `DenseMap.DenseMap` (high) | Is a type-function instantiation `Generic(T)` in expression or type position an edge? (Scripted approximation; overlaps nothing in the wrong set) | ≈2,270 |
| G5 | `.checked_source => \|module_env\| { … module_env.deinit(); }` and other union, slice and complex captures | What type does a payload capture of a tagged union or loop element get? zig/05 decides only optional captures, which are in W11 | 668 |
| G2 | `pub const ConcurrentU64 = if (use_scalar) struct {…} else if (…) struct {…} else struct {…};` · `pub const Mutex = if (!is_freestanding) std.Io.Mutex else struct {…};` · `const debugPrint = if (is_freestanding) …` · `pub const Ctx = if (enable) ___tracy_c_zone_context else struct {…};` | What ID and tier does a member of a const bound to a comptime `if`/`switch` of types or functions get, when the branches are external and in-scan alternatives? | 485 |
| G3 (zig/18) | `codegen.emit.ldrRegMemSoff(..)` with `emit: Emit`, where `Emit = EmitMod.Emit(target)`; field `proc_bases: SafeList(ProcBaseKey).Serialized` | What is the ID of a method reached through a receiver whose declared type is an instance of an in-scan generic type function? | 453 |
| G6 (zig/14) | `const pushNext = struct { fn go(…) … }.go;` | Is `pushNext` a named nested function, an alias of an anonymous-struct member, or a callback? | 139 |
| G7 (zig/18) | `const Serde = artifact_serialize.SliceStoreSerde(CanonicalNameStore, @This()); pub const serialize = Serde.serialize;` | What ID does a member alias of a member of an in-scan generic instance resolve to? | 9 |
| zig/17 | basename qualifiers: `ast.*` names lambda_mono/ast.zig, monotype/ast.zig, monotype_lifted/ast.zig, … | Which file qualifier applies to a file in a subdirectory, and how are identical basenames told apart? | 37,887 (edges naming one of 33 colliding basenames) |

Helper scripts (prefix `h-roc_r18_`, in the fanout folder): load, peek, stats, sample (+`_sample.json`), ctx.sh, defs (+`_defs.json`), inv, medcls, lowsamp, typer, untyped, selff, letcall (+`.json`), cb, census (+`_wrong.json`), optcap (+`.json`), typeinst, recall.
