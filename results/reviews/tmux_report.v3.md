# tmux (C) call-graph review, v3

**precision 50/50; census ≈98.6% (258 wrong of 19,075 in-scope); recall: 0 missed of 76 real calls; 0 non-calls**

Scope: 19,075 edges in `.c`/`.h` files. I excluded `compat/` (640 edges) and `fuzz/` (80 edges), the same scope as v2. The repo has no `regress/` or `tools/` edges. The tier mix is unchanged from v2:

| call_type | confidence | edges |
|---|---|---|
| direct | high | 13,115 |
| direct | low | 3,588 |
| macro | high | 2,272 |
| callback | unknown | 100 |

There are no medium edges.

## Precision sample
I sampled 50 edges with `random.seed(20261028)`, stratified by confidence:
- 36 high (32 direct, 4 macro)
- 9 low
- 5 unknown

They span 35 files. All 50 are correct: each is a real call, and the caller (checked against the enclosing function definition), callee, confidence, call_type and line all match. The sample contains no `<global>`-caller edge. Examples:
- `tty-keys.c:559` tty_keys_free1 → tty_keys_free1 (recursion, high)
- `osdep-dragonfly.c:53` cmp_procs → is_stopped (macro/high, `#define`d in that file)
- `cmd-wait-for.c:496` RB_FOREACH_SAFE (macro/high)
- `server-client.c:2992` → open (low)
- `events-payload.c:559` → evbuffer_new (low)
- `cmd-send-keys.c:100` `wme->mode->key_table(wme)` → key_table (callback/unknown)
- `resize.c:174` → skip_client, called through a function-pointer parameter (callback/unknown)

Script: `tmux_v3_sample.py`.

## Recall (3 functions)
| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| window_copy_cursor_up (window-copy.c:6428) | 30 (incl. screen_hsize ×3, screen_size_y ×3, screen_size_x macros) | 30 | 0 | 0 |
| cmd_capture_pane_history (cmd-capture-pane.c:253) | 39 (incl. `wme->mode->get_screen (wme)` callback, TAILQ_FIRST, 2 calls on line 392) | 39 | 0 | 0 |
| alerts_check_bell (alerts.c:183) | 7 (incl. TAILQ_FOREACH ×2) | 7 | 0 | 0 |

I also ran two whole-repo scans:
- **Every `->x(` / `.x(` call in `.c` files.** 0 have no edge.
- **Every `NAME(` where NAME is a function or function-like macro defined in the scan.** This skipped prototypes and `#define` bodies. The only misses were the file-scope cases in pattern 2 and spec gaps 1–2 below.

Scripts: `tmux_v3_recall3.py`, `tmux_v3_cbrecall.py`, `tmux_v3_recallscan.py`.

## Mismatch table
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| alerts.c:40 | `static TAILQ_HEAD(, window) alerts_list = TAILQ_HEAD_INITIALIZER(alerts_list);` | `<global>` → TAILQ_HEAD_INITIALIZER, high, macro | caller `alerts` | wrong caller | file-scope code still uses `<global>`, not the file path |
| key-string.c:127 | `KEYC_MOUSE_STRING(MOUSEDOWN1, MouseDown1),` | `<global>` → KEYC_MOUSE_STRING, high, macro | caller `key-string` | wrong caller | same |
| options-table.c:1921 | `OPTIONS_TABLE_AFTER_HOOK("bind-key"),` | `<global>` → OPTIONS_TABLE_AFTER_HOOK, high, macro | caller `options-table` | wrong caller | same |
| tmux.h:343 | `KEYC_USER = KEYC_SHIFT_TYPE(KEYC_TYPE_USER),` | `<global>` → KEYC_SHIFT_TYPE, high, macro | caller `tmux` | wrong caller | same (header file scope) |
| utf8.c:47 | `RB_HEAD(utf8_width_cache, utf8_width_item);` | `<global>` → RB_HEAD, high, macro | caller `utf8` | wrong caller | same |
| window-client.c:80 | `WINDOW_CLIENT_FEATURE(256) " "` | no edge | `window-client` → WINDOW_CLIENT_FEATURE, high, macro (`#define`d at window-client.c:51) | missed call | macro call between string literals in a file-scope string-array initializer is not emitted |
| window-tree.c:165 | `WINDOW_TREE_FLAG("active", "pane_active") " "` | no edge | `window-tree` → WINDOW_TREE_FLAG, high, macro (`#define`d at window-tree.c:146) | missed call | same |
| alerts.c:40 | `static TAILQ_HEAD(, window) alerts_list = …` | no TAILQ_HEAD edge | unclear: the spec calls declarations "not calls" but says function-like macros are `macro` | spec gap | type-producing macro in a declaration |
| arguments.c:44 | `RB_ENTRY(args_entry)	 entry;` | no edge | unclear, same reason | spec gap | type-producing macro in a struct member |
| cmd.c:244 | `va_start(ap, fmt);` | cmd_log_argv → va_start, low, direct | function-like macro from `<stdarg.h>`, not `#define`d in the scan. The spec does not say whether an out-of-scan macro is `macro` or `direct`. | spec gap | system header not in the scan |

## Systematic patterns (by census count)
1. **File-scope caller is `<global>`: 258 edges, wrong.** The current spec requires the file path below the scan root without extension (e.g. `options-table`, `key-string`, `tmux`) and names `<global>` as a wrong caller.
   - All 258 are macro/high. They are in 34 files: options-table.c 89, key-string.c 65, tmux.h 29, utf8.c 9, hyperlinks.c 8, monitor.c 6, and others.
   - By callee: KEYC_MOUSE_STRING 65, OPTIONS_TABLE_AFTER_HOOK 38, RB_HEAD 25, RB_GENERATE_STATIC 24, OPTIONS_TABLE_HOOK 24, TAILQ_HEAD 20, OPTIONS_TABLE_PANE_HOOK 19, RB_INITIALIZER 9, OPTIONS_TABLE_WINDOW_HOOK 8, TAILQ_HEAD_INITIALIZER 7, RB_GENERATE 6, RB_PROTOTYPE 6, RB_PROTOTYPE_STATIC 2, LIST_HEAD_INITIALIZER 2, KEYC_SHIFT_TYPE 2, LIST_HEAD 1.
   - This is the only wrong pattern: 258 / 19,075 = 1.35%.
2. **Macro calls inside file-scope string-literal concatenation are missed: 40 calls.** These are missed calls, so they are not in the census numerator.
   - WINDOW_CLIENT_FEATURE: 21 (window-client.c:80–105, in `window_client_info_lines[]`)
   - WINDOW_TREE_FLAG: 19 (window-tree.c:165–217)

   Comparable file-scope table macros not surrounded by string literals, such as KEYC_MOUSE_STRING and OPTIONS_TABLE_*_HOOK, are emitted.

Checks that found 0 wrong edges, over all 19,075 edges (script `tmux_v3_census.py`):
- **Caller matches the enclosing function:** 0 mismatches among the 18,817 non-`<global>` edges.
- **Callee name appears on the reported line:** 0 failures.
- **Confidence matches the definitions in the scan:**
  - Every high callee is a function or macro defined in the scan.
  - No low callee is defined anywhere in the scan, compat/ included (`tmux_v3_lowcheck.py`).
- **Macro call_type matches the `#define`s:**
  - Every `macro` edge names a `#define`d function-like macro.
  - No edge to such a macro has another call_type.
- **Callback edges:** all 100 are callback/unknown. 86 are `->x(`/`.x(` calls and 14 are calls through parameters or locals (`tmux_v3_cb.py`). No direct edge is a member function-pointer call.

## Spec gaps (not counted as wrong)
1. **Type-producing queue/tree macros in declarations** (TAILQ_HEAD, RB_HEAD, TAILQ_ENTRY, RB_ENTRY, LIST_ENTRY, LIST_HEAD). The tool is inconsistent here:
   - It emits 46 file-scope edges when the line starts with the macro: RB_HEAD 25, TAILQ_HEAD 20, LIST_HEAD 1. These are counted in pattern 1 only for their caller.
   - It emits none for struct members (TAILQ_ENTRY 35, RB_ENTRY 30, TAILQ_HEAD 11, RB_HEAD 3, LIST_ENTRY 2) or for `static TAILQ_HEAD(…)` / `static RB_HEAD(…)` declarations (alerts.c:40, cmd-wait-for.c:57, paste.c:35/36).

   The spec says declarations are "not calls" but also that function-like macros are `macro`. It does not decide this case.
2. **`printflike(a, b)` in function heads and prototypes** (38 sites) is not emitted. This is consistent with "declarations/function heads are not calls", but it is a function-like macro.
3. **System macros outside the scan** are emitted as low/direct. The spec does not say whether they should be `macro`. Examples: va_start 35, va_end 35, assert 14, WIFEXITED 9, EVBUFFER_DATA 32, EVBUFFER_LENGTH 64.

## Previous findings
v2 reported no mismatches. Its findings and patterns, re-checked against the current spec:

| previous item | status now | counts |
|---|---|---|
| Mismatch table row: cmd.c:244 `va_start` low/direct (spec gap) | still present, still a spec gap | va_start 35, va_end 35, assert 14, WIFEXITED 9 low/direct |
| Pattern 1: out-of-scan system macros as low/direct (spec gap) | still present, still a spec gap | as above |
| Pattern 2: macro classification matches the scan's `#define`s | still holds | 2,272 macro edges, all macro/high and all `#define`d; 0 defined macros with another call_type |
| Pattern 3: medium tier never used | still present, correct per spec | 0 medium edges. The C rules give no medium case, and no low callee is defined in the scan. |
| Prior fix: `printflike` definitions recognized | still fixed | caller `printflike` 0 edges; args_print_add 6, cmd_log_argv 5, image_log 6, log_vwrite 8, format_log1 7, format_printf 3, input_reply 7, window_customize_write_value 7 |
| Prior fix: `#ifdef` unbalanced braces | still fixed | utf8_add_to_width_cache 24 edges, utf8_towc 5 |
| Prior fix: callback non-calls removed | still fixed | 100 callback edges, all real function-pointer calls; nitems 71, all macro/high |
| v2 "`<global>` now has 258 edges, all file-scope macros", reported as correct | **now wrong under the updated spec** (file-level caller rule): still present, not fixed | 258 edges with caller `<global>`, unchanged count, all macro/high |

Before checking the `<global>` caller under the new file-level rule, I compared the counts with v2. Every tier and per-callee count matches v2 exactly, so the tool's output for tmux appears unchanged. The drop from v2's clean result to 98.6% comes entirely from the spec change.

Helper scripts are in the fanout folder: tmux_v3_load.py, tmux_v3_sample.py, tmux_v3_check.py, tmux_v3_census.py, tmux_v3_global.py, tmux_v3_recallscan.py, tmux_v3_lowcheck.py, tmux_v3_cb.py, tmux_v3_cbrecall.py, tmux_v3_recall3.py, tmux_v3_prev.py.
