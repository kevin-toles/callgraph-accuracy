# lite-xl call-graph review v3 (Lua)

**Summary:** precision 50/50; census ≈99.8% (10 wrong of 4824 in-scope); recall: 0 missed of 31 real calls; 0 non-calls

**Scope.** There are 4,824 in-scope `.lua` edges out of 7,599 total. Of these, 4,585 are under data/ and 239 under scripts/keymap-generator. The excluded edges are the C files in src/ and the files in resources/. By confidence the in-scope edges are high 2484, low 1135, medium 966 and unknown 239. By call type they are method 2759, direct 1826 and callback 239. No edge has an empty caller.

These counts are identical to the v2 run's, so the tool output is effectively unchanged.

**Sample.** The sample uses seed `20261028` and is stratified as 24 high, 11 low, 10 medium and 5 unknown edges, spread over 28 files. The script is `lite-xl_v3_sample.py`. All 50 edges are correct on caller, callee, confidence and line, with one exception: #47, which is a spec gap and not counted as wrong.

- **High tier.** The sampled edges include:
  - local functions (`plugins.treeview.replace_alpha`, the recursive `plugins.workspace.load_node`, `dkjson.addnewline2`);
  - `require` bindings (`core.doc.translate#start_of_word`, `core.common#color` from module-level code in colors/default.lua);
  - superclass resolution (`View:extend()` → `core.object#extend`);
  - an anonymous callback inside `change_project_directory` folded into that local function (`core#confirm_close_docs`, commands/core.lua:131);
  - monkey-patch callers (`core.docview#get_line_screen_position` in linewrapping.lua);
  - 7 `require "…"` edges with callee `require`, high. This is correct because data/core/start.lua:75 defines a global `function require(modname, ...)`.
- **Medium tier.** All 10 are `_G#`, `table#`, `math#`, `string#` and `coroutine#` calls, with correct folding. For example, the `__pairs = function()` literal in config.lua:311 folds to `core.config`, and the `get_value = function` literal in lineguide.lua:48 folds to `plugins.lineguide`.
- **Low tier.** The sampled edges are `doc.position_offset`, `highlighter.each_token`, `doc.reload`, `doc.get_char`, `.insert`, `command_view.enter` (×3), `.sub`, `.match` and `root_node.get_child_overlapping_point`. Each one follows the last-segment or computed-receiver rule.
- **Unknown tier.** The sampled edges are `strsub` (dkjson `local … strsub … = string.sub`), `update` (`local update = RootView.update`), `refresh` (`local refresh = coroutine.wrap(…)`), `on_event` (`local on_event = core.on_event`) and #47 `Node` (spec gap, see below).

**Recall** (`lite-xl_v3_recall.py`):
- `core.node#split` (data/core/node.lua:95-116) makes 11 calls, and all 11 were found. They include the three `Node()` calls, `child:consume`, `self:consume` → `core.node#consume`, `self.b:add_view` → `b.add_view` and `core.set_active_view`.
- `plugins.workspace.save_workspace` (data/plugins/workspace.lua:174-186) makes 8 calls, and all 8 were found. They include both `core.root_project()` calls on :175 and :185, and `storage.save` → `core.storage#save`.
- `core.common#normalize_path` (data/core/common.lua:557-594) makes 12 calls, and all 12 were found. They include `filename:gsub` / `:match` ×3, `drive:upper`, the local `split_on_slash`, and both `table.insert` calls.

Every line number was correct.

**Census checks over all in-scope edges** (`lite-xl_v3_census.py`, `lite-xl_v3_census2.py`, `lite-xl_v3_wrong.py`):
- No high callee is missing from the node list.
- Every edge's callee name appears on its own source line (0 line mismatches).
- `unknown` and `callback` coincide exactly.
- All 11 builtin-named unknown callees (`floor`, `type`, `pairs`, `require` and so on) are in dkjson.lua, which rebinds them as locals at :47 and similar lines. That is correct per the callback rule.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| data/core/process.lua:192-196 (7 edges) | `options.env = function(system_env)` (:190) … `for k, v in pairs(system_env) do final_env[env_key(k)] = k.."="..v end` | `options#env` → `_G#pairs` ×3, `core.process.env_key` ×2, `table#sort`, `table#concat` | caller `process#start`. The anonymous function is assigned to a field of the parameter `options`, so it folds into the enclosing named function. | wrong caller | function assigned to a parameter's field is named as if `options` were a table |
| data/core/node.lua:515, :516 | `self:move_towards("tab_shift", tab_width * (self.tab_offset - 1), nil, "tabs")` | `core.node#update` → `core.node#move_towards`, medium, method | `Node` defines no `move_towards`. It is a stored property (`self.move_towards = View.move_towards`, :27), so the callee is `move_towards`, callback, unknown. | wrong callee + wrong confidence | stored-property function treated as a method on the class |
| data/plugins/autocomplete.lua:300 | `autocomplete.on_close(doc, suggestions[suggestions_idx])` | `plugins.autocomplete.reset_suggestions` → `plugins.autocomplete#on_close`, medium, direct | `on_close` is a stored property (`autocomplete.on_close = nil`, :135, guarded by `if autocomplete.on_close then`), so the callee is `on_close`, callback, unknown. | wrong confidence / call_type | stored-property function treated as a module function |
| data/core/node.lua:99 (sample #47) | `local child = Node()` | `core.node#split` → `Node`, unknown, callback | Lua has no constructor rule. `Node = Object:extend()` is a class called through `__call`; it could be `core.node#<init>` / `Object#__call`. | spec gap | class instantiation via `__call` |
| data/core/statusview.lua:419 (+738, 744, 763) | `local item = StatusView.Item(options)` | `→ core.statusview#Item`, medium, direct | `StatusView.Item = StatusViewItem` (:160) is a class called through `__call`; this is the same gap as the row above. | spec gap | class instantiation via `__call` |
| data/core/rootview.lua:637 | `t.fn(table.unpack(t))` | `core.rootview#draw → t.fn`, low, direct | The spec does not say whether the unknown-receiver rule (`t.fn`, low) or the stored-property rule (`fn`, callback, unknown) applies. | spec gap | function held in a field of an unknown-typed table |
| data/core/process.lua:41 | `function process.stream:read(bytes, options)` | caller `process.stream#read` | `process` is a global C table that this file extends and returns (`return process`). The spec says `core.process#…` (returned table) but also `T#fn` (global table). | spec gap | module table that is also a global |
| data/plugins/linewrapping.lua:561 | `function DocView.translate.previous_line(doc, line, col, dv)` | caller `core.docview.translate#previous_line` | Lua naming for a function on a nested table of the module's class is not specified. | spec gap | nested table on module table |
| scripts/keymap-generator/keymap-generator.lua:2 | `local dkjson = require "dkjson"` | `keymap-generator → require`, high | This is a `#!/usr/bin/env lua` standalone script, so stock `require` (`_G#require`, medium) runs, not the start.lua override. The spec does not cover a scanned global that redefines a builtin for a different program. | spec gap | global redefinition of a builtin |

## Systematic patterns

All 10 wrong edges below were counted by `lite-xl_v3_wrong.py`.

1. **An anonymous function assigned to a field of a parameter gets its own `T#field` caller: 7 edges.** These are all `options#env` in process.lua:192-196. No other caller prefix shows this, out of all callers whose prefix differs from their file's module (the rest are legitimate monkey-patches, global tables or dkjson locals).
2. **Stored-property functions on `self` or a module table are treated as named methods: 3 edges.** These are `core.node#move_towards` ×2 and `plugins.autocomplete#on_close` ×1. They are the only medium edges with a non-stdlib callee that is neither defined nor named on the module table (the other 5 non-stdlib medium edges are the 4 `StatusView.Item` spec-gap edges and `core#open_folder_project`, which is correct).

Census precision = 1 − 10/4824 ≈ 99.79%.

## Spec gaps (counted separately, not wrong)

| gap | in-scope edges |
|---|---|
| C API tables (`system#…`, `renderer#…`) resolve to stub definitions in docs/api/*.lua and are high. docs/ is excluded from judging, but the stubs are in the scan. | 210 |
| Global C table `process` / `process.stream` / `regex` extended and returned by a module: callers are `process#…`, `process.stream#…` and `regex#…`, not `core.process#…` | 71 (33 + 26 + 12) |
| Lua class instantiation via `__call` (`Node()`, `DocView(doc)`, `StatusView.Item(...)` and so on): 26 are unknown/callback and 4 are `core.statusview#Item` medium | 30 |
| Field-held function called with a dot on an unknown receiver (`t.fn(...)`, `cmd.perform(...)`, `item.on_draw(...)`): low/direct | 23 |
| Function on a nested table of the module class (`core.docview.translate#…`) | 8 |
| Standalone Lua script's `require` resolved to the start.lua global override, high | 3 |

## Previous findings

The v2 previous report covered 6 mismatch-table rows, a note on C API stubs, 2 systematic patterns and 5 carried-over findings from v1.

**Mismatch-table rows:**
1. **`options#env` wrong caller (process.lua:192-196): still present, 7 edges (v2: 7).** The current spec rule that a parameter's field is not a named table makes this wrong, as before.
2. **`core.node#move_towards` medium/method (node.lua:515, :516): still present, 2 edges (v2: 2).**
3. **`plugins.autocomplete#on_close` medium/direct (autocomplete.lua:300): still present, 1 edge (v2: 1).**
4. **`process#…` caller spec gap: still present.** There are 33 `process#` edges (v2: 33), plus 26 `process.stream#` and 12 `regex#` edges of the same kind. It is still a gap, because the updated spec's Lua note is unchanged on this point.
5. **`StatusView.Item` spec gap: still present, 4 edges.** It belongs to the broader class-via-`__call` gap (30 edges), which none of the new spec rules covers. The new superclass-constructor rule is about `super(...)`, not Lua `__call`.
6. **`t.fn` spec gap (rootview.lua:637): still present.** The broader pattern counts 23 low/direct edges.
7. **Note on C API stubs (`system#` / `renderer#` high): unchanged, 210 edges (v2: 210).**

**Systematic patterns:**
1. **Stored-property functions treated as named methods: still present, 3 edges (v2: 3).**
2. **Anonymous function on a parameter field gets a `T#field` caller: still present, 7 edges (v2: 7).**

**Carried-over v1 findings, as of v2:**
- Inheritance resolution: still fixed. All high callees resolve to defined nodes, and only 8 medium edges are not stdlib.
- Cross-file `require` resolution: still fixed. In the sample, `core.doc.translate#…`, `core.common#…` and `core.storage#save` are all high.
- Stdlib at medium: still fixed. All sampled stdlib edges are medium.
- No empty callers: still fixed (0).
- Callback/unknown for locals: still partly fixed. Locals are correct (239 unknown, all callback), but the 3 property-held functions in pattern 1 above remain unmarked.

None of the new spec rules (typed receivers, nested lambdas as named functions, file-level callers, anonymous interface instantiation, enum constants, superclass constructors) changes any verdict for this Lua repo:
- Nested `local function` is already `outer.f` (for example `core.tokenizer#tokenize.find_text`).
- File-level code already uses the module ID (for example `colors.default`, `plugins.lineguide`).
- The other rules do not apply to Lua.
