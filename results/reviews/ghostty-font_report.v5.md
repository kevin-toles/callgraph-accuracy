# ghostty-font call-graph review (zig), v5

**Summary:** precision 45/50; census ≈90.5% (271 wrong of 2861 in-scope); recall: 2 missed of 23 real calls; 0 non-calls

## Scope and what changed
- **Edge set:** 3059 edges, the same count as v4. In scope: 2861 `.zig` edges outside test files (700 high, 835 medium, 1303 low, 23 unknown). Out of scope: `nerd_font_codegen.py` and `glyf_rasterize_png_test.zig`.
- **Diff against `ghostty-font.v4a.json`:** 74 in-scope edges changed. Each one pairs 1:1 with an old edge at the same file, line, caller and member name. Only the callee and confidence differ.
  - Old: 54 low, 11 medium, 9 high.
  - New: 41 high, 31 medium, 2 low.
- **Changed-edge verification:** I checked all 74 against the source, more than the 30 required.
- **Precision sample:** 50 edges, seed `20261029`, from 19 files. Quota per tier: 11 high, 13 medium, 21 low, 5 unknown.
- **Recall:** the same three functions as in v3 and v4.
- **Conventions, unchanged from v4:**
  - Builtins are not calls.
  - Inferred locals (`const x = expr;`) and captures stay low and are accepted.
  - Spec-gap edges are accepted in precision and counted separately.

## Verification of all 74 changed edges: 69 correct, 3 spec gap, 2 still wrong, 0 regressions

| Group | Edges | Verdict | Evidence |
|---|---|---|---|
| `Thickness.light/heavy.height()` → `common.Thickness#height`, high | 35 | correct | `const Thickness = common.Thickness;` in box/powerline/geometric_shapes/symbols_for_legacy_computing; `pub fn height(self: Thickness, base: u32)` at common.zig:33. Callers checked; for example box.zig:268–293 lie inside `draw2500_257F` (:48–398). |
| `Fraction.one_third/two_thirds/half.float()` → `common.Fraction#float`, high | 3 | correct | `const Fraction = common.Fraction;` and `pub inline fn float` at common.zig:243 |
| `self.faces.*` → `std.EnumArray#iterator/getPtr/get`, medium | 12 | correct | `faces: StyleArray` (:37); `const StyleArray = std.EnumArray(Style, …)` (:698) |
| Metrics.zig:338 `mods.iterator()` → `std.AutoHashMapUnmanaged#iterator`, medium | 1 | correct | `mods: ModifierSet`; `pub const ModifierSet = std.AutoHashMapUnmanaged(Key, Modifier)` (:448) |
| CodepointResolver `descriptor_cache.*` ×4 and SharedGridSet `map.*` ×5 → `std.HashMapUnmanaged#…`, medium | 9 | correct | Both R2 fixes; the false self-recursion edges are gone. |
| discovery.zig:467/487/494 → `discovery.CoreText#discoverCodepoint`/`#discover`, high | 3 | correct | R3 fix |
| face/freetype.zig `self.face.deinit/hasColor` → `freetype.Face#…`, medium | 6 | correct | R1 fix (`const freetype = @import("freetype");`) |
| shaper/Cache.zig:61/74/86 `self.map.*` → `main.CacheTable#get/put/clear`, medium | 3 | spec gap | `map: CellCacheTable` → `CacheTable(…)` → `@import("../../datastruct/main.zig").CacheTable`. This is the out-of-scan import named by its basename. |
| discovery.zig:646 `lhs_score.int()` / `rhs_score.int()` | 2 | still wrong | Was `discovery.CoreText#int` medium (N3); now `lhs_score.int` low (A). The receiver is `const lhs_score: Score`, so the callee should be `discovery.CoreText.Score#int`, high. The caller is still `CoreText#lessThan` (N4). |

## Precision sample (45/50)
- **High (11/11):**
  - `SmoothMosaic#from`, `branchNode` ×3, `cellDiagonal`, `linesChar` ×2, `dashHorizontal`, `testAppendInt`
  - `CoreText#copyMatchingDescriptors` (bare call inside the struct)
  - `canvas.Point` from `p2: Point(T)`: a spec gap (comptime type function in a type position), accepted
- **Medium (13/13):**
  - Correct: `macos.text.Font#release`, `z2d.Surface#getHeight`, `std.ascii.*` ×2, `std.ArrayList#append` (`var descriptors: std.ArrayList(…)`), `std.mem.Allocator#free`, `std.fmt.allocPrint`, `std.fmt.format`, `std.mem.eql`, `compat_reader.readerInt`, `global.io` ×2
  - Spec gap: `main.sprite.Canvas#invert`
- **Low (16/21):**
  - Correct (inferred locals, captures or `anytype`): `face`, `entry_or_alias`, `size`, `path`, `formatter`, `family_name`, `hb_font`, `font` (local at discovery.zig:590), `data`, `fc.pattern`, `run.group.group`
  - Spec gaps:
    - `self.lib.mutex` (reached only through the `font.Library` re-export)
    - `log.err`, `log.warn` (`std.log.scoped`)
    - `assert` ×2 (function alias)
  - Wrong: #26, #29, #31, #32, #33. See the table below.
- **Unknown (5/5):** `autoHash` ×4 and `autoHashStrat`. All are the function-alias spec gap.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| discovery.zig:1174 (sample #26) | `const path_owned = try self.alloc.dupeZ(u8, full_path);` | Windows.DiscoverIterator#makeDeferred → `alloc.dupeZ`, low, method | `std.mem.Allocator#dupeZ`, medium (field `alloc: Allocator` at :1005) | wrong callee / wrong confidence | A: typed field left low |
| face/coretext.zig:507 (sample #29) | `context.setGrayStrokeColor(ctx, strength / 255.0, 1);` | coretext.Face#renderGlyph → `context.setGrayStrokeColor`, low | Static call on the alias `const context = macos.graphics.BitmapContext.context;` (:452), with the alias expanded: `macos.graphics.BitmapContext.context.setGrayStrokeColor`, medium | wrong callee / wrong confidence | B2 (newly found): a function-local alias of an external namespace/type is treated as an inferred value |
| shaper/harfbuzz.zig:268 (sample #31) | `self.shaper.hb_buf.reset();` | RunIteratorHook#prepare → `hb_buf.reset`, low | `harfbuzz.Buffer#reset`, medium (`shaper: *Shaper` :264, `hb_buf: harfbuzz.Buffer` :29) | wrong callee / wrong confidence | A2: multi-hop typed field chain |
| shaper/coretext.zig:334 (sample #32) | `try self.cell_buf.ensureTotalCapacity(self.alloc, state.codepoints.items.len);` | coretext.Shaper#shape → `cell_buf.ensureTotalCapacity`, low | `std.ArrayListUnmanaged#ensureTotalCapacity`, medium (`cell_buf: CellBuf` :53; `const CellBuf = std.ArrayListUnmanaged(font.shape.Cell);` :82) | wrong callee / wrong confidence | A: an alias of a type-function instance declared inside a struct is not followed (the claimed CellBuf/CodepointList fix is not present) |
| discovery.zig:321 (sample #33) | `const font_pattern = try self.config.fontRenderPrepare(` | Fontconfig.DiscoverIterator#next → `config.fontRenderPrepare`, low | `fontconfig.Config#fontRenderPrepare`, medium (`config: *fontconfig.Config` :303) | wrong callee / wrong confidence | A: typed field left low |
| SharedGridSet.zig:118, :430 | `errdefer self.map.removeByPtr(gop.key_ptr);` / `self.map.removeByPtr(entry.key_ptr);` | → `map.removeByPtr`, low | `std.HashMapUnmanaged#removeByPtr`, medium | wrong callee / wrong confidence | A: R2 fix is partial. The other 5 `self.map.*` calls on the same field resolve. |
| shaper/noop.zig:40 | `self.codepoints.deinit(alloc);` | noop.Shaper.RunState#deinit → `codepoints.deinit`, low | `std.ArrayListUnmanaged#deinit`, medium (`const CodepointList = std.ArrayListUnmanaged(Codepoint);` :30, nested in `Shaper`) | wrong callee / wrong confidence | A: nested type-function alias |
| discovery.zig:646 (recall) | `return lhs_score.int() > rhs_score.int();` | discovery.CoreText#lessThan → `lhs_score.int` / `rhs_score.int`, low | caller `discovery.CoreText#sortMatchingDescriptors`; callee `discovery.CoreText.Score#int`, high (`const lhs_score: Score`, `pub fn int` :687) | wrong caller / wrong callee / wrong confidence | N4 + A. The callee moved from a non-existent `CoreText#int` to low `recv.m`, which is still wrong. |
| discovery.zig:643, :644 (recall) | `const lhs_score: Score = .score(desc_inner, lhs);` | no edge | `discovery.CoreText.Score#score`, high | missed call | decl literals are never emitted |
| face/coretext.zig:130–134, discovery.zig:807–809 | `const cf_name = dict.getValue(Key.name.Value(), Key.name.key()).?;` | → `name.key` / `name.Value`, low | `macos.text.FontVariationAxisKey#key` / `#Value`, medium (`const Key = macos.text.FontVariationAxisKey;`, a local alias of an external enum) | wrong callee / wrong confidence | N2: the enum index covers only in-scan enums |
| shaper/run.zig:330/340/364 (recall) | `return try self.opts.grid.getIndex(` | → `grid.getIndex`, low | `SharedGrid.getIndex`, high | wrong callee / wrong confidence | A2 |
| shaper/run.zig:349 (recall) | `if (!cell.hasGrapheme()) return primary;` | → `.hasGrapheme`, low | `main.Cell#hasGrapheme`, medium (as the tool resolves `cell` at :326) | wrong callee | D |
| face/coretext.zig:120 | `if (ct_font.copyAttribute(.variation_axes)) \|axes\| {` | → `coretext.Face#copyAttribute`, medium | `macos.text.Font#copyAttribute`, medium | wrong callee | N3 remnant |
| shaper/harfbuzz.zig:86 | `errdefer alloc.free(hb_feats);` | → `harfbuzz.Shaper#free`, medium | `std.mem.Allocator#free`, medium | wrong callee | N3 remnant |
| SharedGrid.zig:94 | `var atlas_color = try Atlas.init(alloc, 512, .bgra);` | → `Atlas.init`, low | `Atlas.init`, high | wrong confidence | B |
| shaper/Cache.zig:61 | `return self.map.get(run.hash);` | → `main.CacheTable#get`, medium | no rule for naming an out-of-scan `@import` file | spec gap | `@import("../../datastruct/main.zig")` named by its basename, which collides with the in-scan `main` |
| face/freetype.zig:146 | `self.lib.mutex.lockUncancelable(global.io());` | → `mutex.lockUncancelable`, low | resolvable only by following the `font.Library` re-export | spec gap | Zig re-export chain |

## Recall detail (21 of 23 found; 2 missed; 0 non-calls)
- **`canvas.Canvas#writeAtlas`: 8 of 8 found.**
  - Correct: `canvas.Canvas#trim` and `z2d.Surface#getWidth`/`#getHeight`.
  - Spec gaps: `assert` ×3 (alias) and `main.Atlas#reserve`/`#setFromLarger` (re-export).
- **`run.RunIterator#indexForCell`: 10 of 10 found.**
  - `main.Cell#…` ×4 are out-of-scan import names (gap).
  - Still wrong: `grid.getIndex` ×3 (A2), `.hasGrapheme` (D), `.hasCodepoint` ×2 (D/A2).
- **`discovery.CoreText#sortMatchingDescriptors`: 3 of 5 found.**
  - Found: `std.mem.sortUnstable`, plus the 2 `int` calls, which have the wrong caller and the wrong callee.
  - Missed: `.score` ×2 (decl literals).
  - `}.lessThan` is a function reference, and the tool correctly emits no edge.

## Systematic patterns (scripted census over 2861 in-scope edges, ordered by count)
- **Union: 271 wrong edges.** Identical duplicate edges count separately. Overlaps: A/N4 4 and D/A2 2.
- **Comparison with v4:** on v4's detector set alone, the union is 235 (v4: 310). The other 36 come from two patterns that are newly counted here (B2 21, A2 widened by 12). Both were already present in v4a.
- **Script:** <fanout>/ghostty-font_v5_census3.py

1. **A: typed receiver left low `recv.m`. 142 edges** (v4: 156).
   - Breakdown: 57 parameters, 28 locals, 57 `self.<field>`.
   - Main types:
     - `Allocator` 35 (20 parameters, 15 fields)
     - `*font.sprite.Canvas` 16 (all of braille.zig)
     - `CellBuf` 16, `CodepointList` 4, `RunBuf` 3, `RunState` 2: type-function aliases declared inside a struct (`Shaper`) in shaper/coretext, harfbuzz, noop and web_canvas
     - `Collection.LoadOptions` 9, `Metrics.FaceMetrics` 7, `*macos.text.Font` 6, `*font.Atlas` 7
     - `SimpleFlags` 4, `std.ArrayList(Node)` 3, `Map` 2 (`removeByPtr`), `Score` 2
2. **B: static call on a file-level type alias left low. 24 edges** (unchanged).
3. **B2 (newly found, pre-existing): static call through a function-local alias of an external namespace/type is left low. 21 edges.**
   - `const context = macos.graphics.BitmapContext.context;` ×20 in face/coretext.zig `renderGlyph`.
   - `const testing = std.testing;` ×1 (sprite/Face.zig:465).
4. **D: named receiver after `!` emitted as computed `.m`. 20 edges** (unchanged).
5. **A2: multi-hop typed field chain left low. 19 edges.**
   - `self.opts.grid.*` 7, as in v4.
   - `self.shaper.<field>.*` 12 (newly counted): `hb_buf` ×6, `codepoints` ×2, `run_state` ×2, `run_buf` ×2, in RunIteratorHook of harfbuzz/coretext/noop/web_canvas.
   - Chains that are resolvable only through a re-exported type (`self.lib.*`, `self.resolver.collection.*`, `self.cf_release_thread.*`, 10 edges) are counted as spec gap, not here.
6. **N2: enum constant or type path cut to two segments, low. 17 edges** (v4: 55).
   - `Key.<axis>.key()/Value()` ×16, from a local alias of the external enum `macos.text.FontVariationAxisKey`.
   - `CodepointResolver.StyleStatus.initFill` ×1.
7. **N4: anonymous struct-literal members become callers. 10 edges** (unchanged).
8. **N2b: external enum constant kept in the callee path. 9 edges** (unchanged), for example `macos.text.FontAttribute.family_name.key`.
9. **N1: field `font` promoted to the file-level `font` import. 7 edges** (unchanged).
10. **C: function on an out-of-scan `@import` module left low. 6 edges** (unchanged).
11. **N3: callee names a non-existent member of the enclosing type. 2 edges** (v4: 4). They are face/coretext.zig:120 and shaper/harfbuzz.zig:86.
12. **R1, R2, R3: 0 edges each** (v4: 6, 9, 3).
13. **Missed calls (not in the precision census):**
    - Decl literals: 79 of 79 sites, still no edges.
    - File-level `const` initializers still emit no edges (main.zig:68 `Collection.Index.initSpecial`).

## Spec gaps (counted separately, not as wrong)
- **Zig re-exports through font/main.zig, named as written: 170 medium edges** (unchanged).
  - `main.sprite.Canvas` 105
  - `main.Metrics.ModifierSet` 16
  - `main.Collection` 12, and others
- **Out-of-scan `@import` file named by its basename: 15 medium edges** (v4: 12).
  - `main.page.Cell` 8, `main.Cell` 4
  - New: `main.CacheTable` 3, through the `CellCacheTable` alias.
- **Multi-hop chains reachable only through a re-exported type: 10 low edges.**
- **External type ID collides with an in-scan ID: 19 medium edges** (unchanged), for example `freetype.Face#getSfntName`.
- **Const aliases of functions: 140 edges** (118 low, 22 unknown). `log.*` through `std.log.scoped`: 70 low.
- **Comptime type-function calls in type positions: 41 edges.**
- **Inferred locals:** 626 low edges, by design.

## Previous findings

| v4 item | Status | Counts (v4 → v5) |
|---|---|---|
| R1: external `freetype.Face` matched to the in-scan def, high | **Fixed** | 6 → 0. Now `freetype.Face#deinit/hasColor`, medium. |
| R2: type-function-alias field resolved to the file-as-struct | **Fixed (partly incomplete)** | 9 → 0 wrong-callee edges. CodepointResolver.zig:63/254 and SharedGridSet.zig:65/72/85/107/417 are now `std.HashMapUnmanaged#…`. Two `self.map.removeByPtr` calls on the same field (SharedGridSet.zig:118, :430) are still low `map.removeByPtr`; they are counted in A. |
| R3: `self: *const T` emitted as a free function | **Fixed** | 3 → 0. discovery.zig:467/487/494 are `discovery.CoreText#…`, high. |
| N2: enum constant / type path | **Mostly fixed** | 55 → 17. All 35 `Thickness` and 3 `Fraction` edges are fixed (high). Left: `Key.*` 16, a local alias of an external enum, and `StyleStatus.initFill` 1. |
| A: typed receiver low | **Partly fixed** | 156 → 142. Fixed: `StyleArray` 12, `ModifierSet` 1, `CellCacheTable` 3 (now the `main.CacheTable` gap). Not fixed, despite the claim: `CellBuf` 16, `CodepointList` 4 and `RunBuf` 3. These are all declared inside `Shaper`, not at file level. `lhs_score/rhs_score.int` (2) moved here from N3. |
| A2: multi-hop typed chain | **Still present; wider than counted** | 7 → 19. The +12 `self.shaper.*` edges were present in v4a and are newly counted. |
| N3: member of the enclosing type | **Partly fixed** | 4 → 2. The 2 `int` edges moved to A, so they are still wrong. coretext.zig:120 and harfbuzz.zig:86 remain. |
| B: static call on a type alias, low | **Still present** | 24 → 24 |
| D: named receiver as `.m` | **Still present** | 20 → 20 |
| N4: anonymous struct members as callers | **Still present** | 10 → 10 |
| N2b: external enum constant in the callee path | **Still present** | 9 → 9 |
| N1: field `font` promoted to the import | **Still present** | 7 → 7 |
| C: `@import` module function, low | **Still present** | 6 → 6 |
| Table: CodepointResolver.zig:63, :254; SharedGridSet.zig:72/85, :65/:417 | **Fixed** | R2 |
| Table: face/freetype.zig:149/216/231/329/342/365 | **Fixed** | R1 |
| Table: discovery.zig:467/487/494 | **Fixed** | R3 |
| Table: box.zig:129 `light.height` | **Fixed** | `common.Thickness#height`, high |
| Table: shaper/coretext.zig:98 `codepoints.deinit` | **Still present** | nested `CodepointList` alias |
| Table: Collection.zig:641 `face_metrics.exHeight` | **Still present** | A. In Collection.zig the `faces` edges are fixed; `face_metrics` ×7 is not. |
| Table: braille.zig:146 `canvas.box` | **Still present** | A, 8 edges in braille.zig |
| Table: face/coretext.zig:120, harfbuzz.zig:86 | **Still present** | N3 |
| Table: DeferredFace.zig:157 `font.copyAttribute` | **Still present** | N1 |
| Table: discovery `macos.text.FontAttribute.family_name.key` | **Still present** | N2b |
| Table: run.zig `grid.getIndex` ×3 | **Still present** | A2 |
| Table: run.zig:349 `.hasGrapheme` | **Still present** | D |
| Table: discovery.zig:646 `int` ×2 / `lessThan` caller | **Partly changed, still wrong** | callee is now low `lhs_score.int` (was medium `CoreText#int`); the caller is still wrong |
| Table: discovery.zig:643/644 missed `.score` | **Still present** | decl literals: 79 of 79 missed |
| Table: SharedGridSet.zig:138 `StyleStatus.initFill` | **Still present** | N2 |
| Table: SharedGrid.zig:94 `Atlas.init` low | **Still present** | B |
| Table: Atlas.zig:475 `js.string` low | **Still present** | C |
| Table: main.zig:68 missed `initSpecial` | **Still present** | file-level initializers emit no edges |
| Spec-gap rows: `main.sprite.Canvas#…`, `main.page.Cell#…` | **Unchanged gaps** | re-export 170 → 170; out-of-scan import name 12 → 15 (+3 `main.CacheTable`) |
| Regressions introduced by this fix round | **None** | 0 of the 74 changed edges went from correct to wrong |

Helper scripts (read-only on the repo), all in <fanout>/:
- `ghostty-font_v5_common.py`
- `ghostty-font_v5_diff.py`
- `ghostty-font_v5_pairs.py`
- `ghostty-font_v5_changed.py`
- `ghostty-font_v5_sample.py`
- `ghostty-font_v5_typed.py`
- `ghostty-font_v5_patterns.py`
- `ghostty-font_v5_census2.py`
- `ghostty-font_v5_census3.py`
- `ghostty-font_v5_a2.py`
- `ghostty-font_v5_localalias.py`
- `ghostty-font_v5_recall.py`
- `ghostty-font_v5_ctx.py`
- `ghostty-font_v5_declit.py`
