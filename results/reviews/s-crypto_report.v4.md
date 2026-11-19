# s-crypto (C, linux/crypto) blind call-graph review, round 4

precision 49/50; census ≈99.90% (16 wrong of 15975 in-scope); recall: 0 missed of 97 real calls; 0 non-calls

## Scope
Source root `<source-root>/operating-systems/linux/crypto` (155 .c, 18 .h, plus .asn1/Kconfig/Makefile, which have no edges). The tool emitted 15,975 edges, all from .c/.h files and none under a test/, tests/, spec/, examples/ or docs/ segment, so **all 15,975 are in scope** (testmgr.c, tcrypt.c and krb5/selftest.c are file names, not excluded directories). The edges come from 157 files.
- Confidence: high 6,710 · medium 3 · low 9,084 · unknown 178.
- call_type: direct 12,761 · macro 3,036 · callback 178. Combined: low/direct 9,084, high/direct 3,676, high/macro 3,034, unknown/callback 178, medium/macro 2, medium/direct 1.

Precision sample: seed `20261110`, stratified low 24 / high 18 / unknown 5 / medium 3 (all 3 medium edges exist, so all 3 are taken). It covers 36 files.

## Method notes
- I built a definition index of the scan (function bodies and `#define`s) with `s-crypto_r3_defs.py`. Every high edge's callee is a function or function-like macro defined in the scan. No low edge names an in-scan definition. Every in-scan `#define`d function-like macro is reported as `macro`, and no in-scan function is reported as `macro`.
- Every edge's callee name appears on its reported line (`s-crypto_r3_lines.py`), so there are no wrong lines.
- Every `->f(` / `.f(` call site in the source has a callback/unknown edge, and no direct edge uses that shape (`s-crypto_r3_cbrecall.py`, `s-crypto_r3_lines.py`). Calls through local or parameter function pointers (`fn(...)`, `crypt(...)`, `(*op)(req)`) are callback/unknown, which is correct.
- Callers: every edge's caller is either a function defined in that file or the file's module path (`api`, `asymmetric_keys/x509_parser`), except the 12 in pattern 1 (`s-crypto_r3_scope.py`, `s-crypto_r3_ranges.py`; the range script's other hits are my own parser's false positives, checked by hand at aegis128-neon-inner.c:57 and camellia_generic.c:879).
- Out-of-scan kernel names (`kmalloc`, `pr_err`, `ERR_PTR`, `async_tx_ack`) are low/direct. That is correct per the tiers: a bare name not found in the scan.

## Precision sample: mismatches
Out of 50 edges, 49 are correct and 1 is wrong. Two more are spec gaps (rows 48 and 50, not counted as wrong).

| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| api.c:35 | `DEFINE_STATIC_KEY_FALSE(__crypto_boot_test_finished);` | api → DEFINE_STATIC_KEY_FALSE, medium, direct | low (bare name not defined in the scan; the same-shaped `LIST_HEAD(crypto_alg_list);` at api.c:26 is low) | wrong confidence | file-scope macro invocation under `#if` seems to be taken as a prototype |
| mldsa.c:11 (×2, sample 48 and 50) | `u8 pk[MAX(MAX(MLDSA44_PUBLIC_KEY_SIZE,` | mldsa → MAX, medium, macro | spec gap: a macro recognised from context (array bound) but not `#define`d in the scan; the spec only says "high if #defined in the scan" | spec gap | — |

## Census: wrong patterns (union = 16 edges)
Ordered by count. Each pattern was found by script and checked by hand.

| # | pattern | count | example (file:line, source) | tool said | correct per spec | category |
|---|---|---|---|---|---|---|
| 1 | Body of a `for_each_possible_cpu(x) {` loop is attributed to the loop variable | 12 | acompress.c:398 `struct crypto_acomp_stream *ps = per_cpu_ptr(streams, i);` | i → per_cpu_ptr, low | crypto_acomp_free_streams → per_cpu_ptr | wrong caller |
| 2 | Wrong confidence for a file-scope macro invocation | 1 | api.c:35 (above) | medium | low | wrong confidence |
| 3 | A cast followed by a parenthesised expression is taken as a call | 1 | aegis128-neon-inner.c:88 `w = (v << 1) ^ (uint8x16_t)(((int8x16_t)v >> 7) & 0x1b);` | aegis_aes_round → uint8x16_t, low, direct | no edge (cast) | not a call |
| 4 | The keyword `if` inside a macro argument is taken as a callee | 1 | asymmetric_keys/x509_parser.h:51 `if (!IS_ERR(_T)) x509_free_certificate(_T))` (argument of `DEFINE_FREE(...)`) | asymmetric_keys/x509_parser → if, low, direct | no edge (language construct) | not a call |
| 5 | Edge on a `#define` head line | 1 | rsassa-pkcs1.c:97 `#define _(X) { #X, hash_prefix_##X, sizeof(hash_prefix_##X) }` | rsassa-pkcs1 → _, high, macro | no edge (macro definition) | not a call |

Pattern 1 occurs in all 5 `for_each_possible_cpu(<ident>) {` loops: cryptd.c:110 (4 edges) and :125 (2), acompress.c:397 (2) and :434 (2), scompress.c:73 (2). Calls after the loop are attributed correctly (acompress.c:406 `free_percpu` → crypto_acomp_free_streams). Loops whose macro takes two arguments (`for_each_cpu(cpu, &mask) {`, scompress.c:99) are handled correctly.

Census precision = 1 − 16/15,975 = **99.90%**.

## Recall (3 functions, 0 missed of 97 real calls, 0 non-calls)
| function | file | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|---|
| crypto_rng_reset | rng.c:31–51 | 5 | 5 | 0 | 0 |
| krb5_test_one_mic | krb5/selftest.c:380–489 | 45 | 45 | 0 | 0 |
| essiv_create | essiv.c:440–622 | 47 | 47 | 0 | 0 |

All callees, tiers, call_types and lines match. For example, `crypto_rng_alg(tfm)->seed(...)` is both `crypto_rng_alg` low/direct and `seed` unknown/callback, `LOAD_BUF`/`CHECK` are high/macro, and the multi-line `crypto_spawn_skcipher_alg_common(` is reported on the line of its name.

## Missed-call patterns (recall, whole-source script `s-crypto_r3_missed.py`)
These come from scanning every `name(` site outside comments, strings and preprocessor lines and comparing it with the edges. They are recall findings, not precision. The scan found 55 missed calls in total.

| pattern | count | example |
|---|---|---|
| Declarator/attribute-position macros not emitted (`__free`, `__aligned`, `__counted_by`, `__guarded_by`). By contrast, `__context_unsafe(...)` after a function head at scompress.c:68 *is* emitted. | 16 | testmgr.c:3945 `u8 *ptr, *key __free(kfree);` |
| File-scope `static MACRO(...)` declarator invocations (`DEFINE_MUTEX` ×5, `LIST_HEAD` ×3, `DECLARE_RWSEM` ×2, `DEFINE_STATIC_KEY_FALSE`, `DECLARE_WORK`, `DEFINE_PER_CPU`). The non-`static` forms at api.c:26–31 are emitted. | 13 | aegis128-core.c:39 `static __ro_after_init DEFINE_STATIC_KEY_FALSE(have_simd);` |
| X-macro uses after the first `#define _(X)` are missed (lines 98–105). The uses after the second `#define _` (108–110) are found. | 8 | rsassa-pkcs1.c:99 `_(md5),` |
| Expression statements whose arguments contain a `struct T` type name are dropped whole: outer and inner calls at api.c:366, hctr2.c:295, essiv.c:329 and adiantum.c:519 (2 each). | 8 | api.c:366 `crypto_larval_kill(container_of(larval, struct crypto_larval, alg));` |
| The `for_each_possible_cpu(x)` loop macro itself is not emitted (the same 5 loops as pattern 1). | 5 | cryptd.c:110 `for_each_possible_cpu(cpu) {` |
| The same callee called twice on one line gives one edge. The spec does not say whether duplicates are kept; at mldsa.c:11 the tool does emit both `MAX` calls. | 4 | testmgr.c:2538 `if (crypto_aead_ivsize(tfm) != crypto_aead_ivsize(generic_tfm)) {` |
| A macro inside a struct body | 1 | asymmetric_keys/restrict.c:21 `TRAILING_OVERLAP(struct asymmetric_key_id, id, data,` |

## Spec gaps (counted separately, not wrong)
- **call_type of function-like macros defined outside the scan.** The C note says macros are `macro` ("high if #defined in the scan"), but it does not say how an out-of-scan name should be classified. 3,259 low/direct edges name something that is a function-like `#define` in the kernel's include/ (or arch/x86, arch/arm64, lib/crypto) headers. Examples: `EXPORT_SYMBOL_GPL` 350, `pr_err` 189, `MODULE_ALIAS_CRYPTO` 177, `min` 141, `unlikely` 60. This count is an upper bound, because some of these names (`memcpy`, `kmalloc`) are macros only in some configs. (`s-crypto_r3_extmacro.py`)
- **Confidence of a macro recognised by context but not defined in the scan**: `MAX` in an array bound (mldsa.c:11) is medium/macro. 2 edges.
- **Code inside `#if 0`**: 14 edges (drbg.c:1236–1255, 7; krb5/selftest.c:45–59, 7). The spec does not say whether disabled code is judged.
- **Calls inside `#define` bodies**: the tool emits no edges for them (apart from the wrong edge in pattern 5). The spec has no rule for this, so it is not counted.
- **Attribute-position macros** (`__free(kfree)` and similar, 16 sites) could be treated as macro calls or as attributes. I listed them under recall above, but the spec does not decide this case.

Helper scripts (prefix `s-crypto_r3_`, in <fanout>): scope.py, sample.py, ctx.py, defs.py (+defs.json), lines.py, patterns.py, missed.py, fnptr.py, ranges.py, recall.py, extmacro.py, cbrecall.py.
