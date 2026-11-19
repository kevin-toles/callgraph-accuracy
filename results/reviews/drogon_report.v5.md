# drogon (cpp) call-graph review, v5 (after the alias, using-directive, lambda-scope, paren-init and brace-namespace fixes)

precision 50/50; census ≈94.0% (688 wrong of 11528 in-scope); recall: 2 missed of 110 real calls; 0 non-calls

(50/50 = 41 correct + 9 spec gaps. None of the 50 sampled edges is wrong.)

**Input.** This review uses `drogon.v2.json` as it was regenerated during the review (the namespace-from-braces fix). The earlier output is saved as `drogon.v5pre.json`. Between the two, exactly 8 in-scope edges changed, all in `lib/inc/drogon/HttpFilter.h:100-126`:
- the caller `HttpCoroFilter#doFilter` became `drogon.HttpCoroFilter#doFilter`;
- the callee `internal.handleException` (medium) became `drogon.internal.handleException` (high; it is defined at HttpBinder.h:185);
- the callee `HttpCoroFilter#doFilter` became `drogon.HttpCoroFilter#doFilter`.

All 8 are correct against the source. I re-ran every script on the regenerated file. The sample, the new-edge sample, the recall edges and every census count came out identical to the v5pre run; only the 8 HttpFilter.h edges differ.

## Scope and changes

**In scope.** 22,725 edges in total; 11,528 are in scope. Excluded: test/, tests/, examples/, third_party/, cmake/, and non-C++ files.
- By confidence: medium 5288, low 4058, high 1996, unknown 186.
- By call_type: method 7252, direct 3225, constructor 829, callback 186, macro 36.

**Changes since v4a.** 421 edges are new and 422 are gone. Every new edge sits on a line that also lost an edge.

| change | edges |
|---|---|
| `recv.m` low → typed (std.string 80, std.vector 41, std.filesystem.path 21, std.string_view 14, std.weak_ptr 14, drogon.HttpViewData 13, drogon.Cookie 13, drogon_ctl.Relationship 7, drogon.ConfigLoader 6, others) | 243 |
| alias expanded: SafeStringMap → std.unordered_map (Utilities.h:579 is `std::unordered_map<std::string, T, …>`), SessionMap/AttributesMap → std.map, `*Ptr#get` → std.shared_ptr, handle_type → std.coroutine_handle, DrTemplateData → drogon.HttpViewData, CIDRs → std.vector, ViewDataMap → std.unordered_map | ~105 |
| namespace added through using-directives: DrTemplateBase 20, HttpViewData 18, DrogonDbException 9, string_view 5, string 2, Result 2, HttpRequest 2, HttpClient 1, `utils.splitString/formattedString` → `drogon.utils.*` high (7, direct) | 66 |
| HttpFilter.h caller/callee namespace (brace fix) | 8 |

**New-edge verification.** I took a hand sample of 36 changed edges with seed 52 (`drogon_v5_newsample.py`). For each one I opened the use line and its declaration (parameter, field, local, init-capture, or alias target). All 36 are correct.

The sample covered:
- paren-init locals: `std::filesystem::path baseName(logfileBaseName_)`, `std::ofstream file(wPath, …)`, `ConfigLoader loader(fileName)`;
- locals declared after a lambda in `addHeader`;
- captured `std::weak_ptr` locals;
- `const DrTemplateData &tableInfo` → `drogon.HttpViewData#get`, high;
- `headers_` (SafeStringMap) → `std.unordered_map#find`.

**The 206 edges v4 could not judge** (148 chains and 58 fields) are now all judged:
- **58 `f_.m` fields:** 54 wrong, 4 spec gap. The gaps are Mapper.h `client_->type()`, a `DbClientPtr` reached through `->`.
- **148 `x.f_.m` / `p->f_.m` chains:**
  - 142 are correctly low. The head is `auto` (`auto thisPtr = weakPtr.lock()`, `auto &cmd = …`, range-for `auto &location`), a call result, or an index.
  - 4 are spec gaps (heads typed `std::shared_ptr<…>`).
  - 2 are wrong: coroutine.h:866 and 870, through `Self *self`.

## Precision sample

Seed 51, stratified by confidence: medium 21, low 16, high 8, unknown 5, across 34 files (`drogon_v5_sample.py`, `drogon_v5_sample.json`). Every line number is correct.
- Pass (41): includes #6 `value.find` → `std.string#find` (paren-init local, newly fixed), #44 `e.base()` → `drogon.orm.DrogonDbException#base` high (v4's sample #13, now fixed), and #47 caller `drogon.orm.CoroMapper#findByPrimaryKey.lb` (named lambda `auto lb = […]`, inner lambda folded in).
- Spec gap (9):
  - #25, #26, #30, #32, #34: smart-pointer `->`;
  - #35, #36: template parameter `T` (`T(r[0])`, `T &obj`);
  - #41: `ComparsionResult{…}` is aggregate init of a struct with no constructor, emitted as a high constructor;
  - #3: `std::istreambuf_iterator<char>()`, a temporary of an external type emitted as a direct call.
- Wrong (0).

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/src/HttpRequestParser.cc:151 (64 edges in 3 files) | `auto *space = std::find(buf->peek(),` | → `MsgBuffer#peek`, medium, method | `trantor.MsgBuffer#peek`, medium. The parameter is `MsgBuffer *buf` (line 143). The file's using-directives are `using namespace trantor;` (25, the only one outside the scan) and `using namespace drogon;` (26). | wrong callee | using-directive to an out-of-scan namespace not applied, even though it is the only one. HttpServer.cc (3 edges) has two out-of-scan directives, so honest low applies there. |
| lib/src/YamlConfigAdapter.cc:11 (12 edges) | `if (node.IsNull())` | `YAML.yaml2json` → `Node#IsNull`, medium | `YAML.Node#IsNull`, medium (`const Node &node` inside `namespace YAML {`, line 7) | wrong callee | enclosing namespace not applied to the type (the caller has it) |
| lib/inc/drogon/utils/Utilities.h:588 | `ls.append(v.data(), v.length());` | `trantor.operator<<` → `LogStream#append`, medium | `trantor.LogStream#append` (inside `namespace trantor {`, line 583) | wrong callee | enclosing namespace not applied |
| orm_lib/src/postgresql_impl/PgBatchConnection.cc:553 (30 edges) | `batchCommandsForWaitingResults_.clear();` | → `batchCommandsForWaitingResults_.clear`, low | `std.list#clear`, medium. The field is `std::list<std::shared_ptr<SqlCmd>> batchCommandsForWaitingResults_;` (PgConnection.h:142). | wrong callee + confidence | fields declared inside `#if LIBPQ_SUPPORTS_BATCH_MODE … #else … #endif` (PgConnection.h:140-153; `batchSqlCommands_` std::deque, `preparedStatementsMap_` std::unordered_map in both branches) not typed |
| lib/src/HttpAppFrameworkImpl.cc:188 (6 edges) | `sharedLibManagerPtr_.reset();` | → `sharedLibManagerPtr_.reset`, low | `std.unique_ptr#reset`, medium. Also `libFilePaths_` → `std.vector`, `libFileOutputPath_` → `std.string`. | wrong callee + confidence | fields inside `#if !defined(_WIN32) && !TARGET_OS_IOS` (HttpAppFrameworkImpl.h:712-716) not typed |
| lib/src/MultipartStreamParser.cc:121 (18 edges) | `buffer_.append(data, length);` | → `buffer_.append`, low | `drogon.MultipartStreamParser.Buffer#append`, high (`struct Buffer { … } buffer_;`, MultipartStreamParser.h:49-62; defined at .cc:314) | wrong callee + confidence | field whose type is declared inline in the same declaration not typed |
| lib/inc/drogon/utils/coroutine.h:900 (7 edges) | `if (tasks_.empty())` | `…WhenAllAwaiter<std::vector<Task<T>>>#await_suspend` → `tasks_.empty`, low | `std.vector#empty`, medium (`std::vector<Task<T>> tasks_;`, same specialization) | wrong callee + confidence | fields of explicit/partial specializations not typed. Line 921 of the same function does resolve `self->exceptionFlag_` → `std.atomic_flag`. |
| lib/inc/drogon/utils/coroutine.h:870 (and 866) | `if (self->counter_.fetch_sub(1, std::memory_order_acq_rel) == 1)` | → `counter_.fetch_sub`, low | `std.atomic#fetch_sub`, medium. `Self *self`, where `using Self = WhenAllAwaiter<Tasks...>;` is local (line 846) and the field is `std::atomic<size_t> counter_;`. | wrong callee + confidence | function-local alias not expanded (same root as the next row) |
| lib/inc/drogon/utils/coroutine.h:867 (3 edges) | `self->setException(std::current_exception());` | → `Self#setException`, medium | `drogon.CallbackAwaiter#setException`, high (inherited, as line 922 already resolves) | wrong callee + confidence | local alias `Self` not expanded |
| orm_lib/src/Result.cc:66, Row.cc:118 | `iterator_type tmp(*this);` | → `iterator_type#<init>`, medium | `drogon.orm.ConstResultIterator#<init>` / `ConstRowIterator#<init>`, high (`using iterator_type = ConstRowIterator;`, RowIterator.h:119) | wrong callee + confidence | member alias not expanded |
| lib/src/Redirector.cc:29 (3 edges) | `return HttpResponsePtr{};` | → `HttpResponsePtr#<init>`, constructor | `std.shared_ptr#<init>`, medium | wrong callee | alias not expanded for a constructor call |
| lib/inc/drogon/utils/coroutine.h:284 (and 294) | `coro_.destroy();` | `drogon.Task<void>#~Task` → `coro_.destroy`, low | `std.coroutine_handle#destroy`, medium (`handle_type coro_;` with `using handle_type = std::coroutine_handle<promise_type>;`, line 267) | wrong callee + confidence | alias-typed field in a specialization not typed |
| lib/src/HttpAppFrameworkImpl.cc:1181 (3 + 1 edges) | `sizeLimit = std::numeric_limits<std::size_t>::max();` | → `std.numeric_limits.max`, medium, direct | `std.numeric_limits#max` (`Class::static()` → `Class#static`; the template argument makes the qualifier a class). Also `std::coroutine_handle<promise_type>::from_promise` (coroutine.h:389). | wrong callee | static member of an external class template named as a dotted function |
| drogon_ctl/create_view.cc:40 (3 edges) | `std::string::size_type pos(0);` | → `std.string.size_type#<init>`, constructor | no edge (scalar typedef initialization) | not a call | like `pid_t#<init>` (v4 pattern 9) |
| lib/src/HttpFileImpl.cc:36 (recall; 11 lines, 22 calls) | `std::filesystem::path fsUploadDir(utils::toNativePath(path));` | no edge | `std.filesystem.path#<init>`, constructor, plus `drogon.utils.toNativePath`, high | missed call ×2 | a declaration `T x(ns::f(y));` whose single argument is a qualified call gets no edges. The local is still typed (line 38 resolves). The same form with two arguments (`std::ifstream infile(utils::toNativePath(fullPath), std::ifstream::binary);`) works. |
| lib/src/Cookie.cc:29 (11 sites) | `(std::numeric_limits<int64_t>::max)() &&` | no edge | `std.numeric_limits#max`, medium | missed call | parenthesized callee name (unchanged) |
| lib/src/HttpRequestImpl.cc:1052 | `assert(loop_->isInLoopThread());` | → `assert`, low, direct | call_type macro | other (call_type) | unchanged |
| lib/inc/drogon/utils/monitoring/StopWatch.h:69 | `callback_(stopWatch_.elapsed());` | → `callback_`, low, direct | callback, unknown | wrong confidence + call_type | unchanged |
| lib/src/WebSocketConnectionImpl.cc:214 (14 edges) | `void WebSocketConnectionImpl::WebSocketConnectionImpl::shutdown(` | caller `WebSocketConnectionImpl.WebSocketConnectionImpl#shutdown` | `drogon.WebSocketConnectionImpl#shutdown` | wrong caller | redundant injected-class-name qualifier; unchanged |
| lib/inc/drogon/HttpFilter.h:59 | `auto mcbPtr = std::make_shared<MiddlewareCallback>(std::move(mcb));` | caller `<global>` | `drogon.HttpFilterBase#invoke` | wrong caller | unchanged |
| lib/src/HttpAppFrameworkImpl.cc:584 | `if (sigaction(SIGINT, &sa, NULL) == -1)` | → `sigaction#<init>`, constructor | `sigaction`, low, direct | wrong callee + call_type | unchanged |
| lib/inc/drogon/utils/coroutine.h:922 | `self->setException(std::current_exception());` | caller `drogon.internal.WhenAllAwaiter<std::vector<Task<T>>>#await_suspend` | `drogon.internal.WhenAllAwaiter#await_suspend` | wrong caller | template arguments kept in the caller ID; unchanged |
| drogon_ctl/create_view.cc:136 (26 edges) | `std::string newLine = line.substr(pos + cxx_lang.length());` | → `cxx_lang.length`, low | `static const std::string cxx_lang = "<%c++";` (line 26) is a namespace-scope variable | spec gap | decision A lists locals, parameters, fields, catch, for-loop and pattern bindings, not file-scope variables. v4 counted 6 of these as wrong. |
| lib/src/SlidingWindowRateLimiter.cc:23 (25 edges) | `std::chrono::duration<double>(` | → `std.chrono.duration`, medium, direct | a temporary of an external type (or a functional cast, `std::size_t(20000)`) | spec gap | the spec does not say how to name an external qualified name used as `T(...)` |
| lib/inc/drogon/utils/monitoring/StopWatch.h:28 (16 edges) | `start_(std::chrono::steady_clock::now())` | → `std.chrono.steady_clock.now`, direct | `std.chrono.steady_clock#now` if the qualifier is known to be a class | spec gap | external class versus namespace cannot be told apart without template arguments |
| lib/src/Hodor.cc:78 and others (703) | `rejectResponse_->setBody(` | → `rejectResponse_.setBody`, low | `->` through a smart pointer | spec gap | as specified |

## Recall

| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| `HttpRequestImpl::addHeader` (lib/src/HttpRequestImpl.cc:409-511) | 44 | 44 | 0 | 0 |
| `HttpFileImpl::save(const std::string &)` (lib/src/HttpFileImpl.cc:31-82) | 26 | 24 | 2 (line 36: the `std::filesystem::path` constructor and `utils::toNativePath`) | 0 |
| `HttpAppFrameworkImpl::setupFileLogger` (lib/src/HttpAppFrameworkImpl.cc:1145-1239) | 40 | 41 | 0 | 0 (+1 spec gap: `std::size_t(20000)` cast emitted as direct `std.size_t`) |

**What was not counted as a call:** operators, object-like `LOG_*` macros, copy-initialization without parentheses, and same-line duplicates (collapsed).

**Notes on these functions.**
- `addHeader` was fully low in v4. It is now fully typed: every `value`, `coo`, `cookie_name` and `cookie_value` edge is `std.string#…`, medium, and `headers_.emplace` is `std.unordered_map#emplace`.
- In `setupFileLogger`, the remaining low edges are correct or spec gaps:
  - correctly low: `auto fsLogPath = …` → `fsLogPath.native`; range-for `auto &sink`; `auto logger`;
  - spec gaps: `asyncFileLoggerPtr_->…` (shared_ptr `->`) and the init-captures `loggerPtr->`.
- In `setupFileLogger`, `std::numeric_limits<std::size_t>::max()` is `std.numeric_limits.max` (pattern 10).

## Systematic patterns (scripted counts, ordered by count; wrong union 688)

1. **`assert` emitted as a direct call, not a macro: 259.** Unchanged.
2. **Calls through a function value emitted as direct, not callback/unknown: 99.** Unchanged (`idleCb_` 13, `advice` 9, `closeCallback_` 8, …).
3. **Namespace dropped from IDs: 96.**
   - Callees, 80: `MsgBuffer#` 64, `Node#` 12, `LogStream#` 1, `TcpServer#<init>` 1, `YAML#Load` 1, `Json#writeString` 1.
   - Callers, 16: `WebSocketConnectionImpl.WebSocketConnectionImpl#` 14, and 2 `ConstReverseIterator#base`.
4. **`shared_from_this()` is low, not medium: 92.** Unchanged.
5. **Typed fields and field chains still emitted as `recv.m` low: 63.** These were previously unjudged.
   - preprocessor-guarded fields: PgConnection 30, HttpAppFrameworkImpl 6;
   - inline-declared struct field `Buffer … buffer_`: 18;
   - fields in `WhenAllAwaiter` specializations: 7;
   - `Self *self->field` chains: 2.
6. **Template-specialization arguments kept in IDs: 43.** Unchanged; 42 callers, 1 callee.
7. **`<global>` caller on real calls: 21.** Unchanged.
8. **Aliases not expanded: 10.**
   - `Self#` 3 and `iterator_type#<init>` 2: function-local or member aliases;
   - `HttpResponsePtr#<init>` 3: constructor through an alias;
   - `coro_.destroy` 2: alias-typed field.
9. **Declarations emitted as calls: 7.** Unchanged.
10. **Scalars or functions emitted as constructors: 7.** `sigaction` ×2, `stat`, `pid_t`, `std.string.size_type` ×3.
11. **Static member of an external class template named as a dotted function: 4.** `std.numeric_limits.max` 3, `std.coroutine_handle.from_promise` 1.

**Missed-call patterns** (recall, not counted in census precision):
- `T x(ns::f(y));`: 11 lines, 22 calls. Lines: HttpFileImpl.cc:36/87, StaticFileRouter.cc:162/240/480/497/513, HttpAppFrameworkImpl.cc:449/697/700, HttpBinder.h:85.
- Parenthesized callee `(std::numeric_limits<…>::max)()`: 11 sites (`drogon_v5_paren.py`).

## Spec gaps (counted separately; 832 edges not also wrong)

- **Smart-pointer `->` receivers: 703.** v4 had 691; the extra 12 come from the newly judged chains and fields (`binderPtr`, `paramPack`, `resultPtr`, Mapper `client_`) and `subCtx`.
- **Receivers typed by a template parameter: 33** (including `Pack &&pack` ×3).
- **Namespace-scope variables as receivers: 26.**
  - `static const std::string cxx_*` in create_view.cc 7, `customMime` 4, `fileTypeDatabase_`/`mimeTypeDatabase_` 7, `base64CharMap` 4, `registeredTests`/`allTestRan` 4.
  - Decision A does not list file-scope variables.
- **External qualified type used as `T(...)`, either a temporary or a functional cast, emitted as direct: 25.**
  - `std.chrono.duration` 11, `std.chrono.seconds` 4, `std.size_t` 4, `std.filesystem.path` 2, `std.istreambuf_iterator` 2, `std.filesystem.directory_iterator` 1, `std.locale` 1.
- **Static members of external classes without template arguments, named with dots: 16.** `std.chrono.steady_clock.now` 9, `std.thread.hardware_concurrency` 7.
- **Default-argument callers: 15.**
- **Aggregate initialization emitted as a constructor: 9.** `z_stream#<init>` 3, `ComparsionResult#<init>` 6 (high, but no constructor exists).
- **Pure-virtual callees left medium: 9.**
- **`auto x = T(...)` left low: 1** (PgListener.cc:327).
- **Same-line duplicate calls** are collapsed.

## Previous findings (v4)

### Mismatch-table rows from v4

| v4 row | status | evidence (v5) |
|---|---|---|
| create_model.cc:571 `e.base()` (`DrogonDbException`) | **Fixed** | `drogon.orm.DrogonDbException#base`, high; all 9 edges |
| HttpRequestParser.cc:151 `MsgBuffer#peek` | **Still present** | 64 `MsgBuffer#` edges, the same count as v4 |
| create_filter.cc:41 `HttpViewData#insert` | **Fixed** | `drogon.HttpViewData#insert`, high (18 edges) |
| YamlConfigAdapter.cc:11 `Node#IsNull` | **Still present** | 12 edges |
| SlashRemover.cc `string_view#` / `string#` | **Fixed** | `std.string_view#size` etc. (7 edges) |
| HttpResponseImpl.cc:870/872 `cookie.key` | **Fixed** | `drogon.Cookie#key`, high (13 edges) |
| HttpRequestImpl.cc:425 `addHeader` (paren-init and later locals) | **Fixed** | 0 low edges in the function (recall above) |
| HttpControllersRouter.cc:460 `parametersPlaces.begin` | **Fixed** | `std.vector#begin` |
| HttpAppFrameworkImpl.cc:381 `deps.append` | **Fixed** | `Json.Value#append` |
| StaticFileRouter.cc:152 `restOfThePath.rfind` | **Fixed** | `std.string_view#rfind` |
| coroutine.h:870 `counter_.fetch_sub` | **Still present** | low (pattern 5). The root cause is now the unexpanded local alias `Self`. |
| HttpRequestImpl.cc:1052 `assert` | **Still present** | 259 edges |
| StopWatch.h:69 `callback_` | **Still present** | 99 edges |
| Cookie.cc:29 parenthesized callee | **Still present** | 11 sites missed |
| coroutine.h:922 caller template arguments | **Still present** | 43 edges |
| create_project.cc:47 `DrTemplateBase#newTemplate` | **Fixed** | `drogon.DrTemplateBase#newTemplate`, high (20 edges) |
| HttpFilter.h:59-67 `<global>` | **Still present** | `<global>` → `std.make_shared`; 21 wrong `<global>` edges |
| HttpAppFrameworkImpl.cc:584 `sigaction#<init>` | **Still present** | — |
| HttpRequestImpl.cc:381 `SafeStringMap#begin` (spec gap) | **Fixed** | `std.unordered_map#begin/end` |
| Hodor.cc:116 `RealIpResolver.CIDRs#emplace_back` (spec gap) | **Fixed** | `std.vector#emplace_back` |
| Hodor.cc:78, HttpAppFrameworkImpl.cc:745 smart-pointer `->` | Spec gap, unchanged | — |

### Systematic patterns from v4

| v4 pattern | status | v4 count | v5 count |
|---|---|---|---|
| 1. `assert` as direct | **Still present** | 259 | 259 |
| 2. Typed locals still low | **Fixed** | 238 | 0 locals. All 89 paren-init, 10 brace-init, 14 in-scan-class and 124 of 137 qualified locals are retyped. The 13 left are 7 specialization fields (moved to pattern 5) and 6 namespace-scope `static` strings (reclassified as spec gap). |
| 2b. Unjudged chains and fields | **Judged** | 206 not judged | 56 wrong (54 fields + 2 `Self*` chains), 8 spec gap, 142 correct |
| 3. Namespace dropped | **Partly fixed** | 165 | 96. Fixed 69: DrTemplateBase 20, HttpViewData 18, DrogonDbException 9, `HttpCoroFilter` callers 8 + 1 callee, string_view 5, string 2, Result 2, HttpRequest 2, HttpClient 1, `internal.handleException` 1. `HttpResponsePtr#<init>` 3 moved to pattern 8. LogStream 1 was newly counted (present in v4a). Still present: `MsgBuffer` 64, `Node` 12, WebSocketConnectionImpl callers 14, and 5 singles. |
| 4. Function value called as direct | **Still present** | 99 | 99 |
| 5. `shared_from_this` low | **Still present** | 92 | 92 |
| 6. Template-specialization arguments in IDs | **Still present** | 43 | 43 |
| 7. `<global>` caller | **Still present** | 21 | 21 |
| 8. Declarations as calls | **Still present** | 7 | 7 |
| 9. Functions or scalars as constructors | **Still present** | 4 | 7 (+3 `std.string.size_type`, present in v4a but not counted then) |
| 10. Parenthesized callee missed | **Still present** | ≥1 | 11 (now scripted) |
| Spec gap: alias IDs as written | **Fixed → mostly** | 107 + 12 | 0 left as gaps. Under the updated spec, 10 remaining unexpanded aliases are counted wrong (pattern 8). |
| Spec gap: smart-pointer `->` | Unchanged | 691 | 703 (+12 from newly judged chains and fields) |
| Spec gap: template parameter | Unchanged | 30 | 33 |
| Spec gap: default argument / aggregate init / pure virtual | Unchanged | 15 / 3 / 9 | 15 / 9 (ComparsionResult 6 newly counted) / 9 |
| New this round | — | — | wrong: patterns 5 (fields), 8, 11; missed-call `T x(ns::f(y))` (22 calls). Spec gaps: namespace-scope variables 26, external `T(...)` 25, dotted static members 16. |

Census precision went from 92.0% (921 of 11,529, with 206 unjudged) to 94.0% (688 of 11,528, all judged).

Scripts are in the fanout folder:
- `drogon_v5_load.py`, `drogon_v5_overview.py`, `drogon_v5_diff.py`, `drogon_v5_redo.py` (diff against v5pre);
- `drogon_v5_sample.py` (with `drogon_v5_sample.json`), `drogon_v5_newsample.py` (with `drogon_v5_newsample.json`);
- `drogon_v5_typed.py`, `drogon_v5_residual.py`, `drogon_v5_resid_list.py`, `drogon_v5_chain.py`, `drogon_v5_globals.py`, `drogon_v5_undet.py`, `drogon_v5_prevres.py`;
- `drogon_v5_ns.py`, `drogon_v5_alias.py`, `drogon_v5_cb.py`, `drogon_v5_paren.py`, `drogon_v5_vexing.py`;
- `drogon_v5_recall.py`, `drogon_v5_prev.py`, `drogon_v5_census.py` (with `drogon_v5_census.pkl`).
