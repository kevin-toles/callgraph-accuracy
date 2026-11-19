# s-gorm (Go) blind call-graph review, round v2

precision 50/50; census ≈98.7% (54 wrong of 4230 in-scope); recall: 0 missed of 37 real calls; 0 non-calls

## Scope
Source root `<source-root>/backend/orm/gorm` (module `gorm.io/gorm`). Tool output: `s-gorm.v2.json`, 4400 edges, all from `.go` files. 170 edges are under `tests/` and are out of scope. **In-scope: 4230 edges** in 57 files. Confidence split: high 1487, medium 1683, low 771, unknown 289. call_type split: direct 2657, method 1284, callback 289. There are no constructor, macro or implicit edges.

Coverage: 46 in-scope `.go` files have no edges. 37 of them are `_test.go` files outside `tests/` (for example `clause/*_test.go`, `schema/*_test.go`, `statement_test.go`, `utils/utils_test.go`), and those are in scope under Decisions 2026-11-09. The other 9 (`errors.go`, `interfaces.go`, `model.go`, `clause/with.go`, `clause/association.go`, `callbacks/interfaces.go`, `schema/interfaces.go`, `migrator/index.go`, `migrator/table_type.go`) hold only declarations or call-free bodies, except `errors.go`, which falls under the package-var pattern below.

## Method
- **Sample:** seed 20261110. Stratified 19 medium, 17 high, 9 low and 5 unknown edges, spread over 25 files. Helper scripts: `s-gorm_r1_load.py`, `s-gorm_r1_sample.py`.
- **Census:** `s-gorm_r1_explore.py`, `s-gorm_r1_census.py`, `s-gorm_r1_census2.py` and `s-gorm_r1_final.py` checked every in-scope edge for:
  - whether the callee's member name appears on the line;
  - in-scan callees given medium;
  - high callees that are not nodes and not interface members;
  - callback callees;
  - low edges that have no matching interface edge;
  - closure-call edges;
  - package-level var initializers.
- **Recall:** `s-gorm_r1_recall.py`.

## Precision sample (50 edges)
All 50 edges are real calls with the correct caller, callee, confidence and line.
- **Callers:** named nested functions such as `Association#saveAssociation.appendToRelations.processMap` and `schema.GetRelationsValues.appendToResults`, and closures `pkg.F$1`, are named as the spec requires.
- **Struct-field function values:** calls such as `rel.Field.Set(...)`, `field.ValueOf(...)` and `field.ReflectValueOf(...)` are callback/unknown edges with the field name as callee, which is correct.
- **Interface calls:** emitted as `Interface#Method` (high for in-scan interfaces, medium for `reflect.Type` and `error`). The low edges for concrete implementations, such as `strings.Builder#WriteByte`, `gorm.Statement#WriteString`, `clause.GroupBy#Build` and `reflect.rtype#Kind`, follow the spec's VTA rule, and out-of-scan implementations are emitted (`include_external` behaviour).
- **call_type:** sample items #2, #4–#19 and others use `direct` for concrete method calls. That is a spec gap (G1), not counted as wrong.

## Mismatch table (census and by-looking findings; none in the sample)
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| internal/lru/lru.go:204 | `c.removeElement(ent)` | `internal/lru.LRU#RemoveOldest` → `internal/lru.LRU#removeElement`, medium, direct | same IDs, **high** (method defined in scan) | wrong confidence | callee is a method of an in-scan generic type (`LRU[K, V]`) |
| internal/lru/lru.go:203 | `if ent := c.evictList.Back(); ent != nil {` | `LRU#RemoveOldest` → `internal/lru.LruList#Back`, medium, direct | high | wrong confidence | in-scan generic type `LruList[K, V]` |
| internal/stmt_store/stmt_store.go:113 | `return &lruStore{lru: lru.NewLRU[string, *Stmt](size, onEvicted, ttl)}` | `stmt_store.New` → `internal/lru.NewLRU`, medium, direct | high | wrong confidence | in-scan generic function |
| callbacks/query.go:302 | `fromClause.Expression = clause.From{Tables: v.Tables, Joins: utils.RTrimSlice(v.Joins, len(db.Statement.Joins))}` | `callbacks.AfterQuery` → `gorm.io/gorm/utils.RTrimSlice`, medium, direct | high | wrong confidence | in-scan generic function `RTrimSlice[T any]` |
| schema/field.go:612 | `return fallbackSetter(ctx, value, v, field.Set)` | `schema.Field#setupValuerAndSetter$7` → `fallbackSetter`, unknown, callback | `gorm.io/gorm/schema.Field#setupValuerAndSetter.fallbackSetter`, high, direct | wrong callee | `fallbackSetter := func(...)` (field.go:535) is a named nested function; the tool names it as a caller but its calls from sibling closures come out as a bare callback |
| association.go:480 | `appendToFieldValues(elem.Addr())` | `Association#saveAssociation.appendToRelations` → `appendToFieldValues`, unknown, callback | `gorm.io/gorm.Association#saveAssociation.appendToRelations.appendToFieldValues`, high, direct | wrong callee | `appendToFieldValues := func(ev reflect.Value)` (association.go:424) is also captured by `processMap`, and every call to it comes out as callback |
| association.go:466 | `appendToFieldValues(child)` | `...appendToRelations.processMap` → `appendToFieldValues`, unknown, callback | `...appendToRelations.appendToFieldValues`, high, direct | wrong callee | same as association.go:480 |
| errors.go:13 | `ErrInvalidTransaction = errors.New("invalid transaction")` | (no edge) | `gorm.io/gorm.init` → `errors.New`, medium, direct | missed call | package-level var initializer |
| statement.go:698/713 | `var matchName = func() func(tableColumn string) (table, column string) { … }()` | (no edge from `gorm.init` to `gorm.init$1`; the edges inside the body are present) | `gorm.io/gorm.init` → `gorm.io/gorm.init$1`, high | missed call | immediately invoked literal in a package-level var |
| generics.go:173 | `db = db.Session(&Session{NewDB: true, Context: ctx}).getInstance()` | (no edge; `g#apply` has no edges at all) | `gorm.io/gorm.g#apply` → `gorm.io/gorm.DB#Session`, high | missed call | methods of generic types `g[T]`, `chainG[T]`, `createG[T]`, `execG[T]`, `setCreateOrUpdateG[T]` get no edges |
| callbacks/create_test.go (whole file) | for example `ConvertToCreateValues(stmt)` | (no edges) | edges with the test functions as callers | missed call | in-scope `_test.go` files outside `tests/` are not graphed |

## Systematic patterns, wrong edges (scripted counts, ordered by count)
1. **P1: calls into scanned generics are medium (43 edges).** The callee is defined in the scan, so the spec requires high.
   - Breakdown: `internal/lru.LruList#*` 22, `internal/lru.LRU#*` 15, `internal/lru.Entry#PrevEntry` 3, `lru.NewList` 1, `lru.NewLRU` 1, `utils.RTrimSlice` 1.
   - Script rule: callee starts with `gorm.io/gorm` and confidence is medium. All 43 matches were checked against generic definitions (`type LRU[K comparable, V any]`, `type LruList[K comparable, V any]`, `func RTrimSlice[T any]`, …).
   - The tool's own `known_gaps` lists this ("calls into scanned generics are medium").
2. **P2: calls to a named nested function captured by another closure come out as callbacks (11 edges).**
   - `fallbackSetter` accounts for 8 edges, all from `setupValuerAndSetter$7…$16`. `appendToFieldValues` accounts for 3 (association.go:466, 480, 487).
   - Both are `x := func(...)`, and the tool itself names them as callers (`Field#setupValuerAndSetter.fallbackSetter`).
   - The calls should be `outer.f`, high, direct. Other named nested functions called only directly (`callFc`, `reguessOrErr`, `write`, `processMap`, `appendToRelations`, `getTable`, `processColumn`, `changed`, `cleanUpDeletedRelations`, `appendToResults`) are correct (34 edges).

Union of wrong edges: 54 out of 4230, so census precision is 1 − 54/4230 = **98.72%**.

Checks that found nothing:
- No builtin edges (`len`, `append`, `make`, … are absent).
- No `recv.member` or `.member` guesses.
- No empty or `<global>` callers.
- No type conversions emitted as calls.
- Every callee member name, or the `$N`/`defer func`/`go func` literal, matches its line.
- Every low edge but 3 has the matching interface edge on the same line, and those 3 are the anonymous-interface cases in G3.
- No generic type arguments in IDs.

## Missed-call patterns (recall)
- **Recall sample, 37 real calls, 0 missed, 0 non-calls:**
  - `DB#FirstOrInit` (finisher_api.go:319–342): 6 calls, all present.
  - `clause.Join#Build` (clause/joins.go:53–79): 11 calls, all present, each with its interface edge plus VTA lows.
  - `schema.GetRelationsValues` together with its nested `appendToResults` (schema/utils.go:70–105): 20 calls, all present.
- **M1: methods of generic types get no edges.** 48 methods of `g[T]`, `createG[T]`, `chainG[T]`, `execG[T]` and `setCreateOrUpdateG[T]` in generics.go have none. That is about 199 call sites by regex count (approximate; builtins excluded). generics.go has only 14 edges in total, from non-generic `preloadBuilder`/`joinBuilder` methods and `G$1`.
- **M2: in-scope `_test.go` files are not graphed.** 37 files have zero edges (for example `schema/relationship_test.go` at 1043 lines and `schema/schema_test.go` at 352 lines). I did not count the call sites.
- **M3: package-level var initializer calls are missing (39 calls).** The 2026-10-29 Go decision gives them caller `pkg.init`:
  - errors.go: 21 `errors.New`
  - logger/logger.go: 6 (`errors.New`, 2×`New`, 2×`log.New`, `time.Now`)
  - logger/sql.go: 4 (3×`reflect.TypeOf`, 1×`regexp.MustCompile`)
  - schema/field.go: 3 `reflect.TypeOf`
  - 1 `regexp.MustCompile` each in chainable_api.go:58, migrator/migrator.go:28 and schema/constraint.go:11
  - 1 `errors.New` in schema/schema.go:33
  - the IIFE `init → init$1` in statement.go:698

  Closures inside such initializers are graphed (`gorm.init$1`, `schema.init$1`), and `func init()` bodies are graphed (8 edges).

## Spec gaps (counted separately, not wrong)
- **G1: call_type for statically dispatched method calls (1781 edges).**
  - Concrete method calls (`reflect.Value#Interface`, `DB#UpdateColumns`, `strings.Builder#String`) are `direct`. Interface-dispatched calls and their VTA edges are `method` (1281).
  - The spec lists both values but does not say which one a concrete method call gets.
- **G2: recursive closures declared with `var f func(..)` and then assigned once with `f = func(...)` (19 callee edges).**
  - The callees are `convertParams` 5, `parseDependence` 4, `sortCallback` 3, `insertIntoOrderedList` 3, `getRealFieldValue` 2 and `appendFieldsToMap` 2.
  - Their bodies are named as anonymous `$N` closures and their calls are callback/unknown.
  - The spec's "bound directly to a function literal" does not say whether a separate single assignment counts. `assignValue` (callbacks/update.go:148), which is assigned one of three literals, is correctly a callback.
- **G3: method calls on anonymous interface types (3 edges).** The cases are `dialector.(interface{ Apply(*Config) error })` → `gorm.io/gorm.Apply` (high), `interface{ Ping() error }` → `gorm.io/gorm.Ping`, and `interface{ getInstance() *DB }` → `gorm.io/gorm.getInstance`. The spec's `Interface#Method` form has no name for an unnamed interface. The tool's ID looks like a non-existent free function, and the VTA lows on those lines are correct.
- **Other fields outside the judged set (not counted):**
  - 64 edges carry `is_external: true` although the callee is in the scan. These are the 43 P1 generic edges and 21 VTA lows such as `schema.serializer#Value`, `clause.Expr#Build` and `clause.Where#Name`.
  - 2 calls started by a `go` statement (internal/lru/lru.go:80 `go func(done <-chan struct{})`, internal/stmt_store/stmt_store.go:110 `go v.Close()`) have no `is_async`. The spec does not define `is_async`.
