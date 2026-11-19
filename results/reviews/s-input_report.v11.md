# s-input (zig) — blind call-graph review, round 11

precision 49/50; census ≈98.4% (12 wrong of 730 in-scope); recall: 0 missed of 47 real calls; 0 non-calls

## Scope
Source root `ghostty/src/input` holds 17 `.zig` files. No path segment is named test/tests/spec/examples/docs, so all 730 edges are in scope. They come from 12 files; KeymapNoop, config, kitty, keycodes and mouse have no edges.
- Confidence: high 152, medium 484, low 94.
- call_type: method 403, direct 327.
- By tier and type: medium/direct 302, medium/method 182, high/method 127, low/method 94, high/direct 25.

I ignored the `measured_accuracy` field. Helper scripts are `s-input_r11_load.py`, `_dump.py`, `_sample.py`, `_lows.py`, `_census.py`, `_scopes.py` and `_filelevel.py`, all in the fanout folder.

**Method.**
- **Sample:** stratified by confidence (high 10, medium 33, low 7) with seed 11 (`random.Random(11)`). It first takes one edge from each file that has edges, which covers all 12, then fills each tier's quota at random.
- **Census:** I read every one of the 730 edges against its source line. I also checked every low edge's receiver declaration by hand. The scripted census in `s-input_r11_census.py` counts each wrong pattern, and I checked each of its hits by hand.

Sample result: 49 of 50 correct and 1 wrong (Binding.zig:2159, pattern W2). Two of the 49 are spec gaps (Binding.zig:2642, key_encode.zig:457), which I counted as not wrong.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| Binding.zig:2159 | `var iter = set.bindings.iterator();` | Binding.Set.Value#format → `bindings.iterator`, low, method | `std.ArrayHashMapUnmanaged#iterator`, medium, method. `set` is the `.leader => \|set\|` payload of `self: Value`, declared `leader: *Set`, and `bindings: HashMap` is an alias of `std.ArrayHashMapUnmanaged(..)` | wrong callee / wrong confidence | switch-capture payload not typed |
| Binding.zig:2197 | `var iter = set.bindings.iterator();` | Binding.Set.Value#formatEntries → `bindings.iterator`, low | `std.ArrayHashMapUnmanaged#iterator`, medium | wrong callee / wrong confidence | switch-capture payload not typed |
| Binding.zig:2434 | `error.SequenceUnbind => if (s.bindings.count() == 0) {` | Binding.Set#parseAndPutRecurse → `bindings.count`, low | `std.ArrayHashMapUnmanaged#count`, medium. `old: ?Value`, then `if (old) \|entry\| switch (entry) { .leader => \|s\|` | wrong callee / wrong confidence | optional capture followed by switch capture not typed |
| key.zig:324 | `if (entry[1].keypad()) continue;` | key.Key#fromASCII → `.keypad`, low | `key.Key#keypad`, high. `codepoint_map: []const struct { u21, Key }`, the for-loop capture is `entry`, and `entry[1]` is `Key` | wrong callee / wrong confidence | for-capture tuple index not typed |
| mouse_encode.zig:111 | `if (last_cell.eql(cell)) return;` | mouse_encode.encode → `last_cell.eql`, low | `point.Coordinate#eql`, medium. Declared `last_cell: ?*?point.Coordinate`, captured through two optional captures | wrong callee / wrong confidence | optional capture not typed (matches open defect zig/05) |
| KeymapDarwin.zig:152 | `}).ucKeyTranslate();` (from `(CarbonMods{ … })`) | KeymapDarwin.translate → `.ucKeyTranslate`, low | `KeymapDarwin.CarbonMods#ucKeyTranslate`, high (Typed call results: a literal receiver is typed) | wrong callee / wrong confidence | struct-literal receiver not typed |
| key_encode.zig:690 | `const ctrl_only = comptime (key.Mods{ .ctrl = true }).int();` | key_encode.ctrlSeq → `.int`, low | `key_mods.Mods#int`, high (`key.Mods` is an alias of `key_mods.Mods`) | wrong callee / wrong confidence | struct-literal receiver not typed |
| mouse_encode.zig:276 | `} }).convert(.terminal, size).terminal;` (from `(renderer_size.Coordinate{ … })`) | mouse_encode.posToPixels → `.convert`, low | `size.Coordinate#convert`, medium. This is the ID the tool itself gives at :264 for a declared `coord: renderer_size.Coordinate` | wrong callee / wrong confidence | struct-literal receiver not typed (C2 inconsistency with :264) |
| key_mods.zig:328 | `const side_mask = comptime Mods.side_mask.int();` | key_mods.RemapSet#finalize → `side_mask.int`, low | `key_mods.Mods#int`, high. Declared `pub const side_mask: Mods = .{…}` | wrong callee / wrong confidence | typed container-level const not used as a receiver type |
| key_encode.zig:88 | `return if (opts.kitty_flags.int() != 0) try kitty(` | key_encode.encode → `key.Flags#int`, medium | Not `key.Flags#int`. `KittyFlags = @import("../terminal/kitty/key.zig").Flags` is outside the scan, but `key` is the scanned module key.zig, which defines no `Flags` (C2: an ID is never invented). The qualifier for this out-of-scan file is itself undecided (zig/17) | wrong callee | out-of-scan file basename collides with a scanned module |
| key_encode.zig:106 | `if (opts.kitty_flags.int() == 0) return try legacy(` | key_encode.kitty → `key.Flags#int`, medium | same as :88 | wrong callee | same |
| key_encode.zig:639 | `for (function_keys.keys.get(keyval)) \|entry\| {` | key_encode.pcStyleFunctionKey → `function_keys.keys.get`, medium, direct | `keys.get`, low, method. `keys` is a value (`pub const keys = keys: {…}`), not a function of the scanned module, so the medium ID names nothing defined there (C2/C4) | wrong callee / wrong confidence | value member path of a scanned module named as a module function |
| Binding.zig:2642 | `.leaf_chained => \|*leaf\| try leaf.actions.append(` | → `actions.append`, low | spec gap SG2 | spec gap | — |
| key_encode.zig:457 | `if (!mods_no_shift.empty()) break :should_modify true;` | → `mods_no_shift.empty`, low | spec gap SG2 | spec gap | — |

The other spec-gap edges (SG1, SG3–SG6) are listed with their sites under Spec gaps.

## Systematic patterns (scripted counts; union 12 of 730)
1. **W2: receivers bound by a capture whose payload type is declared in the scan are left as low guesses: 5.** These are switch-on-union payloads (Binding.zig:2159, :2197), an optional then union capture (Binding.zig:2434), a for-capture tuple index (key.zig:324) and a nested optional capture (mouse_encode.zig:111). The last one matches open defect zig/05. This is decision A (pattern binding / for-loop variable) together with "Typed call results" (index). The script matches the hand-validated capture sites among low edges; I re-judged all 94 low edges by hand to make sure nothing else belongs here.
2. **W1: a struct literal receiver `(T{…}).m()` is emitted as `.m`, low: 3** (KeymapDarwin.zig:152, key_encode.zig:690, mouse_encode.zig:276). Per Decisions 2026-11-10 "Typed call results", a literal receiver is typed when its static type is determinable. All three name their type in the literal. Script: callee starts with `.`, the line has `}).m(`, and a `(Name{` appears up to 8 lines above.
3. **W4/W5: a medium callee names a member of a scanned module that the module does not define: 3.**
   - `key.Flags#int` ×2: the out-of-scan `../terminal/kitty/key.zig` gets the same qualifier as the scanned key.zig.
   - `function_keys.keys.get` ×1: a value path is named as if it were a module function.
   - Script: the callee's first segment is a scanned file's basename, the tier is medium, and the name is not declared in that file. The first version of the script also matched 7 `KeymapDarwin.TIS*/UCKeyTranslate/LMGetKbdType` edges. Those are `extern "c" fn` prototypes declared in KeymapDarwin.zig (lines 237–241), so medium is correct per Decisions 2026-11-09, and they are excluded.
4. **W3: a typed container-level decl used as a receiver (`Type.decl.m()`) is left low: 1** (key_mods.zig:328). This is decision A for file-scope/container globals (Decisions 2026-10-29) and is the same family as open defect zig/05.

## Missed-call patterns (recall)
Recall check (3 functions):
| Function | Calls |
|---|---|
| `Binding.Set#getEvent` (Binding.zig:2696–2735) | 11 |
| `key_mods.RemapSet#parse` (key_mods.zig:253–308) | 15 |
| `mouse_encode.encode` (mouse_encode.zig:81–170) | 21 |

Every one of the 47 calls has an edge with the right caller and line, and there are no non-calls. The only flaw is mouse_encode.zig:111, which has a wrong callee (W2).

Missed calls found by looking outside the three functions:
- **Calls inside Zig `test "…" {}` / `test name {}` blocks get no edges at all:** about 1,459 call sites, a regex estimate over 254 test blocks in 11 files (`s-input_r11_scopes.py`). CAPABILITIES does not list this as unsupported, and these files are in scope. The only edges inside test blocks are the 4 from the named local struct `Sink` (see SG5).
- **Calls in file-level / container-level const initializers get no edges: 125** (`s-input_r11_filelevel.py`, excluding type-function calls). This is open defect zig/10.

  | File | Missed calls | Where |
  |---|---|---|
  | function_keys.zig | 116 | `keys` initializer: `KeyEntryArray.initFill`, `result.set`, `pcStyle`, `cursorKey`, `kpKeys` |
  | command.zig | 5 | `defaults` / `defaultsC`: `actionCommands` ×2, `std.mem.sortUnstable`, `assert`, `cmd.comptimeCval` |
  | keycodes.zig | 2 | `code_to_key.get`, `…initComptime` |
  | Binding.zig | 1 | :1848 `initComptime` |
  | mouse_encode.zig | 1 | :10 `std.log.scoped` |

## Spec gaps (20 edges, not counted as wrong)
- **SG1, a value path through an `@import` binding: 5 edges** (key.zig:740, :862; key_mods.zig:135, :153; key_encode.zig:434).
  - Construct: `if (comptime builtin.target.os.tag.isDarwin())`, emitted as `builtin.target.os.tag.isDarwin`, medium, direct.
  - Open question: SPEC says "`@import` bindings make `std.x.y` medium". It does not say whether a path whose segments are values (`builtin.target` is a declared constant, not a namespace) is still a module-function path, or a receiver of unknown type (`tag.isDarwin`, low, method).
- **SG2, a local inferred from a non-call initializer: 4 edges** (Binding.zig:2642, :2672; key_encode.zig:457, :470).
  - Constructs: `const parent = self.chain_parent orelse return error.NoChainParent;` with `chain_parent: ?ChainParent`; `const mods = mods: { … break :mods mods_binding; };`; `var mods_no_shift = mods;`.
  - Open question: the let-bound ruling of 2026-11-12 types a local bound to a call result. SPEC does not say whether a Zig local with no annotation takes the type of an `orelse` unwrap, a labeled block or a copied local (compare CAPABILITIES zig/16).
- **SG3, a builtin's result as receiver: 2 edges** (Binding.zig:1485, :1522).
  - Constructs: `const action = @unionInit(Action, field.name, undefined); if (action.scope() == s)`, and `@unionInit(Action, @tagName(tag), undefined).scope()`.
  - Open question: SPEC does not say whether a compiler builtin whose result type is its type argument (`@unionInit(T, …)`) gives a declared type for "Typed call results".
- **SG4, members of the anonymous struct returned by an in-scan type function: 2 edges** (Binding.zig:2868 `return @truncate(k.hash());`, :2879 `return a.bindingSetEqual(b);`).
  - Construct: `fn Context(comptime KeyType: type) type { return struct { pub fn hash(…) … pub fn eql(…) … }; }`. The tool gives the callers as `Binding.Set#hash` and `Binding.Set#eql`.
  - Open question: this is CAPABILITIES zig/18. SPEC does not say whether such a member is `T#m` with the function standing for the type, or folds into the type function as an anonymous-type member.
- **SG5, a named struct type local to a `test` block: 4 edges** (paste.zig:262 ×2, :266, :270).
  - Construct: `test "encodeWriter chunks…" { const Sink = struct { … fn drain(…) { self.list.appendSlice(…) } }; }`. The tool gives the caller as `paste.Sink#drain`.
  - Open question: SPEC defines no ID for a `test` block, and none for a named type declared inside a function or test body. The same gap leaves the caller of the ≈1,459 missed test-block calls undefined.
- **SG6, a file-as-struct member called through a receiver: 3 edges** (KeymapDarwin.zig:63 `try keymap.reinit();`, :75 `try self.reinit();`, :116 `self.sourceId(&buf)`). The tool gives `KeymapDarwin.reinit`, direct.
  - Open question: a Zig file with top-level fields is itself a struct type (`const Keymap = @This();`). SPEC's Zig note gives `file.Struct#fn` and `file.fn`, but does not say whether such a file's functions are `file.fn` (direct) or a type's members `File#fn` (method, per the `self.m()` rule).
- **Recall-side gap with no edges, type-function calls in type positions: ≈15 sites.** Examples: `std.ArrayList(Action)`, `std.ArrayHashMapUnmanaged(Trigger, …, Context(Trigger), …)`, `?Scoped(s)`. These are comptime function calls. SPEC (zig/18) leaves open whether a call such as `Stack(u8)` in a type position is an edge.
