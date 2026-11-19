# Blind call-graph review: s-lua (Neovim runtime/lua), round 8

precision 50/50; census ≈99.89% (14 wrong of 13025 in-scope); recall: 0 missed of 71 real calls; 0 non-calls

## Scope
Source root `.../neovim/runtime/lua`, which holds 158 `.lua` files. The tool output has 13025 edges, all from Lua files. No path has a test/, tests/, spec/, examples/ or docs/ segment, so all **13025 edges are in scope**, spread over 157 files.
- By confidence: high 7236, medium 3422, low 2163, unknown 204.
- By call_type: direct 10714, method 2107, callback 204.
- Split: high/direct 6984, high/method 252, medium/direct 3422, low/method 1855, low/direct 308, unknown/callback 204.

I ignored `measured_accuracy`. Contract checks on the whole graph:
- Every high callee is in `nodes` (C1).
- No caller or callee is empty (C7).
- Every caller is a node.
- Every non-alias callee's member name appears on the edge's line. The 285 exceptions are all Lua alias calls, for example `getlines` → `vim.filetype#_getlines` and `N_` → `vim.fn#gettext`, which are correct under Decisions 2026-10-29.

## Method
- **Precision:** 50 edges drawn with `random.seed(20261113)` (high 26, medium 12, low 7, unknown 5), across 40 files (`s-lua_r8_sample.py`).
- **Recall:** three functions in three files:
  - `vim.lsp.util#preview_location`: 5 calls
  - `vim.fs#find`, including its nested `add`/`test`: 36 calls
  - `vim.treesitter.highlighter#new`, including the nested `set_conceal_lines`: 30 calls
- **Census:** scripted in `s-lua_r8_census.py`. The other helper scripts are `s-lua_r8_load.py`, `_ctx.py`, `_req.py`, `_recall.py`, `_chk1.py`, `_chk2.py`, `_self.py`, `_alias.py`, `_shadow.py`, `_recv.py` and `_unres.py`.

## Precision sample
I found no wrong edges among the 50. Every sampled caller, callee, tier, call_type and line matched the spec. Some sample items touch spec gaps (listed below), and those are not counted as wrong:
- **G3 (module IDs of files nothing requires):** 20 items: 1, 2, 3, 7, 12, 13, 14, 15, 18, 22, 23, 26, 29, 35, 36, 37, 38, 44, 48, 50.
- **G2 (the global `vim` table is also the file's returned table):** 7 items: 1, 4, 7, 11, 12, 16, 17.
- **G1 (callable or aliased `vim.*` field):** 2 items: 31 (`vim#uri_from_bufnr`) and 35 (`vim#cmd`).

Checks on the edge kinds the sample covered:
- **Aliases:**
  - `local P = lpeg.P` with `local lpeg = vim.lpeg` → `vim.lpeg#P` high.
  - `local nvim_on = require('vim._core.util').nvim_on` → `vim._core.util#nvim_on` high.
  - `getlines = vim.filetype._getlines` → `vim.filetype#_getlines` high.
- **Named nested functions:** `check_tmux.get_tmux_option` and the forward-declared `local load` / `test = function` all resolve.
- **Method calls:** `self:_run_callbacks` → `vim.lsp.client#_run_callbacks`, method, high.
- **External `require "lpeg"`:** `m.C` → `lpeg#C` medium.
- **Low guesses:** `('…'):format` → `.format` low (a literal receiver); `path:find` → `path.find`; `self.tree:parse` → `tree.parse`.
- **Callbacks through parameters or locals:** `on_confirm`, `f`, `names`, `notify_reply_callback`, and `text`, which is bound to `vim.func._memoize(...)`, are all callback/unknown.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| vim/re.lua:20 | `local mt = getmetatable(mm.P(0))` | vim.re → `mm.P`, low, direct | `lpeg#P`, medium, direct (`local mm = m`, `local m = require"lpeg"`) | wrong callee / wrong confidence | a local alias of a require-bound table is not followed. `m.P` in the same file resolves to `lpeg#P` (C1/C2) |
| vim/re.lua:42 | `mm.locale(Predef)` | vim.re.updatelocale → `mm.locale`, low, direct | `lpeg#locale`, medium | wrong callee / wrong confidence | same |
| vim/re.lua:204 | `function (n, p) return mm.Cg(p, n) end` | vim.re → `mm.Cg`, low, direct | `lpeg#Cg`, medium | wrong callee / wrong confidence | same |
| coxpcall.lua:113 | `return coxpcall(f, id, ...)` | _G#copcall → `coxpcall`, low, direct | `_G#coxpcall`, high, direct (defined at line 71 as `function _G.coxpcall(f, err, ...)`) | wrong callee / wrong confidence | a bare call of a global defined through `_G.f` is not matched to its definition |

## Systematic patterns (scripted counts)
1. **A local alias of a require-bound module table is not followed: 13 edges.** All 13 are in vim/re.lua: `mm.P`×3, `mm.V`×2, `mm.Cp`×2, `mm.Cg`, `mm.Cmt`, `mm.Cb`, `mm.Cs`, `mm.locale`, `mm.type`. I checked lines 20, 42 and 204 by hand.
   - Under C1 and the 2026-10-29 alias ruling, these should be `lpeg#X`, medium.
   - The tool does follow table aliases elsewhere, such as `local api = vim.api` (779 edges) and `local m = vim.lpeg` (118 edges).
   - Over the whole graph, the alias scan (`s-lua_r8_alias.py`) found no other alias of a resolvable table left low. `uv = vim.uv` stays low, but consistently: `vim.uv.f()` is also `uv.f` low, and `vim.uv` has no function definitions in the scan.
2. **A bare call of a global function defined as `function _G.f` is not resolved: 1 edge** (coxpcall.lua:113). It is the only bare call of such a global in the scan.

The census is 1 − 14/13025 ≈ 99.89%.

## Missed-call patterns (recall)
None. The tool reported all 71 calls in the three functions, with correct callers, including those in anonymous callbacks folded into the enclosing function. No edge in them was a non-call: `pcall(TSHighlighterQuery.new, lang)` correctly gives only `_G#pcall`.

## Spec gaps (not counted as wrong)
- **G3. Module ID of a file that no require string names (lua/15): 4734 edges.** 75 of the 158 files are never named by a literal `require`, for example `vim.lsp.buf`, `vim.lsp.rpc`, `vim.treesitter.languagetree`, `man`, `nvim.zip`, `vim.health.health` and `vim._core.defaults`.
  - Several are loaded only through `vim._defer_require` or `require('vim.lsp.' .. key)`.
  - The tool uses the path below the root with dots.
  - Open question (CAPABILITIES lua/15): what is the module ID of such a file?
- **G2. A global table that is also the module's returned table: 1645 edges.** vim/_core/shared.lua starts `_G.vim = _G.vim or {}`, defines `function vim.validate(...)`, and ends `return vim`. editor.lua does the same.
  - The tool uses `vim#validate`.
  - SPEC lists both "the module's returned table: `mod#f`" and "a global: `T#f`", and does not say which applies when a table is both.
- **G1. A call of a `vim` field that holds a callable table or an aliased module function: 153 medium edges**, `vim#uri_*`, `vim#cmd`, `vim#iter`, `vim#inspect`, `vim#pos`, `vim#range`, `vim#version`.
  - Examples:
    - `vim.uri_from_bufnr = uri.uri_from_bufnr`, written in the meta file vim/_meta.lua, which errors when loaded.
    - At runtime the function is supplied by the `__index` in `_init_packages.lua`.
    - `vim.cmd = setmetatable({}, { __call = … })`.
    - `vim.pos = require('vim.pos')`, whose module has a `__call` metamethod.
  - SPEC's alias ruling covers only "a local or const alias", and no ruling covers calling a table through `__call`.
  - Open questions: is a global-table field alias followed to its target (`vim.uri#uri_from_bufnr`, high)? What is the callee of a call to a callable table?
- **G5. `self` as a local bound to `setmetatable({}, T)` in a dot-defined constructor: 32 low edges**, for example `local self = setmetatable({}, TSHighlighter)` then `self:on_detach()` → `self.on_detach` low. Others are in `vim.lsp.client#create`, `vim.lsp.rpc.Client#new` and `vim._core.options.create_option_accessor`.
  - Open question: does such a local type its receiver, so the callee is `T#m`, or does it stay a receiver guess?
- **G4. `self.field(...)` in a colon method, where the field is data holding a function rather than a defined method: 8 low/direct edges**, for example `self.on_read(err, nil)` in `MessageStream:feed`, `self._next()` and `self.format_func(...)`.
  - For the similar `self._logger(...)`, the tool gives a callback/unknown edge to `_logger`.
  - Open question: is this a stored-property callback (`on_read`, callback, unknown) or a receiver guess (`self.on_read`, low)?
- **Small cases, not scripted beyond a look:**
  - **Nested module fields.** `function M.msg:start_timer` in vim/_core/ui2/messages.lua gives `vim._core.ui2.messages.msg#start_timer`, and `Ringbuf` is declared inside a `do` block. SPEC does not say what ID a function on a nested module field or a block-local table gets.
  - **A parameter reassigned to a function literal.** In coxpcall.lua, `f = function() … end` gives `_G#coxpcall.f`. SPEC does not say whether that makes `f` a named nested function.
