# s-mesa-drm (C): blind call-graph review, round 7

precision 50/50; census ≈99.84% (8 wrong of 4942 in-scope); recall: 0 missed of 27 real calls; 0 non-calls

(Of the 50 sample edges, 34 are confirmed correct and 16 fall in spec gaps: 11 libc calls, 5 X-macro `CHIPSET` rows. None is wrong. Spec-gap edges are counted separately below and are not in the census numerator.)

## Scope
Tool output `<scans>/final20-A/s-mesa-drm.v2.json` has 8111 edges: 7547 from `.c` files, 510 from `.h` files and 54 from `.py` files. The `.py` edges are out of scope (other language). Excluding every `.c`/`.h` edge under a `tests/` path segment (3169 edges) leaves **4942 in-scope edges over 59 files**. Confidence: high 3478, low 1315, medium 75, unknown 74. call_type: direct 3509, macro 1359, callback 74. By pair: high/direct 2194, high/macro 1284, low/direct 1315, medium/macro 75, unknown/callback 74. There are no `method` or `constructor` edges, as expected for C. The `measured_accuracy` field was ignored.

Method: precision sample seed `20261114`, stratified high 29 / low 11 / medium 5 / unknown 5, 21 files. Census scripts: a comment/string-aware C scanner indexes function definitions (with body spans) and `#define`s over the whole scanned tree (178 `.c`/`.h` files, 1380 function bodies). The scanner checks every in-scope edge for these things:
- the enclosing function or file-module caller
- the callee name on the line, in call syntax
- the tier against scanned definitions: low → scanned function or macro, high direct → no scanned function, high macro → no scanned `#define`, medium macro → scanned `#define`
- call_type against definition kind
- calls through `(*name)` pointers emitted as direct
- the same-name edge count per line against call-site count
- high edges to `static` functions of other translation units
- candidate call sites in function bodies that have no edge

Helper scripts are `s-mesa-drm_r7_*.py` in the fanout folder.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| intel/intel_bufmgr_gem.c:1158 | `if (bo_gem->mem_virtual) {` (call is on 1159: `VG(VALGRIND_FREELIKE_BLOCK(bo_gem->mem_virtual, 0));`) | drm_intel_gem_bo_free → VG, high, macro | same edge on line 1159 | wrong line | `VG(...)` statement reported on the line of the enclosing block's `{` |
| intel/intel_bufmgr_gem.c:1163 | `if (bo_gem->wc_virtual) {` (call on 1164: `VG(VALGRIND_FREELIKE_BLOCK(bo_gem->wc_virtual, 0));`) | drm_intel_gem_bo_free → VG, high, macro | line 1164 | wrong line | same |
| intel/intel_bufmgr_gem.c:1405 | `{` (function body open; call on 1471: `VG(VALGRIND_MAKE_MEM_DEFINED(bo_gem->mem_virtual, bo->size));`) | drm_intel_gem_bo_map → VG, high, macro | line 1471 | wrong line | same |
| intel/intel_bufmgr_gem.c:1422 | `if (!bo_gem->mem_virtual) {` (call on 1444: `VG(VALGRIND_MALLOCLIKE_BLOCK(mmap_arg.addr_ptr, mmap_arg.size, 0, 1));`) | drm_intel_gem_bo_map → VG, high, macro | line 1444 | wrong line | same |
| intel/intel_bufmgr_gem.c:1542 | `{` (call on 1579: `VG(VALGRIND_MAKE_MEM_DEFINED(bo_gem->gtt_virtual, bo->size));`) | drm_intel_gem_bo_map_gtt → VG, high, macro | line 1579 | wrong line | same |
| intel/intel_bufmgr_gem.c:1621 | `if (ret == 0) {` (call on 1623: `VG(VALGRIND_MAKE_MEM_DEFINED(bo_gem->gtt_virtual, bo->size));`) | drm_intel_gem_bo_map_unsynchronized → VG, high, macro | line 1623 | wrong line | same |
| intel/intel_bufmgr_gem.c:3476 | `} else {` (call on 3477: `VG(VALGRIND_MALLOCLIKE_BLOCK(mmap_arg.addr_ptr, mmap_arg.size, 0, 1));`) | drm_intel_gem_bo_map__cpu → VG, high, macro | line 3477 | wrong line | same |
| intel/intel_bufmgr_gem.c:3519 | `} else {` (call on 3520: same text) | drm_intel_gem_bo_map__wc → VG, high, macro | line 3520 | wrong line | same |
| radeon/r600_pci_ids.h:344 (sample #3; also #5 :38, #6 :132, #9 :96, #25 :286) | `CHIPSET(0x6801, PITCAIRN_6801, PITCAIRN)` | radeon/r600_pci_ids → CHIPSET, high, macro | undecided (CAPABILITIES c/12-gap-xmacro) | spec gap | X-macro fragment `#include`d inside `radeon_get_family`'s switch (radeon_surface.c:140-142) |
| intel/intel_bufmgr_gem.c:2602 (sample #30; also #31-#33, #35-#40) | `bo_gem = calloc(1, sizeof(*bo_gem));` | drm_intel_bo_gem_create_from_prime → calloc, low, direct | undecided (CAPABILITIES c/13-libc-calls) | spec gap | libc function declared only in a system header outside the scan |
| xf86drm.c:3340 (sample #34) | `if (!drmNodeIsDRM(maj, min) \|\| !S_ISCHR(sbuf.st_mode)) {` | drmGetNodeTypeFromFd → S_ISCHR, low, direct | undecided (c/13: system-header function-like macro: macro/medium or direct?) | spec gap | `S_ISCHR` is a `<sys/stat.h>` macro, not in the scan |

All other sample edges were verified correct: 24 high/direct to scanned functions, including `static inline` header helpers `DRM_IOCTL`, `nouveau_bo` and `cli_kref_get`, plus a recursive call on the callee-name line of a multi-line call. Also correct: 5 high/macro to scanned `#define`s (`U642VOID`, `MAX2`, `RADEON_SURF_CLR`, and others), 5 medium/macro (`assert`, `va_start`) and 5 unknown/callback through struct fields (`bo->bufmgr->bo_exec(...)`, `csi->csm->funcs->cs_emit(csi)`).

## Systematic patterns (wrong), by scripted count
1. **Statement-level macro invocation `VG(...)` reported on the enclosing block's opening line (wrong line, C7): 8 edges.** The script compared each edge's line with the nearest `VG(` site. All 8 in-scope `VG` edges are off, by 1 to 66 lines. All 8 real `VG(` call sites in the file have no edge on their own line. The calls inside the argument (`VALGRIND_*`) are on the correct lines. Hand-checked: 1158/1159, 1405/1471, 1422/1444, 3476/3477. Callers are correct.

No other wrong pattern was found:
- Caller check: 0 mismatches. The 8 script hits in `libsync.h` and `xf86drmMode.h` came from my scanner's handling of `extern "C" {` and were hand-confirmed correct.
- Low edges whose callee is a scanned function or `#define`: 0.
- High-direct edges to non-functions: 0. The 2 script hits were in-header functions inside `extern "C"`, hand-confirmed.
- High-macro edges without a `#define`: 0.
- Medium-macro edges with a scanned `#define`: 0.
- Direct edges through `(*name)` function pointers: 0.
- Duplicate edges per call site: 0. The only extra was `(*cs->space_flush_fn)(...)`, a correct callback that my regex missed.
- High edges to other files' `static` functions: 0.

## Missed-call patterns (recall)
- Recall functions:
  - `parse_one_line` (amdgpu/amdgpu_asic_id.c:42-110): 11 calls, all present.
  - `radeon_cs_check_space_internal` (radeon/radeon_cs_space.c:189-207): 2 calls, including callback `(*cs->space_flush_fn)(...)`, all present.
  - `drm_intel_gem_bo_free` (intel/intel_bufmgr_gem.c:1151-1184): 14 calls (`DRMLISTDEL`, `VG`×2, `VALGRIND_FREELIKE_BLOCK`×2, `drm_munmap`×3, `HASH_DELETE`×2, `drmCloseBufferHandle`, `DBG`, `strerror`, `free`), all present. The two `VG` edges are on the wrong line, counted under pattern 1.
- Total: 0 missed of 27, 0 non-calls.
- Whole-scope candidate scan of call sites in function bodies without a matching edge: only the 8 `VG` sites (their edges sit on other lines, pattern 1) and calls written inside multi-line `#define` bodies (intel/intel_decode.c:2353/2355, not call sites). There are no other missed calls.

## Spec gaps (counted separately, not wrong): 1805 edges
1. **libc / external-library calls with no declaration in the scan: 1315 edges, all low/direct.** That is every low edge. The top callees are `fprintf` 201, `free` 176, `calloc` 100, `pthread_mutex_unlock` 94 and `pthread_mutex_lock` 66. The set includes 56 edges to system or external function-like macros or builtins (`major` 11, `minor` 11, `VALGRIND_*` 11, `S_ISCHR` 8, `alloca` 7, `makedev` 4, `__builtin_clz*`/`__builtin_ctz` 3, `_BitScanReverse64` 1). It also includes 12 edges to non-libc libraries (`devname_r`, `sysctlbyname`, `pci_*`, `native_handle_create`). No scanned header has a prototype for any of them; the only matches were in comments. Construct: `bo_gem = calloc(1, sizeof(*bo_gem));`, `!S_ISCHR(sbuf.st_mode)`. Open question (CAPABILITIES c/13-libc-calls): is a call to a function declared only in a system header outside the scan medium or low, does its ID take a qualifier, and is a system-header function-like macro `macro` (medium) or `direct`? By contrast, `assert`/`va_start`/`va_end` are emitted as medium/macro (75 edges). I judged those correct under "function-like macros → macro (high if #defined in the scan)".
2. **X-macro fragment included inside a function: 454 edges.** Every `CHIPSET(...)` line of radeon/r600_pci_ids.h gets caller `radeon/r600_pci_ids`, high/macro. Construct: radeon_surface.c:140-142 `#define CHIPSET(pci_id, name, fam) case pci_id: ...` / `#include "r600_pci_ids.h"` inside `radeon_get_family`'s `switch`. Open question (CAPABILITIES c/12-gap-xmacro): is the caller the inclusion site (`radeon_get_family`) or the fragment file's module ID? Which file and line do the edges get? Are the invocations macro edges to `CHIPSET`?
3. **Macro invocation in a C enum-constant initializer: 21 edges.** In intel/intel_aub.h:105-125, `AUB_TRACE_VS_STATE = ENCODE_SS_TYPE(AUB_TRACE_TYPE_GENERAL, 1),` inside `enum aub_state_struct_type { ... }` gets caller `intel/intel_aub`, high/macro. Open question: SPEC assigns file-level code to the file module "outside any function or type" and field initializers to `Type#field`. It does not say whether a C enum constant's initializer is file-level code or a member initializer of the enum type.
4. **libc name that a scanned test defines as an interposer: 15 edges.** `ioctl` is emitted high/direct from libsync.h, xf86drm.c, intel/intel_bufmgr_gem.c, tegra/channel.c, tegra/job.c and tegra/syncpt.c, for example `ret = ioctl(fd1, SYNC_IOC_MERGE, &data);`. It matches `int ioctl(int fd, unsigned long request, ...)` in tests/nouveau/threaded.c:40, an LD-style override that forwards through `dlsym(RTLD_NEXT, "ioctl")` and is linked only into that test program. Open question: with bare C IDs, does a scanned definition in a different program (link unit) make a library call to the same name "defined in the scan" (high), or does it remain the external libc call (c/13)?
