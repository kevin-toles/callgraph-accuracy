# Blind call-graph review: s-config (zig, ghostty src/config), round 13

precision 49/50; census ≈98.9% (13 wrong of 1148 in-scope); recall: 0 missed of 41 real calls; 0 non-calls

(Sample: 49 correct, 1 wrong. Two of the 49 are spec gaps, counted apart and never as wrong: `Wasm.zig:28` and `limit.zig:39`.)

## Scope
- **Source root:** `<source-root>/devtools/terminals/ghostty/src/config` (20 `.zig` files, 15,089 lines).
- **Tool JSON:** `final23-A/s-config.v2.json`. I ignored the `measured_accuracy` field.
- **In-scope edges:** all 1148 edges are Zig, and none sits under a test/, tests/, spec/, examples/ or docs/ segment, so all 1148 are in scope. `testdata/` holds only non-Zig theme files and has no edges.
- **Confidence split:** high 210, medium 754, low 184.
- **call_type split:** method 705, direct 443.
  - high: 107 method, 103 direct.
  - medium: 414 method, 340 direct.
  - low: 184 method.
- **Edges by file:** 19 files have edges. `Config.zig` has 755 of them. `url.zig` has none: it holds only regex string constants and one test.
- **Precision sample:** seed 13. One random edge from each of the first 16 files in a seeded shuffle, then filled per tier to 9 high, 33 medium and 8 low. That gives 50 edges over 17 files.
- **Recall:** 3 functions, one each from three files: `file_load.preferredAppSupportPath`, `command.Command#parseCLI` and `edit.openPath`.
- **Helper scripts:** `fanout/s-config_r13_*.py` (`load`, `sample`, `ctx`, `decl`, `caps`, `census`, `medrecv`, `missed`, `tests`).

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| command.zig:148 (sample) | `.shell => \|*v\| v.deinit(),` | Command.ArgIterator#deinit → `command.Command#deinit`, high, method | `v` is the `shell` payload of `ArgIterator`, declared `shell: std.process.Args.IteratorGeneral(.{})` → `std.process.Args.IteratorGeneral#deinit`, medium, method | wrong callee | union payload capture typed as the enclosing outer type `Command` |
| command.zig:137 | `.shell => \|*v\| v.next(),` | Command.ArgIterator#next → `command.Command#next`, medium, method | `std.process.Args.IteratorGeneral#next`, medium, method. `Command` defines no `next`, so the tool invented an ID (C2) | wrong callee | same |
| Config.zig:3967 | `if (self._arena) \|arena\| arena.deinit();` | Config.deinit → `arena.deinit`, low | field `_arena: ?ArenaAllocator` → `std.heap.ArenaAllocator#deinit`, medium, method | wrong callee / confidence | optional capture left untyped (open defect zig/05) |
| Config.zig:4683 | `try theme.finalize(alloc);` (capture `if (self.theme) \|*theme\|`, `theme: ?Theme`) | Config.finalize → `theme.finalize`, low | `Config.Theme#finalize`, high, method | wrong callee / confidence | optional capture left untyped (zig/05) |
| Config.zig:5355 | `.diagnostic => \|v\| .{ .diagnostic = try v.clone(alloc) },` | Replay.Step#clone → `v.clone`, low | union field `diagnostic: cli.Diagnostic` → `cli.Diagnostic#clone`, medium, method (Decision A covers pattern bindings) | wrong callee / confidence | switch-prong capture left untyped. The tool types the same construct at Config.zig:5717 |
| Config.zig:5360 | `for (v.conditions, 0..) \|cond, i\| conds[i] = try cond.clone(alloc);` | Replay.Step#clone → `cond.clone`, low | `conditions: []const Conditional` (alias of `conditional.Conditional`) → `conditional.Conditional#clone`, high, method | wrong callee / confidence | for-loop capture over a slice typed in the scan left untyped |
| Config.zig:5395 | `const cloned = diag.clone(arena_alloc) catch \|err\| {` (capture `.diagnostic => \|diag\|`) | Replay.Iterator#next → `diag.clone`, low | `cli.Diagnostic#clone`, medium, method | wrong callee / confidence | switch-prong capture left untyped |
| Config.zig:6022 | `self.mask.set(entry.index);` | Palette#parseCLI → `mask.set`, low | field `mask: terminal.color.PaletteMask` → `…PaletteMask#set`, medium, method. The module qualifier is spec gap G4 | wrong callee / confidence | declared field type not used (`self.set.put` with `set: inputpkg.Binding.Set` is resolved) |
| Config.zig:4356 | `var loaded = std.StringHashMap(void).init(alloc_gpa);` | loadRecursiveFiles → `.init`, low | `std.StringHashMap#init`, medium, method | wrong callee / confidence | static call on an instantiated generic type (open defect zig/12) |
| Config.zig:6173 | `var list = try std.ArrayListUnmanaged([:0]const u8).initCapacity(` | RepeatableString#clone → `.initCapacity`, low | `std.ArrayListUnmanaged#initCapacity`, medium, method | wrong callee / confidence | zig/12 |
| Config.zig:8734 | `var list = try std.ArrayListUnmanaged(inputpkg.Link).initCapacity(` | RepeatableLink#clone → `.initCapacity`, low | same as above | wrong callee / confidence | zig/12 |
| io.zig:181 | `var list = try std.ArrayListUnmanaged(ReadableIO).initCapacity(` | RepeatableReadableIO#clone → `.initCapacity`, low | same as above | wrong callee / confidence | zig/12 |
| io.zig:198 | same construct | RepeatableReadableIO#cloneParsed → `.initCapacity`, low | same as above | wrong callee / confidence | zig/12 |
| Wasm.zig:28 (sample) | `alloc.destroy(v);` (`const alloc = wasm.alloc;`) | config_free → `wasm.alloc.destroy`, medium, direct | undecided | spec gap G3 | a method on a value reached through an import, named as a module path |
| limit.zig:39 (sample) | `if (self.value == std.math.maxInt(T)) {` | `limit.formatEntry` → std.math.maxInt, medium, direct | the callee is right; the caller ID is undecided | spec gap G1 | member of the struct returned by `fn Limit(...) type` (zig/18) |
| Config.zig:6616 | `if (!builtin.target.os.tag.isDarwin()) {` | Keybinds#init → `builtin.target.os.tag.isDarwin`, medium, direct | undecided | spec gap G3 | as above |
| Config.zig:4356 | `std.StringHashMap(void)` | loadRecursiveFiles → `std.StringHashMap`, medium, direct | undecided | spec gap G2 | call of a type-returning function |
| Config.zig:6017 | `terminal.color.parsePaletteEntry(value)` | Palette#parseCLI → `terminal.color.parsePaletteEntry`, medium, direct | undecided | spec gap G4 | import nested in a file-local namespace struct |
| Config.zig:9618 | `primary.format(&writer)` (`const primary = self.primary orelse return;`) | QuickTerminalSize#formatEntry → `primary.format`, low | undecided | spec gap G6 | untyped local bound to `orelse` of a typed field (zig/16) |

The other 49 sample edges were judged correct: real call, right caller, right callee, right tier, right call_type, right line. The low `log.*`, `it.next`, `lines.next`, `list.items` and `a.equal` guesses are correct. Each receiver is a local bound to the result of a call outside the scan, or an `anytype` parameter, or reached only through std's `items` field, so no declaration in the scan types it.

## Systematic patterns (wrong), by scripted count
`s-config_r13_census.py`. I hand-checked every edge each pattern matched; all 13 were read in the source.

1. **Typed capture left as a low guess: 5.**
   - Optional captures of typed fields, open defect zig/05: Config.zig:3967 and 4683.
   - Switch-prong captures of union fields declared in the scan: 5355 and 5395.
   - For-capture over a slice field declared in the scan: 5360.
   - The tool types the same constructs elsewhere: `.color => |v| v.toTerminalRGB()` at 5717, and `if (self.secondary) |secondary| secondary.format` at 9621.
2. **Static call on an instantiated std generic type emitted as `.init`/`.initCapacity`, low: 5.** Open defect zig/12.
3. **Union payload capture typed as the enclosing outer union: 2** (command.zig:137 and 148). One of them is an invented medium ID, `command.Command#next`; the other is a wrong high, `command.Command#deinit`.
4. **Field receiver with a declared type left as a low guess: 1** (Config.zig:6022, `self.mask.set`).

Union: 13 wrong of 1148, so census precision = 1 − 13/1148 ≈ 98.87%.

## Missed-call patterns (recall)
The recall functions themselves had no misses:
- `file_load.preferredAppSupportPath`: 13 calls, 13 edges.
- `command.Command#parseCLI`: 12 calls, 12 edges. `std.meta.Tag(Self)` in a type annotation on line 53 is left out of the count as spec gap G2.
- `edit.openPath`: 16 calls, 16 edges.

Patterns found by looking (counted by `s-config_r13_missed.py`):
- **Zig `test "…" {}` blocks emit no edges at all.** 182 test blocks (top-level and nested in structs) hold about 1,850 call sites by regex count, and none has an edge. SPEC scopes by path segment only, and CAPABILITIES does not list test blocks as unsupported, so these are recall gaps. The caller ID they should get is spec gap G7.
- **File-level const initializers emit no edges** (open defect zig/10). About 15 calls in 9 initializers. Examples:
  - `const log = std.log.scoped(.config);` in CApi, Config, Wasm, file_load and path.
  - `std.StaticStringMap(…).initComptime(…)` and 3× `cli.compatibilityRenamed(...)` at Config.zig:64–75.
  - `std.meta.fields(Config)` at key.zig:8.
  - `std.math.IntFittingRange` at key.zig:22 and conditional.zig:40.
- **Decl-literal calls outside tests emit no edges** (open defect zig/11): 8. Examples are `.init(alloc, v)` at command.zig:120 and `.initEmpty()` at Config.zig:5992, plus `.parse` at 9591/9599 and `.initCapacity` at edit.zig:124. The `.fixed(&buf)` decl literals are emitted (`std.Io.Writer#fixed`), so this defect is only partly open.

## Spec gaps (counted separately, not wrong): 43 edges, plus the test-block caller question
- **G5, 16 edges: the out-of-scan module qualifier is the file basename.**
  - Construct: `internal_os.xdg.config(` with `internal_os = @import("../os/main.zig")` gives `main.xdg.config`. `fontpkg.face.Variation.Id.init(` with `fontpkg = @import("../font/main.zig")` gives `main.face.Variation.Id#init`.
  - Question: what qualifier does an imported Zig file outside the scan get? Two different modules collapse to the same `main.` prefix here. zig/17 covers only files inside the scan.
- **G3, 11 edges: a method on a value reached through an imported module path.**
  - Construct: `builtin.target.os.tag.isDarwin()` (8), `builtin.target.cpu.arch.isWasm()` (1), and `alloc.create(Config)` / `alloc.destroy(v)` with `const alloc = wasm.alloc;` (2). All are emitted as `medium, direct` module-path IDs.
  - Question: does the Zig rule "`@import` bindings make `std.x.y` medium" cover a path whose last receiver is a value, not a namespace? The value's type is knowable only outside the scan. Or is it a receiver guess (`tag.isDarwin`, low)?
- **G1, 7 edges: members of the anonymous struct returned by `pub fn Limit(comptime T: type, …) type`.**
  - Construct: callers `limit.parseCLI`, `limit.formatEntry` and `limit.optional`.
  - Question: what are these members' IDs? This is zig/18, undecided.
- **G2, 6 edges: calls of type-returning functions.**
  - Construct: `std.ArrayListUnmanaged(ReadableIO)` / `std.StringHashMap(void)` as a static-call receiver, and `std.meta.Tag(BackgroundBlur)` as an argument.
  - Question: is a comptime call that yields a type an edge? zig/18 asks this for type positions. Type-position uses, such as `var builder: std.ArrayList(u8)`, get no edge.
- **G4, 2 edges: an import nested in a file-local namespace struct.**
  - Construct: `const terminal = struct { const color = @import("../terminal/color.zig"); … }` with `terminal.color.parsePaletteEntry(value)` and `terminal.color.RGB.parse(input)`.
  - Question: is the ID the written path `terminal.color.…`, or the imported file's qualifier (`color.…`)?
- **G6, 1 edge: an untyped local bound to a non-call expression.**
  - Construct: `const primary = self.primary orelse return; primary.format(&writer)` (Config.zig:9618).
  - Question: does an unannotated Zig local take its type from a typed field it is bound to? This is zig/16. The let-bound ruling of 2026-11-12 covers call results only.
- **G7, no edges: the caller of a `test "name" { … }` block.**
  - Question: SPEC gives no caller ID for a Zig test block. Is it a module-scope caller (the file path), a named test function, or something else?
- **Noted, not counted:** a for-capture over `<field>.items` of a std container whose element type is declared in the scan. Examples are `for (self.links.items) |item| item.clone(...)` → `input.Link#clone` and `io.ReadableIO#clone`, while Config.zig:5163 `for (self._replay_steps.items) |item| item.clone(...)` is left low.
  - Under the 2026-11-09 rule ("typing reaches only declarations in the scan") the low guess is correct. Under "does not make a correctly resolved library type wrong", the typed edges are correct too. Neither side is counted.
  - Question: does the element type reached through std's `items` field count as a declaration in the scan?
