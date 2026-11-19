# h-chi (Go) call-graph blind review, v2

precision 50/50; census ≈99.9% (2 wrong of 1774 in-scope); recall: 0 missed of 31 real calls; 0 non-calls

## Scope
Source root `<source-root>/web/frameworks/chi`, tool output `h-chi.v2.json`. All 1774 edges have a `.go` source_file, and none sits under a test/, tests/, spec/, examples/ or docs/ segment. `_examples/` is not the excluded `examples` segment, so it is in scope (Decisions 2026-11-09). That leaves **1774 in-scope edges**:
- By confidence: high 388, medium 560, low 800, unknown 26.
- By call_type: method 1021, direct 727, callback 26.
- 1120 edges carry `is_external`: all 560 medium, plus 560 of the low edges.

The tool emitted no edges from `*_test.go` files, so "everything the tool scans" means the 54 non-test .go files. 51 of them have edges. `_examples/logging/main.go` and `_examples/versions/presenter/v1/article.go` contain no calls.

There are three Go modules: the root `github.com/go-chi/chi/v5`, `_examples/versions` (module `versions`) and `_examples/rest` (module `rest-example`).

All 800 low edges are VTA implementation edges. Each one pairs with a high or medium interface edge at the same file, line and caller (`h-chi_r1_vta.py`: 800 paired, 0 orphans). I checked them for "the callee type implements the interface and the flow is plausible", but I did not re-run VTA.

Helper scripts are in the fanout folder, all prefixed `h-chi_r1_`: `load`, `sample`, `vta`, `defs`, `callers`, `lines`, `noparen`, `pkgvars`, `census`, `gaps`.

## Method
- **Precision sample:** seed 20261110, drawn by `h-chi_r1_sample.py`. Strata: low 21, medium 14, high 10, unknown 5. It covers 24 files. Every edge was checked against its source line. All 50 are correct: 1 is a spec gap (#33, below), and the call_type question in Spec gaps affects many of them.
- **Scripted checks over all 1774 edges:**
  - Every edge's caller matches its enclosing function, closure (`$N`) or named nested func (`outer.f`); 0 mismatches.
  - Every callee name appears on the reported line followed by `(`; 0 failures.
  - Every closure callee is an immediately invoked `go func(){…}()` or `defer func(){…}()`.
  - There are no builtin edges and no conversion edges.
  - Every in-scan callee ID resolves to a definition, apart from the presenter case under Spec gaps.
- **Recall:** three functions, 31 real calls, all found by the tool:
  - `Mux#Mount` (mux.go:295): 14 calls, including the `Mount$1` closure.
  - `NewCompressor` (middleware/compress.go:72): 7 calls.
  - `prettyStack#decorateFuncCallLine` (middleware/recoverer.go:132): 10 calls.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| middleware/logger.go:52 | `entry.Write(ww.Status(), ww.BytesWritten(), ww.Header(), time.Since(t1), nil)` | `middleware.RequestLogger$1.fn$1` → `middleware.WrapResponseWriter#Header`, high, method | same callee, **medium**. `Header` is not declared in the scan; it comes from the embedded `http.ResponseWriter` in `type WrapResponseWriter interface { http.ResponseWriter; … }` | wrong confidence | method promoted from an out-of-scan embedded interface counted as defined in the scan |
| middleware/logger.go:52 | same line | `middleware.RequestLogger$1.fn$1` → `net/http.ResponseWriter#Header`, low, method (as a VTA implementation edge) | VTA edges must name concrete implementations. Here they would be the runtime writers behind `basicWriter`'s embedded field (`net/http.response#Header` etc.), as the tool does at compress.go:331 | wrong callee | promoted method on a concrete type resolved to the embedded interface method instead of its implementations |
| middleware/content_type.go:12 (sample #33) | `w.Header().Set(key, value)` | `middleware.SetHeader$1$1` → `net/http.Header#Set`, medium, direct | the receiver type is known only from net/http's signature of `Header()` | spec gap | correct resolution beyond the "typing reaches only declarations in the scan" rule (gap 2) |
| _examples/versions/main.go:87 | `articles <- v1.NewArticleResponse(article)` | `versions.listArticles$1` → `github.com/go-chi/chi/v5/_examples/versions/presenter/v1.NewArticleResponse`, medium, direct | the function is defined in the scan as `versions/presenter/v1.NewArticleResponse`, but the import path names the parent module | spec gap | nested-module import of its own package through the parent module path (gap 3) |

## Systematic patterns (wrong), scripted counts (`h-chi_r1_census.py`)
1. **VTA "implementation" edge naming an interface method.** These are low edges whose callee type is one of the interfaces used as an interface-call target: 1 edge (logger.go:52 `net/http.ResponseWriter#Header`). Every other low edge names a concrete type.
2. **High confidence for a method promoted from an out-of-scan embedded interface:** 1 edge (logger.go:52 `WrapResponseWriter#Header`). `h-chi_r1_defs.py` finds no other high callee that is missing from the scan's declarations.

Union: 2 wrong edges of 1774, so census precision = 1 − 2/1774 ≈ 99.9%.

## Missed-call patterns (recall)
- **Recall functions:** 0 missed of 31.
- **Found by looking: calls in package-level `var` initializers have no edge.** Per Decisions 2026-10-29 the caller should be `pkg.init`. `h-chi_r1_pkgvars.py` finds 10 missed calls:
  - `middleware/realip.go:12-14`: `http.CanonicalHeaderKey` ×3
  - `middleware/nocache.go:12`: `time.Unix`, `time.Time#UTC`, `time.Time#Format`
  - `_examples/versions/data/errors.go:11-13`: `errors.New` ×3
  - `_examples/rest/main.go:53`: `flag.Bool`

  Calls inside an explicit `func init()` are emitted with caller `pkg.init`, for example `middleware/request_id.go:47-59` and `middleware/logger.go:177`. So the gap is limited to `var` initializers.

## Spec gaps (not counted as wrong)
1. **call_type `direct` vs `method` for calls on concrete types: 320 edges** (186 high, 134 medium). The tool marks method calls on a concrete receiver as `direct`, for example `r.Context()` → `net/http.Request#Context` and `r.Use(...)` → `Mux#Use`. It reserves `method` for interface dispatch. The spec lists both values but never defines the difference.
2. **Receivers typed only by out-of-scan library signatures, resolved to `Type#m` medium: at least 50 base edges.** The 2026-11-09 decision calls a low guess correct here but says nothing about a correct, more precise resolution. Scripted subset in `h-chi_r1_gaps.py`, broken down:
   - `r.Context().Value/Done/Err`: 14
   - `w.Header().Set/Add/Get/Del`: 14
   - `r.Header.Get/Values/Del`: 11
   - `r.URL.Query`: 3
   - `.Query().Get`: 3
   - other: 5

   Locals bound by `:=` from external calls, such as `ctx.Done()` after `context.WithTimeout`, are not included. The VTA low edges at these sites depend on the same typing.
3. **Nested-module self-imports: 6 edges.** The `versions` module imports `github.com/go-chi/chi/v5/_examples/versions/presenter/v{1,2,3}`. The scan defines those packages under the module's own path, `versions/presenter/vN`. The tool emits the import-path ID, medium. With `require github.com/go-chi/chi/v5 v5.1.0` and no `replace`, that path does not point at the scanned files.

   The same modules' calls into `github.com/go-chi/chi/v5` resolve to the scanned chi source (high), even though they would build against module-cache copies (v5.1.0 / v5.0.1). The spec does not say how scanned sources map onto required module versions.
4. **`is_async` on `go func(){…}()`: 2 edges** (`_examples/graceful/main.go:26`, `_examples/versions/main.go:75`) have no `is_async`. The spec has the field but does not define when a Go call counts as async.
