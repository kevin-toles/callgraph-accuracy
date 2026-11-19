# Blind call-graph review: s-xv6-riscv (C), round 7

precision 47/50; census ≈99.84% (5 wrong of 3042 in-scope); recall: 1 missed of 59 real calls; 0 non-calls

(Sample: 47 correct, 0 wrong, 3 spec gap (c/13). Seed 6.)

## Scope
The tool output holds 3159 edges. 117 have `source_file` test-xv6.py (Python, not the repo language) and are ignored. No C path has a segment named test/tests/spec/examples/docs, so user/usertests.c, mkfs/ and all of kernel/ and user/ are in scope. **In-scope: 3042 edges** in 48 files (3039 from .c, 3 from kernel/riscv.h).
- Confidence: high 1782, medium 1248, low 9, unknown 3.
- call_type: direct 2908 (high 1686, medium 1213, low 9), macro 131 (high 96, medium 35), callback 3 (unknown). There are no method, constructor or implicit edges.

Scripted whole-graph checks, before the sample. These use comment- and string-stripped source with a brace-depth enclosing-function parser:
- Every in-scope edge sits on a line where `callee_id(` is written: 0 unmatched. None sits on a prototype or definition head.
- Every caller equals the enclosing function at that line: 0 mismatches, and no file-scope edges.
- Every `#define`d function-like macro name in the scan is tagged `macro`. No direct edge names one.
- Every direct edge's tier agrees with "body in scan → high, prototype only → medium, neither → low", taken name by name.
- Every written `name(` call outside a definition or prototype has an edge. The only leftovers are `__attribute__((format(...)))`, `aligned(16)` and the function-type parameter `void f(char *)`, which are not calls.

## Precision sample (seed 6)
Stratified at 24 high, 18 medium, 5 low and 3 unknown. The unknown tier has only 3 edges, so all 3 were taken. The sample covers 42 files. Each edge was checked at its line for a real call, caller, callee, tier, call_type and line. Results:
- 1–24 (high, direct/macro): all correct. Examples: `kernel/proc.c:42 proc_mapstacks → kvmmap`, `kernel/console.c:112 consoleread → C` (macro, high, `#define C(x)` at console.c:26), and `mkfs/mkfs.c:212 rinode → rsect` (mkfs-local).
- 25–42 (medium, direct): the user syscall wrappers `exit`, `unlink`, `fork`, `open`, `close`, `write`, `pause`, `link`, `fstat` and `kill`. Each is declared in user/user.h and defined only in usys.S, which usys.pl generates and which is not C. That gives medium by the 2026-11-09 prototype rule. All correct.
- 28 `kernel/printk.c:115 printk → va_arg` (macro, medium): spec gap c/13 (a system-header name).
- 43–45 `__atomic_store_n` / `__atomic_load_n` (low, direct): GCC builtins with no declaration anywhere, which makes them "a bare name not found in the scan". Correct.
- 46 `mkfs/mkfs.c:184 wsect → lseek` and 47 `mkfs/mkfs.c:292 iappend → bcopy` (low): spec gap c/13 (libc).
- 48 `user/usertests.c:3424 run → f` (callback, unknown): `f` is a parameter. Correct.
- 49/50 `kernel/file.c:147/119 → write/read` (callback, unknown): `devsw[f->major].write(...)` is a call through a stored function-pointer field, named by the field. Correct.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| mkfs/mkfs.c:124 | `bzero(&de, sizeof(de));` | main → bzero, high, direct | bzero, direct; tier not high (libc `bzero`; medium vs low is c/13) | wrong confidence | matched to `static void bzero(int dev, int bno)` in kernel/fs.c:51-52, which has internal linkage and is invisible to mkfs.c |
| mkfs/mkfs.c:129 | `bzero(&de, sizeof(de));` | main → bzero, high, direct | as above | wrong confidence | same |
| mkfs/mkfs.c:158 | `bzero(&de, sizeof(de));` | main → bzero, high, direct | as above | wrong confidence | same |
| mkfs/mkfs.c:232 | `bzero(&din, sizeof(din));` | ialloc → bzero, high, direct | as above | wrong confidence | same |
| mkfs/mkfs.c:248 | `bzero(buf, BSIZE);` | balloc → bzero, high, direct | as above | wrong confidence | same |
| kernel/syscall.c:146 | `p->trapframe->a0 = syscalls[num]();` | (no edge) | a dynamic call through the function-pointer array: callback, unknown (C4: never dropped) | missed call | call through an indexed array element is not emitted |
| kernel/printk.c:115 | `if ((s = va_arg(ap, char *)) == 0)` | printk → va_arg, medium, macro | undecided | spec gap | c/13 (system-header macro) |
| mkfs/mkfs.c:184 | `if (lseek(fsfd, sec * BSIZE, 0) != sec * BSIZE)` | wsect → lseek, low, direct | undecided | spec gap | c/13 (libc) |
| mkfs/mkfs.c:292 | `bcopy(p, buf + off - (fbn * BSIZE), n1);` | iappend → bcopy, low, direct | undecided | spec gap | c/13 (libc) |

## Systematic patterns (wrong), by scripted count
1. **A high match to a `static` function defined in another translation unit: 5 edges.** These are all mkfs/mkfs.c → `bzero` (lines 124, 129, 158, 232, 248). The script took every high direct edge and listed the files that define its callee. It flagged an edge when every such definition is a `static` function in a different .c file, with no same-file or header definition. Only these 5 matched. I checked all 5 by hand. kernel/fs.c:51-52 is `static void bzero(int dev, int bno)`, with a different arity, while mkfs calls libc `bzero(void*, size_t)`. C internal linkage makes the kernel definition unreachable from mkfs.c, so "defined in the scan" (high) does not hold.

Census: 1 − 5/3042 = 99.84%.

## Missed-call patterns (recall)
Recall functions:
- `syscall` (kernel/syscall.c): 4 real calls (`myproc`, `NELEM`, `syscalls[num]()`, `printk`). 3 have edges. `syscalls[num]()` is missed.
- `create` (kernel/sysfile.c): 20 real calls. All 20 have edges, including the two `dirlink` calls on line 302.
- `runcmd` (user/sh.c): 35 real calls. All 35 have edges.

Totals: 1 missed of 59, 0 non-calls.

Whole-scan pattern:
- **A call through an indexed function-pointer array element `arr[i]()`: 1.** A grep for `](` / `)(` call forms over all in-scope C found only kernel/syscall.c:146. CAPABILITIES.md (c) does not list this construct as unsupported. The other indirect calls, a parameter `f(s)` and a struct field `devsw[..].read(..)`, are emitted.

## Spec gaps (counted separately, not wrong)
1. **c/13, C library and system-header names: 60 edges.** This excludes the 5 `bzero` edges counted wrong above, whose high tier is excluded either way.
   - 25 are mkfs/mkfs.c calls to hosted libc functions. mkfs.c includes `<stdio.h>`, `<unistd.h>`, `<stdlib.h>`, `<string.h>`, `<fcntl.h>` and `<assert.h>`, and not user/user.h. The calls come out at three tiers:
     - low: `lseek` ×2, `index`, `bcopy`, `perror`.
     - medium: `exit` ×3, `open` ×2, `read` ×2, `close`, `write`.
     - high, through same-named non-static definitions in user/ or kernel/: `printf` ×3, `strcpy` ×2, `fprintf`, `memset`, `memmove`, `strncmp`, `strlen`, `strncpy`.
   - 35 are function-like macros from system headers, tagged macro, medium: `va_arg` ×24, `va_start` ×3, `va_end` (kernel/printk.c, user/printf.c), and `assert` ×7 (mkfs.c).
   - Construct: `if (lseek(fsfd, sec * BSIZE, 0) != sec * BSIZE)` (mkfs.c:184), `assert(index(shortname, '/') == 0);` (mkfs.c:142).
   - Question SPEC leaves open (CAPABILITIES c/13): is a call to a standard-library function whose only declaration is in a system header medium or low? Does its ID stay bare? Is a system-header function-like macro macro/medium or direct?
2. **The same bare C name defined in a different program of the same scan: 13 edges.** 11 of these overlap gap 1. They are the 11 mkfs high edges above (printf ×3, strcpy ×2, fprintf, memset, memmove, strncmp, strlen, strncpy), plus 2 in user/ulib.c.
   - Construct: `return sys_sbrk(n, SBRK_EAGER);` (user/ulib.c:155, 161). The user-side `sys_sbrk` is declared at user/user.h:24 and defined by the generated usys.S (`if ($name eq "sbrk")` in usys.pl). The tool marks it high through the kernel's unrelated `sys_sbrk(void)` at kernel/sysproc.c:40.
   - Likewise `printf(...)` in mkfs.c resolves high to user/printf.c's non-static `printf`. That file is linked only into user programs.
   - Question SPEC leaves open: C IDs are bare names, so separate executables in one scan (kernel, user programs, host tool mkfs) share IDs. Does "defined in the scanned source" (high) require the definition to be in the caller's link unit, or does any external-linkage definition of that name count? C1 says each definition has exactly one ID, but SPEC does not say how bare names resolve when several definitions share one.

Union of spec-gap edges, excluding the 5 wrong: 62.

## Helper scripts
- <fanout>/s-xv6-riscv_r6_load.py
- <fanout>/s-xv6-riscv_r6_scan.py
- <fanout>/s-xv6-riscv_r6_caller.py
- <fanout>/s-xv6-riscv_r6_conf.py
- <fanout>/s-xv6-riscv_r6_static.py
- <fanout>/s-xv6-riscv_r6_sample.py
- <fanout>/s-xv6-riscv_r6_recall.py
- <fanout>/s-xv6-riscv_r6_census.py
