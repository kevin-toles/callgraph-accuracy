# cppfront (cpp) call-graph review, v5

precision 48/50; census ≈93.4% (818 wrong of 12452 in-scope); recall: 0 missed of 20 real calls; 0 non-calls

**Input.** This review is based on the regenerated `cppfront.v2.json`, which adds the braces-as-written namespace fix. The earlier output I started from is saved as `cppfront.v5pre.json`; the "Previous findings" section says what changed from it.

**Scope.** 12,452 of the 112,285 edges are in scope (source/, include/, experimental/). I excluded passthrough-tests/ (70,447) and regression-tests/ (29,386).
- By confidence: high 9281, low 2648, medium 441, unknown 82.
- Compared with v4a: 749 edges changed and all 749 pair up on the same file and line, so no edge was dropped or added. Compared with v5pre: 422 edges changed.

**Changed-edge check (cppfront_v5_newsample.py, seed 5050).** I drew 36 of the 749 edges that differ from v4a and checked each against its declaration in source. All 36 are correct per spec, or are spec gaps. Examples:
- `std.basic_string#find` on `std::string const& line` (io.h:173)
- `std.basic_istream#getline` on `std::istream& in` (io.h:946)
- `std.variant#index` high on primary_expression_node's `std::variant<…> expr` (parse.h:136)
- `cpp2.binary_expression_node#lhs_is_id_expression` (sema.h:2887; alias `assignment_expression_node`)
- `std.vector#back` on `selection_stack`, declared after a local struct (sema.h:1433)
- `std.optional#has_value` under a concept bound (cpp2util.h:2127)
- `cpp2.impl.as` called from `cpp2.impl.as_` (cpp2util.h:2949; `namespace impl {` at 2792)
- `std.map#find`/`contains` on `in<std::map<…>>` (reflect.h:10776/10784)

Bare `ssize`/`get_if` are now low and bare `isspace` is now medium. See spec gaps.

Before the regeneration I had sampled 36 changed edges from v5pre. 4 of them were wrong:
- 1 `std.conditional_t#type`, still present (pattern 3)
- 3 `std.variant#index` medium, fixed in the regenerated output

**Precision sample.** Seed 20261105 (`cppfront_v5_sample.py`, saved in `cppfront_v5_sample.json`). I drew one edge per file for all 15 in-scope files, then filled each tier at random: high 30, low 10, medium 5, unknown 5. Proportional would be 37/11/3/0, so medium and unknown were raised to the 5-edge floor.
- By tier: high 30/30, low 9/10, medium 5/5, unknown 4/5.
- The 2 wrong edges: lex.h:353 `assert` and parse.h:8435 `next`.
- Six sampled edges are spec gaps, not errors:
  - 4 `std.string#<init>`: #14, #42, #43, #44
  - 2 smart-pointer `->` edges: #36, #37

  #10, bare `isspace` medium, sits under the same `<cctype>` gap.
- Verified as correct, among others:
  - `std.unordered_map#find` on `std::unordered_map<void*,Data> data` (extrinsic_storage_std_locked.h:57; gcc defines `find` in class at gcc-10-libstdc++-e.cpp:49157)
  - `cpp2.unchecked_narrow` from `main` via `using namespace cpp2;` (cppfront.cpp:37, 151)
  - `std.optional#value` on `std::optional<raw_string>& raw_string_multiline` (lex.h:627 → 1286)
  - `std.variant#index` high (parse.h:10862)
  - `std.basic_string_view#find_first_of` on member `std::string_view regex` (reflect.h:2525 → 10873)
  - callbacks `func`, `other` and `term` (lambda/`TermFunc` parameters), and `handle_error` (`const auto handle_error = emit_errors ? emit_error : skip_error;`)
  - `auto` receivers left low: `pos_ranges`, `decl`, `n->my_statement->…`

**Recall** (`cppfront_v5_recall.py`). All 20 calls in the three functions were found, and none of the edges was a non-call.
- **common.h:519 `cpp2.is_empty_or_a_decimal_number`.** 4 calls: `std::ssize`, `isspace` ×2, `isdigit`. All 4 found.
- **to_cpp1.h:2940 `cpp2.cppfront#is_pointer_declaration(type_id_node const*)`.** 8 calls: recursion ×3, `std::count_if`, `std::cbegin`, `std::cend`, `q->type()` (lambda parameter `auto* q` → `q.type` low, correct), `unchecked_narrow`. All 8 found.
- **sema.h:478 `cpp2.sema#is_captured`.** 8 calls: `std::find_if`, `symbols.begin`/`end` ×2 (`stable_vector<symbol> symbols`, 367), `s.get_global_token_order` and `t.get_global_token_order`, `std::get_if`, `sym->is_use()` (if-init `identifier_sym const* sym`). All 8 found with correct callees. The neighbouring `get_declaration_of` (sema.h:422/424) now gives `std.unordered_map#find`/`#cend`.

**Census.** Scripts: `cppfront_v5_census.py`, built on `cppfront_v5_typed.py`, `cppfront_v5_stddef.py` and `cppfront_v5_lambda.py`. Per-pattern edge sets are saved in `cppfront_v5_patterns.pkl`.
- The union is 818 wrong edges. The pattern counts add up to 850; 32 edges fall in two patterns (mostly `<global>` together with a qualified `.m` or `(*this)` edge).
- The two v4 counts that were carried without a source check (brace-init lambdas, `(*this)`/conversion operators) are now checked against source.

## Mismatch table

| file:line | source line | tool said (caller → callee, conf, type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| source/lex.h:353 | `assert (t);` | cpp2.labelized_position → assert, low, direct | assert, macro, medium (not `#define`d in scan) | other (call_type) / wrong confidence | assert not treated as a macro |
| source/parse.h:8435 | `next();` (in `iteration_statement`) | → next, unknown, callback | cpp2.parser#next, high, method (`auto next(int num = 1)` 6852); the `auto next = assignment_expression();` at 8374 is local to the lambda `handle_optional_next_clause` | wrong callee / wrong confidence | out-of-scope lambda local shadows member |
| source/reflect.h:6656 | `if (cpp2::cpp2_default.is_active() && …) { cpp2::cpp2_default.report_violation(""` | → .is_active / .report_violation, low | cpp2_default.is_active, low (`auto inline cpp2_default = contract_group(` cpp2util.h:573; receiver is a named object, not computed) | wrong callee | qualified-name receiver treated as computed |
| source/parse.h:733 | `if (!expression_node::current_expressions.empty()) {` | → .empty, low | std.vector#empty, high (`static inline std::vector<expression_node*> current_expressions` 595) | wrong callee / wrong confidence | same |
| source/reflect.h:10964 | `auto iter {change_str.begin()};` | parser_group_modifiers → std.conditional_t#begin, medium | std.basic_string#begin, high (`in<std::string> change_str`; `in<T>` = `std::conditional_t<…, T const, T const&>`, cpp2util.h:1460) | wrong callee / wrong confidence | alias expanded one level into another alias |
| include/cpp2regex.h:1362 | `{ return ctx.size(); }` | search_return#group_number → matcher_context_type#size, medium | ctx.size, low (`context<Iter> ctx` → `matcher_context_type<matcher,Iter>` → `typename matcher::template context<Iter>`, unbounded `matcher`) | wrong callee / wrong confidence | same |
| source/reflect.h:9230 | `base::traverse(expr);` | autodiff_expression_handler#traverse → base#traverse, medium | cpp2.meta.simple_traverser#traverse, high (`using base = simple_traverser;`) | wrong callee / wrong confidence | `Alias::m()` not expanded |
| source/sema.h:309 | `definite_initializations.begin(),` | → definite_initializations.begin, low | std.vector#begin, high (namespace-scope `std::vector<token const*> definite_initializations;` 302) | wrong callee / wrong confidence | namespace-scope variable type unused |
| source/parse.h:5581 | `indent_str.c_str(),` | cpp2.pre → indent_str.c_str, low | std.basic_string#c_str, high (`inline static std::string indent_str = std::string( 1024, ' ' );` 5575) | wrong callee / wrong confidence | same |
| source/common.h:1247 | `: delta { entries.empty() ? 0 : std::abs(entries.back().ptr - p) }` | → entries.empty, low | std.vector#empty, high (`static std::vector<entry> entries;` 1255, outer class, later) | wrong callee / wrong confidence | outer-class static declared after use |
| include/cpp2util.h:1551 | `dt->value() = T(CPP2_FORWARD(args)...);` | → dt.value, low; → T, low, direct | cpp2.impl.deferred_init#value, high (anonymous-union `deferred_init<T>* dt;` 1504); T#\<init\>, constructor | wrong callee / other | anonymous-union member; `T(...)` as direct |
| include/cpp2util.h:2265 | `f();` (`F f;` member, 2278) | cpp2.finally_success#~finally_success → f, high, direct | f, callback, unknown | wrong callee type / wrong confidence | stored callable matched to an out-of-scope function `f` (regression-tests) |
| include/cpp2util.h:1940 | `(c < C{}) == (x < CPP2_TYPEOF(x){})` | cpp2.impl.as → C#\<init\> high, x#\<init\> high | type parameter `C`; `x` is a parameter, not a type; not high | wrong confidence / wrong callee | matched to unrelated out-of-scope classes `C`/`x` |
| source/io.h:591 | `struct process_line_ret r { in_comment, true , in_raw_string_literal};` | → `struct process_line_ret#<init>`, medium | process_line_ret#\<init\> (no keyword, no space) | wrong callee | elaborated-type keyword kept in ID |
| source/parse.h:7231 | `typename Binary::term t{};` | → `typename Binary.term#<init>`, medium | Binary.term#\<init\> | wrong callee | `typename` kept in ID |
| source/reflect.h:5686 | `cpp2::i64 min_value {};` | → cpp2.i64#\<init\>, medium, constructor | no edge (integer value-initialization) | not a call | integer declaration as constructor |
| source/to_cpp1.h:2935 | `return is_pointer_declaration(type.get(), …)` in `[&]<typename T>(T const& type)` | → T#get, medium | type.get, low (unconstrained type variable stays low) | wrong callee / wrong confidence | unbounded type parameter named |
| source/reflect.h:3335 | `add_line(CPP2_UFCS(substr)(source, 0, newline_pos));` | → add_line, unknown, callback | …#parse_statement.add_line, high, direct (`auto add_line {[&, _1 = lines](…) mutable -> void{` 3320) | wrong callee / wrong confidence | brace-init lambda not a named nested function |
| source/lex.h:261 | `return operator std::string_view() == t.operator std::string_view();` | → operator.string_view, medium, direct; → `cpp2.token#std::string_view`, medium | cpp2.token#operator std::string_view, high (conversion operator, lex.h:255) | wrong callee / wrong confidence | conversion-operator call split |
| source/lex.h:1759 | `auto literal = std::string_view{ &line[i], std::size_t(j+1) };` | → std.size_t, medium, direct | no edge (cast) | not a call | functional cast to integer |
| source/reflect.h:3317 | `CPP2_UFCS(push_back)(generated_lines, std::vector<source_line>());` | → std.vector, medium, direct | std.vector#\<init\>, constructor, high | wrong callee / other | `std::X<…>()` construction as direct |
| source/reflect.h:3783 | (`#line` between function head and `{`) | \<global\> → parse_statement, low | caller cpp2.meta.compiler_services#… | wrong caller | `#line` between head and body |
| source/to_cpp1.h:2784 | `auto lambda_intro = std::string("[");` | → std.string#\<init\>, medium | alias rule is stated for receiver types; constructor IDs through an alias are unspecified | spec gap | alias as constructor name |
| source/sema.h:2414 | `n.declaration->name()` | → declaration.name, low | `std::unique_ptr<declaration_node>` then `->` | spec gap | smart-pointer `->` |
| source/io.h:595 | `i < ssize(line)` | → ssize, low, direct | ADL finds `std::ssize` (no using-directive in source) | spec gap | ADL |
| source/lex.h:1895 | `else if (!isspace(line[i])) {` | → isspace, medium | C `::isspace(int)` is only declared in the scan (`extern int isspace (int) throw ();` gcc:15820); low vs medium unspecified | spec gap | declared-only C library function |
| experimental/extrinsic_storage.h:134 | `instrument_access_count.fetch_add(1 M_O_RELAXED);` | → std.atomic#fetch_add, medium | msvc defines `fetch_add` only in a base (59904); gcc has only forward `struct atomic;` at the matched spots | spec gap | member of a scanned base |

## Systematic patterns (census, ordered by count)

1. **`assert` is not a macro: 506 edges.** All are direct/low; per spec they should be macro, medium. Unchanged.
2. **`<global>` caller: 110 edges.** reflect.h 77 (`#line` between head and `{`), cpp2util.h 26, common.h 4, union_test.cpp 2, parse.h 1. Unchanged.
3. **Qualified-name receiver `ns::obj.m()` emitted as computed `.m`: 102 edges.** `cpp2::cpp2_default.is_active`/`.report_violation` 92, `cpp2::type_safety.*` 2, `expression_node::current_expressions.*` 4, `expression_statement_node::current_expression_statements.*` 4. The receiver is a named object: the `current_*` ones should be `std.vector#m` high, and the `contract_group` ones are `auto`-declared, so they should be `cpp2_default.is_active` low. Pre-existing (102 in v4a as well); the v4 review missed it.
4. **Alias expanded only one level, into another alias template: 33 edges.**
   - `std.conditional_t#*` (28): the receiver is `cpp2::impl::in<X>`, whose real type is X. Correct targets include `std.basic_string#*`, `std.set#empty`, `std.map#empty`, `cpp2.taylor#get`, `cpp2.meta.object_declaration#type` and `std.basic_string_view#*`.
   - `matcher_context_type#*` (5): dependent on the unbounded `matcher`, so it should stay `ctx.m` low.

   In v4a these were `cpp2.impl.in#*` (28) and `context#*` (5), which the v4 review listed as a spec gap.
5. **Typed receivers still left `recv.m` low: 31 edges** (v4: 53).
   - `deferred_init` locals in `<global>`-caller functions in reflect.h: 12
   - namespace-scope globals `definite_initializations`/`definite_last_uses`: 8
   - `indent_str`: 1
   - `entries`: 4
   - `dt` (anonymous union): 4
   - `Name` (`string_util::fixed_string` NTTP): 2

   With paren-init declarations included, the scan finds no further cases.
6. **Brace-init lambdas `auto f {[..]}` not named nested functions: 17 edges.** `apply` callbacks 7 plus 3 body edges with the outer caller (reflect.h:10954); `add_line` 1 plus 2 (reflect.h:3320); `inner_call` bodies 2 (cpp2regex.h:1007, 1233). Now checked against source.
7. **Functional casts to integer types emitted as calls: 10 edges.** `colno_t#<init>` 5, `std.size_t#<init>` 3, `std.size_t` direct 2.
8. **`(*this).m()` and conversion-operator calls not resolved: 8 edges.** `(*this).is_active`/`report_violation` 4 (reflect.h:3780–3781), `cpp2::move(*this).func()` 1 (cpp2regex.h:960, computed, acceptable as `.func`, but counted as in v4), conversion operator 3 (lex.h:261, 267). 4 overlap pattern 2. Now checked against source.
9. **Construction `T(...)` / `std::X<…>()` emitted as direct: 7 edges.** `T` 3, `std.vector` 2, `std.optional` 1, `std.basic_string` 1.
10. **Member `next()` treated as a callback: 5 edges** (parse.h:8429…). Unchanged.
11. **`Alias::m()` qualified call not expanded: 5 edges.** `base#traverse`, where `using base = simple_traverser;`. Pre-existing; the v4 review missed it.
12. **`Ret` parameter type as callee: 4 edges** (cpp2util.h:845–854). Also counted in pattern 2.
13. **Type-parameter construction matched high to an unrelated class: 4 edges.** `C#<init>` 2, `X#<init>` 1 and `x#<init>` 1 (cpp2util.h:1788, 1940, 1988). The only definitions named C/X/x are in regression-tests or passthrough. Pre-existing.
14. **Call through stored callable member `F f;` emitted as direct high `f`: 3 edges** (cpp2util.h:2265, 2291, 2319). Should be callback/unknown. Pre-existing.
15. **Keyword kept in type ID: 2 edges.** `struct process_line_ret#<init>`, `typename Binary.term#<init>`. Pre-existing.
16. **Integer declaration `cpp2::i64 x {}` as constructor: 2 edges.** Pre-existing.
17. **Unconstrained type parameter named as `T#m` medium: 1 edge** (to_cpp1.h:2935). This was a spec gap in v4; the updated spec now says it stays low.

## Spec gaps (not counted)

- **Constructor named through an alias: 300 edges.** `std.string#<init>` 248, `std.string_view#<init>` 26, `std.true_type`/`false_type` 9, `std.ofstream` 5, `token_vec` 5, `token_ptr` 2, `context` 2, `word_class` 1, `std.stringstream` 1, `std.string.size_type` 1.
  - The alias sentence sits in the typed-receiver rule. Receivers now expand (e.g. `std.basic_string#size` high), but `Type#<init>` keeps the alias name, medium.
  - If the alias rule covers constructors too, these 300 are wrong and the census would be ≈91.0% (1118/12452).
- **Smart-pointer `->`: 143 `recv.m` low edges,** e.g. `n.declaration->name()`.
- **`auto x = T(...)` / `auto x = T{}` / `auto& x = std::get<…>(…)` locals: 659 `recv.m` low.** The spec types only `= new T(...)`.
- **ADL-resolved bare calls: 27 edges.** `ssize` 11, `get` 8, `get_if` 8, now low (were high through namespace-less libstdc++ IDs).
- **Declared-only C `<cctype>` functions: 15 edges, bare `isspace`/`isdigit`/`isxdigit`/`isalpha`, medium.** The spec does not say low vs medium for a prototype without a body.
- **`std.*` medium with a borderline scan definition: 14 edges.**
  - `std.atomic#fetch_add` 6: base `_Atomic_integral` in msvc
  - `std.chrono.high_resolution_clock.now` 2: an alias whose target differs per STL (`steady_clock`/`system_clock`)
  - `std.basic_ostringstream#str` 2: defined as `std.__cxx11.basic_ostringstream#str`, an inline namespace
  - `std.filesystem.*` 4: friend declarations / ctor
- **Members inherited by a typed receiver's class.** `std.runtime_error#what` medium (parse.h:6719, to_cpp1.h:1242): gcc only declares it in `runtime_error`, while msvc inherits it from `exception` (defined 28549). The "Superclass#m" rule is written for `self.m()` only.
- **Type-parameter construction, medium: 17 edges** (`R#<init>` 11, `T#<init>` 6).
- **Macro-declared parameter `where`: 3 edges.**
- **UFCS dispatch.** Only the macro edge is emitted (1,479 `CPP2_UFCS*` macro edges).
- **Repeated calls on one line collapse.**

## Previous findings

### Relative to v5pre (output before the namespace-from-braces fix)

| item | v5pre | final | status |
|---|---|---|---|
| cpp2util.h namespace loss (callers after ~2255, `range#m`, `impl.cmp_*`) | 86 | 0 | fixed: `cpp2.finally#<init>`, `cpp2.range#front`, `cpp2.impl.cmp_less`, `cpp2.unchecked_div`… |
| Callers in `namespace impl` 1722–2235 named `cpp2.is`/`cpp2.as` | 25 | 0 | fixed (now `cpp2.impl.is`/`cpp2.impl.as`). These were never counted by v4 |
| `cpp2.impl.*` defined in the scan but medium | 91 | 0 | fixed (high) |
| `std.*` medium although defined (variant#index 86, setw 16, numeric_limits 16, max/min 12, …) | 169 | 0 counted (14 borderline, spec gap) | fixed. The gcc/clang passthrough definitions now carry `std.` (gcc callers with prefix `std`: 19,609) |
| Typed `unordered_map`/`map` receivers resolved to msvc base `std._Hash#m`/`std._Tree#m` | 10 | 0 | fixed (`std.unordered_map#find`, `std.map#contains`, high) |
| Bare `isspace`/`isdigit`/… high (matched to `std::isspace(c, locale)`) | 15 | 0 | fixed (now medium; spec gap) |
| Bare `ssize`/`get`/`get_if` high | 27 | 0 high | changed to low (spec gap, ADL) |
| `contains` in cppfront.cpp (via `using namespace cpp2`) | 1 bare | `cpp2.contains` | fixed |
| `std.ios_base#eof` (io.h) | — | `std.basic_ios#eof` | changed; correct |
| Census | 1179 wrong (90.53%) | 818 (93.43%) | improved |
| Precision sample | 43/50 | 48/50 (same seed, redrawn) | improved |

### Mismatch-table rows of v4

| v4 row | status | evidence |
|---|---|---|
| union_test.cpp:82 `std.source_location#line` medium | fixed | high |
| to_cpp1.h:5108/5111 `std.variant#index` medium | fixed | high |
| cpp2util.h:2270 caller `finally_success#<init>` | fixed | `cpp2.finally_success#<init>` |
| cpp2util.h:1551 `T(...)` direct | still present | `T`, low, direct (pattern 9) |
| reflect.h:3335 `add_line` callback | still present | pattern 6 |
| sema.h:216 `std.variant #index` (space) | fixed | `std.variant#index`, high |
| parse.h:208 `std.vector #empty` | fixed | `std.vector#empty`, high |
| cpp2util.h:2034 `X#index` | fixed | `std.variant#index`, high |
| cpp2util.h:2065 `X#has_value` | fixed | `std.any#has_value`, high |
| sema.h:1290 `selection_stack.pop_back` | fixed | `std.vector#pop_back`, high |
| sema.h:309 `definite_initializations.begin` | still present | pattern 5 |
| common.h:1247 `entries.empty` | still present | pattern 5 |
| cpp2util.h:1549/1551 `dt.value` | still present | pattern 5 |
| sema.h:492 `sym.is_use` | fixed | `cpp2.identifier_sym#is_use`, high |
| lex.h:1759 `std.size_t` direct | still present | pattern 7 |
| reflect.h:3317 `std.vector` direct | still present | pattern 9 |
| sema.h:2886 `assignment_expression_node#…` (alias spec gap) | fixed | `cpp2.binary_expression_node#is_standalone_expression`, high |
| reflect.h:10586 `token_vec#insert` (alias spec gap) | fixed | `std.vector#insert`, high |
| to_cpp1.h:2935 `T#get` (spec gap in v4) | still present, now wrong under the updated spec | pattern 17 |
| cpp2util.h:561 `where.file_name` (spec gap) | still a spec gap | 3 edges |

### Systematic patterns of v4

1. **`assert` not a macro (506)**: still present, 506.
2. **`std.*` medium although defined (267)**: fixed. 267 → 169 in v5pre → 0 counted. 14 borderline edges are now a spec gap.
3. **`<global>` caller (110)**: still present, 110.
4. **`cpp2.impl.*` defined but medium (91)**: fixed, 0.
5. **cpp2util.h namespace loss (86)**: fixed, 0. Also fixed: 25 `cpp2.is`/`cpp2.as` callers inside `namespace impl` that v4 never counted.
6. **Typed receivers left `recv.m` (53)**: partly fixed, 31 left. Fixed: `selection_stack` 15, `loop_stack` 4, `thds`, `sym`, `suffix2`. Remaining: see pattern 5.
7. **Space before `#` (10)**: fixed, 0. A related pre-existing issue remains: 2 IDs keep the keyword `struct`/`typename` (pattern 15).
8. **Brace-init lambdas (17)**: still present, 17, now checked against source.
8b. **`(*this)` / conversion operator (8)**: still present, 8, now checked against source.
9. **Concept-constrained `X#m` (7)**: fixed, 0. They now resolve to `std.variant`/`std.optional`/`std.any`.
10. **Functional casts to integer types (10)**: still present, 10.
11. **`T(...)` / `std::X<…>()` construction as direct (7)**: still present, 7.
12. **Member `next()` as callback (5)**: still present, 5.
13. **`Ret` as callee (4)**: still present, 4.

v4 spec gaps:
- **Type aliases.** The receiver side is fixed: std.string/string_view/istream/ofstream methods (146 in v4a) and `token_vec` (22), `word_class` and `assignment_expression_node` all resolve now. Two parts are not:
  - `cpp2.impl.in#*` (28) and `context#*` (5) became pattern 4 (wrong).
  - Constructors through alias names (300) are still a spec gap.
- **Smart-pointer `->`**: still a spec gap, 143.
- **Unbounded type parameters**: now covered by the spec. 5 `recv.m` low are correct; 1 `T#get` is wrong.
- **Members through a scanned base**: still a spec gap.
- **`auto x = T(...)` locals**: still a spec gap.
- **Macro-declared `where`**: still a spec gap, 3.
- **UFCS dispatch**: still a spec gap, 1,479 macro edges.
- **Repeated calls collapse**: still a spec gap.

Other v4 items:
- **Doubled namespaces.** `std.std.*` IDs dropped from 5,748 in v4a to 2 in the whole graph. Both are out of scope: `std.std.std.complex → __visibility__` at gcc-10-libstdc++-e.cpp:121247 and clang-12:120174, where `namespace __gnu_cxx __attribute__ ((__visibility__ ("default")))` is reported as a call.
- **Census, like for like.** v4 1153 wrong (90.7%) → 818 (93.43%). Restricted to v4's pattern set it is 678. The final union also includes 119 pre-existing wrong edges in patterns the v4 review missed: patterns 3, 11, 13, 14, 15, 16, and pattern 17, which v4 classed as a spec gap. It also includes the 33 alias-to-alias edges (pattern 4).
