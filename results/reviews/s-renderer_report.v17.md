# s-renderer (zig): blind call-graph review, round 17

precision 47/50; census ≈99.1% (14 wrong of 1512 in-scope); recall: 0 missed of 35 real calls; 0 non-calls

(The 3 sample edges that are not counted as correct are spec gaps, not errors: 0 of 50 are wrong.)

## Scope
Source root `ghostty/src/renderer`, tool output `final23-A/s-renderer.v2.json`. All 1512 edges are Zig, and none sit under a test/tests/spec/examples/docs path segment, so **all 1512 are in scope**. They span 31 of the 35 `.zig` files (Options.zig, WebGL.zig, cursor.zig and metal/api.zig have no edges). Confidence: high 250, medium 699, low 563, unknown 0. call_type: method 1130, direct 382. No callback, constructor, macro or implicit edges. Split: high/direct 137, high/method 113, medium/method 456, medium/direct 243, low/method 561, low/direct 2. I ignored the `measured_accuracy` field. Helper scripts are `fanout/s-renderer_r17_*.py`.

Sample: seed 1717, quotas high 8 / medium 23 / low 19, covering 16 files. Results: 47 correct. 3 are spec gaps (#32 `GraphicsAPI.Buffer` type-function call, zig/18; #47 `t.drainMailbox` with `const t = self_.?`, zig/16; #48 `block.renderer.frameCompleted` on an in-scan generic instance, zig/18). 0 are wrong. Separately, 12 sample edges have zig/18 caller IDs and 18 have zig/17 basename IDs. Those are listed under spec gaps and are not counted wrong.

## Mismatch table (wrong edges: all 14 from the census, with hand checks; sample rows that are spec gaps at the end)
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| cell.zig:277 | `const prev_cp = raw_slice[x - 1].codepoint();` | cell.constraintWidth → `.codepoint`, low, method | element type of the param `raw_slice: []const terminal.page.Cell`: `main.page.Cell#codepoint` (tool's qualifier form), medium | wrong callee/confidence | index of a typed parameter slice not typed (Typed call results ruling: index). `self.fg_rows[0].m()` is typed. |
| cell.zig:285 | `const next_cp = raw_slice[x + 1].codepoint();` | same, `.codepoint` low | same | wrong callee/confidence | same |
| generic.zig:298 | `for (&self.frames) \|*frame\| frame.deinit();` | generic.SwapChain#deinit → `frame.deinit`, low | field `frames: [buf_count]FrameState` → `generic.FrameState#deinit`, high | wrong callee/confidence | for-loop capture of a typed array field not typed (decision A for-loop variable) |
| opengl/RenderPass.zig:120 | `for (s.buffers[1..], 1..) \|b, i\| if (b) \|buf\| { _ = buf.bindBase(...)` | RenderPass.step → `buf.bindBase`, low | `buffers: []const ?gl.Buffer` → `opengl.Buffer#bindBase`, medium | wrong callee/confidence | optional capture inside a for capture not typed (open defect zig/05). The same shape on line 106 (`sampler.sampler.bind`) is typed. |
| opengl/RenderPass.zig:72 | `.target => \|t\| t.framebuffer.bind(.framebuffer) catch return,` | RenderPass.step → `framebuffer.bind`, low | union payload `target: Target`, field `framebuffer: gl.Framebuffer` → `opengl.Framebuffer#bind`, medium | wrong callee/confidence | switch-prong capture not typed (decision A pattern binding) |
| message.zig:103 | `v.impl.deinit();` | message.Message#deinit → `impl.deinit`, low | `.change_config => \|v\|` with `impl: *renderer.Renderer.DerivedConfig` → `renderer.Renderer.DerivedConfig#deinit`, medium | wrong callee/confidence | switch capture on `self.*` (Message, in scan) not typed |
| message.zig:104 | `v.alloc.destroy(v.impl);` | → `alloc.destroy`, low | `alloc: Allocator` → `std.mem.Allocator#destroy`, medium | wrong callee/confidence | same |
| message.zig:105 | `v.alloc.destroy(v.thread);` | → `alloc.destroy`, low | `std.mem.Allocator#destroy`, medium | wrong callee/confidence | same |
| metal/IOSurfaceLayer.zig:25 | `const layer = (try getSubclass()).msgSend(` | IOSurfaceLayer.init → `.msgSend`, low | `fn getSubclass() error{ObjCFailed}!objc.Class` → `objc.Class#msgSend`, medium | wrong callee/confidence | in-place call result of an in-scan fn not typed. `self.rgb().asPixel()` is typed. |
| size.zig:131 | `const term = (Coordinate{ .surface = surface }).convert(` | size.Coordinate#convert → `.convert`, low | literal of type Coordinate → `size.Coordinate#convert`, high | wrong callee/confidence | struct-literal receiver not typed (Typed call results ruling: literal) |
| metal/IOSurfaceLayer.zig:162 | `if (display_cb) \|cb\| cb(` | IOSurfaceLayer.getSubclass → `cb`, low, direct | `DisplayCallback = ?*align(8) const fn (...)` → `cb`, callback, unknown | wrong call_type/confidence | call through a function-pointer value classified as a direct call (C3) |
| shadertoy.zig:332 | `try optionsFn(options);` | shadertoy.spvCross → `optionsFn`, low, direct | param `optionsFn_: ?*const fn (...)` captured → `optionsFn`, callback, unknown | wrong call_type/confidence | same |
| image.zig:139 | `var buf = GraphicsAPI.Buffer(GraphicsAPI.shaders.Image).initFill(` | image.State#draw → `.initFill`, low | static call on an instantiated generic type (`renderer.Renderer.API.Buffer#initFill`, medium) | wrong callee/confidence | open defect zig/12 |
| generic.zig:1341 | `state.terminal.scrollViewport(.bottom);` | generic.updateFrame → `terminal.scrollViewport`, medium, direct | receiver is the field `state.terminal` (state from an external type): `terminal.scrollViewport`, low, method | wrong confidence/call_type | a struct field named like the file's `const terminal = @import(...)` binding was read as the module |
| generic.zig:352 (sample #32) | `const CellTextBuffer = Buffer(shaderpkg.CellText);` | generic.Renderer → `GraphicsAPI.Buffer`, low, method | — | spec gap | zig/18 type-function call |
| Thread.zig:500 (sample #47) | `t.drainMailbox() catch \|err\|` (`const t = self_.?;`) | Thread.wakeupCallback → `t.drainMailbox`, low | — | spec gap | zig/16 inferred binding |
| metal/Frame.zig:90 (sample #48) | `block.renderer.frameCompleted(health);` | → `renderer.frameCompleted`, low | — | spec gap | zig/18 receiver typed `*Renderer` = `generic.Renderer(Metal)` |

## Systematic patterns (scripted: `s-renderer_r17_census.py`), by count
1. **Typed receiver left as a low guess: 10.** These are captures (for, optional and switch-prong), indexes of typed params, struct literals and in-place results of in-scan calls. Candidates came from `s-renderer_r17_capture.py`, `_capture2.py`, `_selffield.py` and the `.m` listing. I checked each one by hand against its declaration. The other candidates resolve to out-of-scan types, generic `GraphicsAPI` members, or zig/16 bindings, so leaving them low is correct. The tool handles the same constructs inconsistently: `if (s_) |sampler| sampler.sampler.bind` and `if (s.uniforms) |ubo|` are typed; `if (b) |buf|` after `s.buffers[1..]` is not.
2. **Call through a function pointer emitted as low/direct instead of callback/unknown: 2.** Script: low direct edges with a bare callee. These are all such edges, and both sources are fn-pointer values.
3. **Field read as a module binding: 1.** Script: medium/direct callee written after another receiver segment. 10 candidates, 9 are real module paths (`gl.glad.load`, `internal_os.macos.*`, `terminal.kitty.graphics.*`). Only `state.terminal.scrollViewport` is wrong.
4. **Open defect zig/12 (static call on an instantiated generic type is `.m`): 1.** Script: `.m` callee preceded by `Capitalized(...)`. A word-boundary fix removed one false hit (`renderData().bytes()`).

Union: 14 wrong of 1512, census precision 99.07%.

## Missed-call patterns (recall)
- Recall functions:
  - `cell.constraintWidth`: 8 calls, 8 edges.
  - `Thread.Compression#wake`: 6 calls, 6 edges.
  - `opengl/RenderPass.step`: 21 calls, 21 edges, 2 of them with wrong callees (lines 72 and 120, above).
  - Total: 0 missed and 0 non-calls of 35.
- Repo-wide (`s-renderer_r17_recallpat.py`, approximate):
  - **Calls in `test` blocks inside in-scope files: ~515 call sites, 0 edges.** Six files (shadertoy, link, size, image, State, cell), plus cursor.zig, whose 4 tests also have none. The scope rule excludes only test paths, not test blocks.
  - **File-level const initializer calls: ~32 with no edge** (`const log = std.log.scoped(.metal)` ×24, `rendererpkg.GenericRenderer(Metal)`, `BlockingQueue(...)`, `std.ArrayListUnmanaged(...)`, `objc.Block(...)`). This is open defect zig/10.
  - **Decl-literal calls: ~15 with no edge** (`fg_rows[0] = try .initCapacity(alloc, 1)`, `return .fromTerminal(...)`, `result.compression = try .init()`, `self.autorelease_pool = .init()`, and field defaults `= .init(0)`). This is open defect zig/11. A typed `var ctx: z2d.Context = .init(...)` does get its edge.

## Spec gaps (counted separately; 872 edges in their union, none overlapping the wrong set)
- **zig/18: in-scan generic type function (519 caller IDs, 6 type-function calls, 4 receivers).** Construct: `pub fn Renderer(comptime GraphicsAPI: type) type { return struct { ... pub fn drawFrame(...) ... } }` in generic.zig, and `pub fn Buffer(comptime T: type) type { return struct { pub fn init ... } }` in opengl/ and metal/buffer.zig. The tool names these members `generic.drawFrame` and `buffer.init`. That is neither of the forms the question lists (`generic.Renderer#drawFrame`, or folded into `generic.Renderer`). Also: is `const CellTextBuffer = Buffer(shaderpkg.CellText);` an edge (6 edges)? And what is the callee for a receiver typed `*Renderer` with `const Renderer = @import("../generic.zig").Renderer(OpenGL)` (4 low edges)? SPEC leaves the member ID and the edge status open.
- **zig/17: file qualifier below a subdirectory (378 edges).** The tool uses basenames, so `metal/Pipeline.zig` and `opengl/Pipeline.zig` both define `Pipeline.deinit`, and both `RenderPass.step`, `Texture.init`, `shaders.Shaders#init`, `Frame.begin`, `buffer.init` and so on collide. Question: basename, dotted path, or path? A related reading (61 edges): out-of-scan relative imports are named by basename, so `@import("../font/main.zig")` and `@import("../terminal/main.zig")` both become `main.` (`main.ShaperCache#init`, `main.Style#bg`). SPEC does not say how a relative import of an unscanned file is named.
- **zig/16: unannotated local typed by its initializer (7 edges).**
  - Edges: `const p = self.getPendingPointer().?; p.prepForUpload(...)`, `const library = try initLibrary(device); library.msgSend(...)`, `const t = self_.?; t.drawFrame(true)`, and the captures `if (frame.custom_shader_state) |*state| state.deinit()` where `const frame = swap_chain.nextFrame();`.
  - Open question: does such a binding take its type? The 2026-11-12 let-bound bullet ("and the like") could cover Zig, but CAPABILITIES, regenerated after 2026-11-13, still lists zig/16 as undecided.
  - The tool is internally inconsistent here. It types `const device = try chooseDevice();` (`objc.Object#msgSend`, medium) and `frame.custom_shader_state.?.resize` (high). It does not type `const library = try initLibrary(device);` (same return shape, `!objc.Object`) or the `|*state|` capture of that same field.
- **Inline `@import` receiver (1 edge).** `@import("objc").AutoreleasePool.init()` gives `.init`, low. The Zig note covers `@import` *bindings*, not an inline `@import(...)` expression used as a receiver.

## Files
- Report: `<fanout>/s-renderer_report.v17.md`
- Scripts:
  - `<fanout>/s-renderer_r17_sample.py`
  - `<fanout>/s-renderer_r17_load.py`
  - `<fanout>/s-renderer_r17_census.py`
  - `<fanout>/s-renderer_r17_capture.py`
  - `<fanout>/s-renderer_r17_capture2.py`
  - `<fanout>/s-renderer_r17_selffield.py`
  - `<fanout>/s-renderer_r17_letbound.py`
  - `<fanout>/s-renderer_r17_fieldmod.py`
  - `<fanout>/s-renderer_r17_line.py`
  - `<fanout>/s-renderer_r17_c2.py`
  - `<fanout>/s-renderer_r17_recallpat.py`
