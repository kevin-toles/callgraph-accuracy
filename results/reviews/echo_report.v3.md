# echo (go) call-graph review, v3 (re-review against the current SPEC.md)

precision 49/50; census ≈98.7% (45 wrong of 3442 in-scope); recall: 7 missed of 38 real calls; 0 non-calls

**Scope.** The output has 3,442 edges, and all of them are in scope. No edge comes from a `_test.go` file or an excluded directory. `echotest/` (44 edges) is a test-helper package, but it is not one of the excluded directory names, so I kept it. By confidence: low 1,578, medium 921, high 746, unknown 197. By call_type: method 1,767, direct 1,478, callback 197.

**Sample.** `echo_v3_sample.py` uses seed 20261028 and allows at most 2 edges per file per tier. It drew 50 edges (high 10, medium 13, low 22, unknown 5) from 28 files. 49 are correct. The wrong one is #37 at context.go:741 (see the table). The low edges are VTA implementation edges, and every low site also has its interface edge. I cannot re-derive VTA by hand, so I judged them against the Go note. They use include_external (the external edges carry `is_external`).

**Census.** I built an AST inventory of every call site in the non-test source with `echo_v3_ast/main.go` (go/parser, read-only), saved as `echo_v3_calls.jsonl`. I checked it against the edges with:
- `echo_v3_recall.py`: call sites with no edge.
- `echo_v3_census.py`: named-local closures and package-level closures.
- `echo_v3_defs.py`: callee IDs against definitions, and confidence tiers.
- `echo_v3_lines.py`: whether the callee name appears on the edge's line.

Results:
- Every edge's callee name appears on its line (0 line errors).
- All 197 callbacks name a variable or field that is on the line.
- Only 2 repo-prefixed callee IDs have no definition (the anonymous-interface spec gap).
- Wrong edges: 14 + 19 + 12 = 45 (patterns 1–3 below).

**Recall** (38 real calls, builtins excluded):
- `proxyRaw` (middleware/proxy.go:130-186), including its closure `proxyRaw$1` and the local `cp`: 23 of 23 found. The outer function has no calls; `http.HandlerFunc(...)` is a conversion and `d.DialContext` is a method value. The 2 `cp` calls are found, but under the wrong name (pattern 3).
- `Echo#serveHTTP` (echo.go:828-847): 7 of 7 found. These are `sync.Pool#Get`, `sync.Pool#Put`, `Context#Reset`, `Router#Route` (plus a low `DefaultRouter#Route`), and the callbacks `chain`, `preChain` and `HTTPErrorHandler`.
- `createExtractors` (middleware/extractor.go:78-114): 1 of 8 found. Only `strings.SplitSeq` (line 88) has an edge. The 7 calls inside the `for source := range sources` body (a range-over-func loop) are missing.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| context.go:741 | `f, err = filesystem.Open(file)` | `fsFile` → `echo/v5.defaultFS#Open`, low, method, **is_external** | Same edge without `is_external`, because `defaultFS` is defined at echo.go:923 | other (wrong flag) | in-scan implementation edges flagged external |
| middleware/extractor.go:91 | `parts := strings.Split(source, ":")` | (no edge) | `createExtractors` → `strings.Split`, medium, direct | missed call | call in a range-over-func loop body dropped |
| middleware/extractor.go:93 | `return nil, fmt.Errorf("extractor source for lookup could not be split into needed parts: %v", source)` | (no edge) | → `fmt.Errorf`, medium | missed call | same |
| middleware/extractor.go:98 | `extractors = append(extractors, valuesFromQuery(parts[1], limit))` | (no edge) | → `middleware.valuesFromQuery`, high | missed call | same |
| middleware/extractor.go:100 | `extractors = append(extractors, valuesFromParam(parts[1], limit))` | (no edge) | → `middleware.valuesFromParam`, high | missed call | same |
| middleware/extractor.go:102 | `extractors = append(extractors, valuesFromCookie(parts[1], limit))` | (no edge) | → `middleware.valuesFromCookie`, high | missed call | same |
| middleware/extractor.go:104 | `extractors = append(extractors, valuesFromForm(parts[1], limit))` | (no edge) | → `middleware.valuesFromForm`, high | missed call | same |
| middleware/extractor.go:110 | `extractors = append(extractors, valuesFromHeader(parts[1], prefix, limit))` | (no edge) | → `middleware.valuesFromHeader`, high | missed call | same |
| middleware/proxy.go:173 | `go cp(out, in)` | `proxyRaw$1` → `middleware.proxyRaw$1$1`, high, direct | → `middleware.proxyRaw$1.cp`, high (named nested function) | wrong callee | local bound to a func literal named as an anonymous closure |
| middleware/proxy.go:174 | `go cp(in, out)` | `proxyRaw$1` → `middleware.proxyRaw$1$1`, high, direct | → `middleware.proxyRaw$1.cp`, high | wrong callee | same |
| middleware/proxy.go:169 | `_, copyErr := io.Copy(dst, src)` | `middleware.proxyRaw$1$1` → `io.Copy`, medium | caller `middleware.proxyRaw$1.cp` | wrong caller | same |
| response.go:127 | `rw = t.Unwrap()` (`case interface{ Unwrap() http.ResponseWriter }:`) | `UnwrapResponse` → `echo/v5.Unwrap`, high, method | The interface is anonymous, so there is no `Interface#Method` name. `echo/v5.Unwrap` does not exist. | spec gap | anonymous interface type |
| renderer.go:31 | `return t.Template.ExecuteTemplate(w, name, data)` | `TemplateRenderer#Render` → `echo/v5.ExecuteTemplate`, high, method | same as above | spec gap | anonymous interface type |

## Systematic patterns (ordered by census count)

1. **Missed: calls in package-level variable initializers (20 call sites, 0 edges).** The spec now says file-level code is a caller under the module ID (here the package path). None of these sites has an edge:
   - httperror.go:30-36 and :41: `errors.New(...)` x7.
   - bind.go:517-521: `reflect.TypeFor[...]()` x4.
   - context_generic.go:9 and :12: `errors.New` x2.
   - context.go:774: `var quoteEscaper = strings.NewReplacer(...)`.
   - scheme.go:70: `var defaultSchemeChecker = newIPChecker(nil)`.
   - middleware/key_auth.go:106 and :109: `echo.NewHTTPError(...)`.
   - middleware/rate_limiter.go:55 and :58: `echo.NewHTTPError(...)`.
   - middleware/method_override.go:32: `Getter:  MethodFromHeader(echo.HeaderXHTTPMethodOverride),`.

   Function literals inside these initializers do get edges (as `init$N`, see Spec gaps).
2. **In-scan callees flagged `is_external` (33 edges, of which 19 are wrong only because of the flag).** The 19 are low implementation edges whose type is defined in the repo: `httpError#Error` x11, `defaultFS#Open` x5 and `DefaultJSONSerializer#Serialize`/`#Deserialize` x3. Other in-scan implementation edges, such as `HTTPError#Error`, carry no flag. The other 14 are pattern 3.
3. **Calls to generic in-scan functions get medium plus `is_external` instead of high (14 of 14 call sites).** The callees are `ParseValue` x4, `ParseValueOr` x4, `ParseValuesOr` x3, `ParseValues` x2 and `ContextGet` x1, all defined in binder_generic.go and context_generic.go. Example: binder_generic.go:62 `v, err := ParseValue[T](pv.Value, opts...)` gives `PathParam` → `echo/v5.ParseValue`, medium, is_external. This is wrong confidence.
4. **Locals bound to a func literal are named as anonymous closures `F$N`, not `outer.f` (12 edges: 7 wrong caller, 5 wrong callee).** There are 6 such locals:
   - `dispatch` (echo.go:429) → `Echo#buildRouterChains$1`
   - `route` (echo.go:435) → `$2`
   - `handler` (echo.go:728) → `Echo#File$1`
   - `handler` (group.go:178) → `Group#File$1`
   - `cp` (proxy.go:168) → `proxyRaw$1$1`
   - `backtrackToNextNodeKind` (router.go:955) → `DefaultRouter#Route$1`

   The callee edges are proxy.go:173 and :174, and router.go:1009, :1105 and :1119, for example `nk, ok := backtrackToNextNodeKind(staticKind)` → `DefaultRouter#Route$1`. They are already high and direct; only the IDs are wrong. The Go note's `pkg.F$1` is still right for anonymous closures. I applied the general named-nested-function rule to the named locals (see Spec gaps).
5. **Missed: calls in range-over-func loop bodies (11 call sites in 3 loops, 0 edges).** The loops are middleware/extractor.go:88-113 (7 calls, listed in the table), echo.go:1032 and middleware/static.go:427, the two copies of `hasDotOrEmptySegment`. In those two, `if strings.Contains(segment, \`\\\`) {` and `for part := range strings.SplitSeq(segment, \`\\\`) {` (echo.go:1038-1039, static.go:433-434) have no edge. The range expression itself (`strings.SplitSeq` on the loop line) is found.

The census counts only edges that exist. Patterns 2, 3 and 4 give 19 + 14 + 12 = 45 wrong edges. Patterns 1 and 5 are 31 missed calls, which do not enter census precision. The AST cross-check found no other call site without an edge, apart from builtins and conversions.

## Spec gaps (not counted as wrong)

- **Go named locals versus the Go closure note (12 edges, pattern 4).** The general rule ("a local bound directly to a function literal … is a named nested function") lists no Go form. The Go note only says "closures `pkg.F$1`". I counted these as wrong under the general rule. If the Go note is meant to override it, census becomes 33 wrong (99.0%).
- **Package-level closures are named `pkg.init$N` (21 caller edges).** 17 of them come from package-level `var f = func…` bindings: `redirectHTTPS`/`WWW`/`NonWWW`… in middleware/redirect.go:147-179, and `notFoundHandler`/`methodNotAllowedHandler`/`optionsMethodHandler` in router.go:882-901. The other 4 are closures inside struct literals, as in rate_limiter.go:63-71. The spec says neither whether a package-level func var is `pkg.f`, nor what a closure in a package-level initializer is named.
- **Methods of anonymous interface types (2 edges).** These are response.go:127 and renderer.go:31 above. They are high-confidence edges to an ID that does not exist.
- **Go builtins produce no edges.** That covers 309 builtin call sites, plus `unsafe.Slice`/`unsafe.StringData` at context.go:38.
- **`go f()` statements carry no `is_async`.** There are 0 async edges, including proxy.go:173-174. The spec does not say whether goroutine launches are async.
- **call_type mapping for Go.** Statically resolved method calls are `direct` (715 high), and interface calls are `method` at every tier (189 high or medium, 1,578 low). The spec does not define this mapping.
- **Out-of-scan implementation fan-out.** There are 1,272 out-of-scan low edges over 150 sites (max 108 per site). 614 of them name unexported stdlib types, for example `runtime.plainError#Error` and `crypto/x509/internal/macos.OSStatus#Error`. They are allowed under include_external, and every site keeps its interface edge.

## Previous findings

| previous item (v2 report) | status | count now |
|---|---|---|
| Mismatch rows 1–4: `defer cancel()` named after an SSA register (`t9`, `t92`, `t12`, `t13`) | **Fixed** | 0 of 4. server.go:156, server.go:190, echo.go:873 and middleware/context_timeout.go:61 now give `cancel`, unknown, callback. 0 callbacks with a `tN` callee; all 197 callbacks name a variable or field on the line. |
| Mismatch rows 5–6: anonymous-interface calls get a package-level ID at high (spec gap) | **Still present** (spec gap) | 2 (response.go:127, renderer.go:31) |
| Pattern 1: `tN` register callees on tuple-assigned function values | **Fixed** | 0 (was 4) |
| Pattern 2: interface calls fan out to out-of-scan stdlib implementations, including unexported types | **Still present, unchanged** (allowed under include_external) | 1,578 low edges; 1,272 out-of-scan plus 19 in-scan flagged `is_external`, which matches the previous 1,291; 614 unexported out-of-scan types (my regex); max 108 per site; 150 sites, all with their interface edge |
| Pattern 3: anonymous-interface method IDs | **Still present** (spec gap) | 2 |
| Pattern 4: top-level `low_confidence_count` (1,775) = low (1,578) + unknown (197) | **Still present** | 1,775 |
| Pattern 5: builtins produce no edges; static methods are `direct`, interface calls are `method` (spec gaps) | **Still present** (spec gaps) | 0 builtin edges; `method` 1,767, `direct` 1,478 |
| Not in the previous report (found now) | new | Missed package-level initializer calls (20 sites, now in scope under the file-level-caller rule), named-local func-literal IDs (12, under the new named-nested rule), generic in-scan callees at medium (14), in-scan `is_external` flags (19), missed calls in range-over-func bodies (11). The edge totals match the previous run exactly, so the last 3 were most likely already present and were missed in v2. |

Helper files (all in the fanout folder): `echo_v3_sample.py`, `echo_v3_sample.json`, `echo_v3_ast/main.go` (with its own `go.mod`), `echo_v3_calls.jsonl`, `echo_v3_recall.py`, `echo_v3_census.py`, `echo_v3_defs.py`, `echo_v3_lines.py`.
