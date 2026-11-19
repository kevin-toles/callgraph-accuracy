# Blind call-graph review: s-robpike-ivy (Go)

precision 50/50; census ≈98.9% (73 wrong of 6615 in-scope); recall: 0 missed of 43 real calls; 0 non-calls

In the recall set, 13 of the 43 calls (in `value.gamma`) have the wrong callee. They are calls through the local method values `B`/`U`, which the tool reported as `value.Context#EvalBinary`/`#EvalUnary` (pattern 2 below). No edge in the sample or the recall set lacks a real call expression.

## Scope
- Source root: `<source-root>/compilers/sme/robpike-ivy`.
- Tool output has 6615 edges, all with `.go` source files. None is under a test/, tests/, spec/, examples/ or docs/ segment, so all **6615 are in scope**.
- Confidence: high 3792, medium 1258, low 1532, unknown 33.
- call_type: direct 4538, method 2044, callback 33.
- By tier and type: high/direct 3287, high/method 505, medium/direct 1251, medium/method 7, low/method 1532, unknown/callback 33.
- In-scope Go files that got zero edges: the six `*_test.go` files (`ivy_test.go`, `demo_test.go`, `order_test.go`, `quorem_test.go`, `value/persist/slice_test.go`, `mobile/mobile_test.go`) and the three `//go:build ignore` generators (`parse/helpgen.go`, `mobile/help_gen.go`, `lib/libgen.go`). These are covered under recall below.
- Files with no calls to miss: `doc.go`, `parse/help.go`, `mobile/help.go`, `lib/lib.go`, `lib/libdefs.go`, `exec/operator.go`, `exec/opdef.go`, `parse/exec/opdef.go`.

## Method
- **Precision sample:** seed 20261110, stratified high 26 / low 11 / medium 8 / unknown 5, covering 23 files (`s-robpike-ivy_r1_sample.py`). All 50 are correct:
  - Interface calls emit `Interface#Method` high, plus low VTA edges to concrete types. Examples: `value.Expr#ProgString` → `IfExpr/Complex/...#ProgString`, and `value.Context#Errorf` → `exec.Context#Errorf`.
  - The named nested function `value.IndexAssign.badShape` is correct.
  - Closure invocations `run.Run → run.Run$1` (`defer func(){…}()`) follow the Go closure naming `pkg.F$1`.
  - Callback edges name the parameter or local (`op`, `fn`, `f`, `yield`, `state`).
- **Recall:**
  - `exec.Context#EvalBinary` (exec/context.go:235–261): 12 calls, all present. The `fn.EvalBinary` call has its `BinaryOp#EvalBinary` high edge plus low edges to `exec.Function` and `value.binaryOp`.
  - `persist.TransientSlice#Resize` (value/persist/slice.go:503–546): 12 calls, all present. The builtins `clear`/`copy`/`panic` correctly have no edge. 9 of the 12 are in-scan callees marked medium (P2).
  - `value.gamma` (value/fac.go:183–225): 19 calls, all present. 13 of them have the wrong callee (P1).
- **Census scripts:** `s-robpike-ivy_r1_census.py`, `s-robpike-ivy_r1_rangefunc.py`, `s-robpike-ivy_r1_varinit.py` and `s-robpike-ivy_r1_unscanned.py`, all in the fanout folder.
- **Extra census checks:**
  - Every low edge has a matching high/medium "as written" interface edge on the same line: 0 orphans.
  - In every edge except 28, the callee's name appears on the source line. The 28 are the 18 P1 edges and 10 correct `F$1` closure invocations.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| value/fac.go:169 | `rMinusN := B(r, "-", Int(n))` | value.cₙ → value.Context#EvalBinary, medium, direct | value.cₙ → `B`, unknown, callback | wrong callee | call through local bound to method value `B := c.EvalBinary` resolved to the method |
| value/fac.go:202 | `return B(𝛑, "/", B(sin(c, B(z, "*", 𝛑)), "*", gamma(c, B(one, "-", z))))` | value.gamma → value.Context#EvalBinary, medium, direct (×4) | value.gamma → `B`, unknown, callback (×4) | wrong callee | same (`B := c.EvalBinary`, line 193) |
| value/fac.go:218 | `q := exp(c, U("-", zPlusR))` | value.gamma → value.Context#EvalUnary, medium, direct | value.gamma → `U`, unknown, callback | wrong callee | same (`U := c.EvalUnary`, line 194) |
| value/persist/slice.go:506 | `case n > t.Len():` | persist.TransientSlice#Resize → persist.TransientSlice#Len, medium, direct | same callee, **high** | wrong confidence | method of scanned generic type `TransientSlice[T]` not tiered high |
| value/persist/slice.go:521 | `ip, _ := p.Load().(*inode)` | … → sync/atomic.Value#Load, medium | correct | — | (control) |
| value/vector.go:66 | `func (v *vectorEditor) Len() int { return v.t.Len() }` | value.vectorEditor#Len → persist.TransientSlice#Len, medium, direct | same callee, high | wrong confidence | call into scanned generic type |
| value/vector.go:29 | (Vector#All body) `v.data.All()` | value.Vector#All → persist.Slice#All, medium, direct | same callee, high | wrong confidence | call into scanned generic type |
| value/index.go:143 | `c.Errorf("invalid index %s (type %s) in %s", vj, whichType(c, vj), DebugProgString(top))` | (no edges) | Context#Errorf high, whichType high, DebugProgString high, … | missed call | body of `for … range v.All()` (range-over-func) gets no edges |
| ivy.go:28 | `execute = flag.String("e", "", …)` | (no edge) | main.init → flag.String, medium | missed call | package-level var initializer |
| value/const.go:52 | `complexOne = NewComplex(debugContext, one, zero)` | (no edge) | value.init → value.NewComplex, high | missed call | package-level var initializer |
| value/expr.go:118 | `… c.Cond.ProgString() + " : " + c.Value.ProgString()` | value.ColonExpr#ProgString → value.Value#ProgString, low (is_external) | concrete impl is `QuietValue` (embeds `Value`); spec does not say how to name a promoted method of an embedded interface | spec gap | VTA implementation via embedded interface |

## Systematic patterns (wrong, counted by script)
1. **In-scan callees on generic types are tiered medium: 55 edges.** Edges into `persist.TransientSlice` (40) and `persist.Slice` (15) are medium although both are defined in value/persist/slice.go, so per the tiers they should be high. Validated by hand at slice.go:506/508/511 and vector.go:29/66.
2. **Call through a local bound to a method value: 18 edges, all in value/fac.go.** `B := c.EvalBinary` / `U := c.EvalUnary` (fac.go:156, 193, 194). Every `B(...)`/`U(...)` call is reported as `value.Context#EvalBinary`/`#EvalUnary`, medium, direct. Per spec a call through a local holding a function is one edge with callee `B`/`U`, callback, unknown. The tier is also wrong, since `value.Context` is in scan. These are the only method-value bindings in the repo (grep).

The two patterns are disjoint, so the union is 73 edges (55 + 18) and census precision = 1 − 73/6615 ≈ 98.9%. The census script prints 66 because it dedups on (file, line, caller, callee, confidence, call_type), which collapses repeated `B(...)` edges on one line. The raw edge count, 73, is the one used here.

## Missed-call patterns (recall)
- **Range-over-func loop bodies get no edges.** 60 `for … range X.All()` / `slices.Backward(…)` / `strings.SplitSeq(…)` / `eachValue(…)` loops in non-test files have 0 edges inside their bodies. There are 94 body lines with call expressions and ≈124 call tokens (regex count, `s-robpike-ivy_r1_rangefunc.py`). The loop header's own call (`v.All()`) is graphed. Examples: ivy.go:98–121 (`conf.SetDebug`, `lib.Lookup`, `runString`, `os.Exit`), parse/parse.go:36, value/index.go:141–197.
- **Package-level var initializers get no edges: 32 calls.**
  - ivy.go:28–41: 14 `flag.*` calls.
  - value/const.go:37–53: 15 calls (`NewVector`, `bigInt64`, `big.NewInt`, `big.NewRat`, `NewComplex`).
  - value/fac.go:134–135: 2 `stringToFloat` calls.
  - mobile/mobile.go:43: 1 `strings.NewReplacer` call.
  
  Per Decisions 2026-10-29 these should have caller `pkg.init`. Calls inside `func init()` bodies are graphed.
- **In-scope files not graphed at all: ≈450 call expressions** (regex count, includes some conversions).
  - The six `*_test.go` files have ≈295.
  - The three `//go:build ignore` generators have ≈156: `parse/helpgen.go`, `mobile/help_gen.go` and `lib/libgen.go`.
- The 3 recall functions themselves: 0 missed of 43.

## Spec gaps (counted separately, not wrong)
- **Promoted methods of an embedded interface: 38 edges** (`value.Value#ProgString` ×19 and `value.Value#Eval` ×19, all low).
  - `QuietValue` (value/assign.go:15) embeds the interface `Value`, so its `ProgString`/`Eval` are promoted wrappers that dispatch through `Value`.
  - The tool names the VTA "implementation" `value.Value#…`, an interface method, rather than `QuietValue#…`.
  - The spec's Go note ("one low edge per concrete implementation") does not say how to name an implementation that comes from an embedded interface.
- **`is_external: true` on in-scan callees: 111 edges.** These are the 38 above plus the 73 medium `persist.*` / `value.Context#*` edges. The spec defines the field's presence but not its meaning, so this is not judged.
