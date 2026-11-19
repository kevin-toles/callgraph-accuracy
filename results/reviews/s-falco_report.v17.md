# s-falco (cpp): blind call-graph review, round 17

precision 50/50; census ≈98.8% (106 wrong of 8887 in-scope); recall: 0 missed of 41 real calls; 0 non-calls

## Scope
The tool JSON has 10,083 edges. I kept the 8,887 edges whose `source_file` is C++ (`.cpp` 8,436 and `.h` 451). None of those paths has a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment. `unit_tests/` is not one of the excluded names, so it is in scope (SPEC Decisions 2026-11-09). I left out the Go and Python edges (chart/, e2e/, tools/).

The 8,887 in-scope edges come from 122 files:
- **By confidence:** high 3,276, medium 4,528, low 1,062, unknown 21.
- **By call_type:** method 4,937, macro 1,778, direct 1,648, constructor 503, callback 21.

**Sample:** seed 17, stratified by tier: high 17, medium 22, low 6, unknown 5. It covers 34 files, with at most 2 edges per file per tier. I ignored the `measured_accuracy` field. All scripts are in the fanout folder with the prefix `s-falco_r17_` (load, sample, show, dotrecv, chain, ctorasfn, nestedctor, lowtyped, autocall, autofield, fieldrecv, medscan, recall, census, gaps).

## Precision sample
None of the 50 edges is wrong: every one is a real call, with the correct caller, callee, tier and line. One is a spec gap:
- **S44**, `list_plugins.cpp:41`, `configs.size` (low). `configs` is `const auto& configs = s.config->m_plugins;`: an `auto` local bound to a field of declared type `std::vector<plugin_config>`. See G2.

These samples were checked against definitions and passed:
- **gtest bodies and fixtures:** S2, S5, S47, S49, S50.
- **Named callback locals:** S46–S50. `auto action = falco::app::actions::…` gives callback/unknown.
- **File-static and global-namespace callers:** S14 `configure_output_format`, S15 `read_file`.
- **Typed call results:** S19, `get_unknown_macros()` returns `const std::vector<value_info>&`, so `std.vector#begin`.
- **Index receivers left low:** S41, S43. The element type is only knowable from `std::vector::operator[]`, which is outside the scan.

## Mismatch table
Every row was found by the census or by looking; none came from the sample. There is one or more rows per pattern.

| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| unit_tests/engine/test_filter_macro_resolver.cpp:230 | `filter_ast::pos_info a_macro_pos(32, 84, 9);` | TestBody → `filter_ast.pos_info#<init>` (medium, constructor) | `libsinsp.filter.ast.pos_info#<init>` (medium) | wrong callee | `namespace filter_ast = libsinsp::filter::ast;` not expanded in declared types. In the same file `filter_ast::and_expr::create` IS expanded (C2) |
| unit_tests/engine/test_filter_macro_resolver.cpp:67 | `ASSERT_TRUE(filter->is_equal(expected.get()));` | → `filter_ast.expr#is_equal` (medium, method) | `libsinsp.filter.ast.expr#is_equal` | wrong callee | namespace alias in the receiver's declared type |
| userspace/engine/filter_details_resolver.cpp:44 | `filter->accept(&v);` | `filter_details_resolver#run` → `ast.expr#accept` (medium) | `libsinsp.filter.ast.expr#accept` | wrong callee | `ast::expr` not resolved through `using namespace libsinsp::filter;` |
| userspace/falco/falco_metrics.cpp:148 | `{{"file_name", fs_path.filename()}, …` | → `fs.path#filename` (medium) | `std.filesystem.path#filename` | wrong callee | `namespace fs = std::filesystem;` not expanded. Other files give `std.filesystem.path#<init>` (C1) |
| userspace/falco/configuration.h:399 | `if(!node.IsMap()) {` | `YAML.convert#decode` → `Node#IsMap` (medium) | `YAML.Node#IsMap` | wrong callee | `const Node&` inside `namespace YAML {` not qualified by the enclosing namespace. Elsewhere `YAML.Node#Scalar` |
| unit_tests/engine/test_filter_warning_resolver.cpp:53 | `filter_warning_resolver().run(ctx, res, ast);` | warns_ast → `.run` (low, method) | `filter_warning_resolver#run` (high) | wrong callee/confidence | a temporary `T()` receiver is not typed, although the same line has the `filter_warning_resolver#<init>` edge |
| userspace/engine/falco_engine.cpp:595 | `filter_details_resolver().run(ast.get(), details);` | → `.run` (low) | `filter_details_resolver#run` (high) | wrong callee/confidence | same |
| userspace/falco/webserver.cpp:68 | `falco::versions_info(state.offline_inspector).as_json().dump();` | → `.as_json` (low), `.dump` (low) | `falco.versions_info#as_json` (high); `nlohmann.json#dump` (medium; `as_json` declares `nlohmann::json`) | wrong callee/confidence | same; `print_version.cpp:31` `info.as_json().dump()` gives `nlohmann.json#dump` (C2) |
| userspace/falco/app/restart_handler.cpp:107 | `auto parent = std::filesystem::path(f).parent_path();` | → `.parent_path` (low) | `std.filesystem.path#parent_path` (medium) | wrong callee/confidence | temporary of a named external type not typed |
| userspace/engine/falco_engine.cpp:581 | `auto ast = libsinsp::filter::parser(info.cond).parse();` | → `libsinsp.filter.parser` (medium, direct) and `.parse` (low) | `libsinsp.filter.parser#<init>` (constructor) and `libsinsp.filter.parser#parse` (medium) | wrong callee / call_type | functional-notation construction emitted as a free-function call. The same ID is `#<init>` elsewhere (C2) |
| userspace/engine/rule_loader_collector.cpp:87 | `ex.comps.items.push_back(rule_loader::rule_exception_info::entry("="));` | → `rule_loader.rule_exception_info#entry` (medium, method) | `rule_loader.rule_exception_info.entry#<init>` (high, constructor); `struct entry` is at rule_loader.h:454 | wrong callee / call_type / confidence | nested-type construction read as a member call |
| userspace/engine/yaml_helper.h:207 | `void clear() { m_root = YAML::Node(); }` | → `YAML#Node` (medium, method) | `YAML.Node#<init>` (medium, constructor) | wrong callee / call_type | namespace read as a type |
| userspace/engine/falco_engine.cpp:78 | `return sinsp_version(FALCO_ENGINE_VERSION);` | → `sinsp_version` (low, direct) | `sinsp_version#<init>` (medium, constructor); the tool itself emits `sinsp_version#<init>` at rule_loader_collector.cpp:171 | wrong callee / call_type | external type in functional notation |
| userspace/falco/falco_outputs.cpp:252 | `m_queue.clear();` | → `m_queue.clear` (low) | `tbb.concurrent_bounded_queue#clear` (medium) | wrong callee/confidence | field type `falco_outputs_cbq` is a class-member `typedef tbb::concurrent_bounded_queue<ctrl_msg>`, not expanded. stats_writer.cpp's `m_queue` (written `tbb::…`) is typed |
| userspace/falco/stats_writer.cpp:435 | `… = m_writer->m_engine->get_rules();` | → `m_engine.get_rules` (low) | `falco_engine#get_rules` (high) | wrong callee/confidence | field chain through `std::shared_ptr<stats_writer> m_writer` → `std::shared_ptr<const falco_engine> m_engine` not typed. `m_writer->m_libs_metrics_collectors.find` on nearby lines is typed |
| userspace/falco/app/actions/start_webserver.cpp:64 | `state.webserver.start(state, webserver_config);` | → `webserver.start` (low) | `falco_webserver#start` (high) | wrong callee/confidence | field `falco_webserver webserver;` (state.h:115) is declared inside `#if !defined(__EMSCRIPTEN__) && !defined(MINIMAL_BUILD)` and is not used for typing |
| userspace/engine/falco_utils.cpp:102 | `s_rgx_prometheus_time_duration.NamedCapturingGroups();` | → `s_rgx_prometheus_time_duration.NamedCapturingGroups` (low) | `re2.RE2#NamedCapturingGroups` (medium) | wrong callee/confidence | file-scope `static re2::RE2 …` (line 38) not used for typing (Decisions 2026-10-29) |
| userspace/falco/app/actions/print_syscall_events.cpp:136 | `events_bc.print_all(*formatter);` | → `events_bc.print_all` (low) | `events_by_category#print_all` (high) | wrong callee/confidence | the declaration `struct events_by_category events_bc = …` (elaborated type specifier) is not read |
| userspace/falco/app/app.cpp:104 | `res = falco::app::run_result::merge(res, func(s));` | → `func` (low, direct) | `func` (unknown, callback) | wrong confidence / call_type | range-for variable over `std::list<app_action>` holding a function |
| userspace/falco/app/restart_handler.cpp:255 | `should_restart = m_on_check();` | → `m_on_check` (low, direct) | `m_on_check` (unknown, callback) | wrong confidence / call_type | stored `std::function` property |
| userspace/engine/yaml_helper.h:62 | `cb(cur);` | `yaml_visitor#operator()` → `cb` (low, direct) | `cb` (unknown, callback) | wrong confidence / call_type | `Callback cb` member (a `std::function`) |
| userspace/engine/indexable_ruleset.h:237 | `if(wrap->event_codes().empty()) {` | → `filter_wrapper#event_codes` (low) | `wrap.event_codes` (low) | wrong callee | `filter_wrapper` is the class template parameter, not a type. The same function's `wrap->tags()` gives `wrap.tags` (C2) |
| userspace/falco/app/actions/pidfile.cpp:95 | `if(dprintf(fd, "%lld\n", (long long)getpid()) < 0) {` | → `getpid` (high, direct) | `getpid` (libc, not high) | wrong confidence | resolved to the macro node of `#define getpid _getpid`. That define is in the `#else` (Windows) branch of unit_tests/falco/app/actions/test_pidfile.cpp:28, which pidfile.cpp does not include |
| unit_tests/falco/test_reload_control_runtime.cpp:189 | `if(HasFailure()) {` | `ReloadControlRuntimeTest#TearDown` → `HasFailure` (low, direct) | `ReloadControlRuntimeTest#HasFailure` (medium, method) | wrong callee/confidence | member inherited from `testing::Test` (outside the scan) |
| userspace/falco/stats_writer.h:88 | `stats_writer::ticker_t m_last_tick = std::numeric_limits<ticker_t>::max();` | `userspace/falco/stats_writer` → `std.numeric_limits#max` | caller `stats_writer.collector#m_last_tick` | wrong caller | instance field initializer (open defect cpp/10) |

## Systematic patterns (scripted census, `s-falco_r17_census.py`; union 106)
Each pattern was hand-checked on at least 3 edges, or on all of them where there are fewer.

1. **Namespace alias, using-directive or enclosing namespace not resolved in a declared type: 46.**
   - The prefixes are `filter_ast.*` (24), `fs.*` (8), `Node#*` inside `namespace YAML` (8) and `ast.*` medium (6).
   - These violate C1 (one external type gets two IDs) and C2 (`filter_ast::and_expr::create` in the same file is expanded).
2. **Call on an in-place temporary `T(args).m()` left as `.m` low: 19.**
   - 12 have the `T#<init>` edge on the same line: `filter_details_resolver`, `filter_warning_resolver`, `falco::atomic_signal_handler`, `falco::versions_info`, `std::filesystem::path`.
   - 6 are on external-type temporaries: `libsinsp::filter::parser(...).parse()`, `sinsp_filter_compiler(...).compile()`, `nlohmann::json(output).dump()`.
   - 1 is a cascade: `versions_info(...).as_json().dump()`.
3. **Receiver with a declared type left low: 17.**
   - `m_queue` through a class-member typedef: 4.
   - `m_writer->field->m` smart-pointer field chains: 5.
   - `state.webserver` / `state.reload_control`, fields declared under `#if`: 5.
   - File-scope `static re2::RE2`: 2.
   - `struct T x = …` declaration: 1.
4. **Construction in functional notation emitted as a direct/method call instead of `T#<init>`: 12.**
   - `libsinsp.filter.parser` 4, `sinsp_version` 3, `nlohmann.json` 2, `sinsp_filter_compiler` 1, `rule_loader.rule_exception_info#entry` 1, `YAML#Node` 1.
5. **Function-holding variable or member called, emitted low/direct instead of callback/unknown: 4.**
   - `func` ×2, `m_on_check`, `cb`. The tool gets this right for parameters (`predicate`, watchdog `cb`) and for named locals (`action`).
6. **Class template parameter used as a type ID: 4.**
   - `filter_wrapper#event_codes`.
7. **`getpid` high/direct resolved through an unrelated file's conditional macro: 2.**
   - pidfile.cpp:95 and test_restart_handler.cpp:144.
8. **Bare call of a member inherited from the gtest base outside the scan: 1.**
   - `HasFailure`.
9. **Instance field initializer with the file as caller: 1.**
   - stats_writer.h:88. This matches open defect cpp/10.

census precision = 1 − 106/8887 = 98.81%

## Missed-call patterns (recall)
None of the 41 calls in the three recall functions was missed:
- `falco::app::actions::list_plugins`, list_plugins.cpp:26–43: 8 calls.
- `rule_loader::collector::define(configuration&, plugin_version_info&)`, rule_loader_collector.cpp:168–181: 8 calls.
- `falco::app::restart_handler::watcher_loop`, restart_handler.cpp:175–316: 25 calls, including the macros `FD_ZERO`, `FD_SET` and `FD_ISSET`, and `gettid` (`#define`d in that file).

`m_on_check()` is present but mis-typed (pattern 5). Missed calls found outside the recall functions:
- **File-scope object constructions with arguments get no constructor edge: 4.**
  - `static re2::RE2 s_rgx_identifier(RGX_IDENTIFIER, re2::RE2::POSIX);` (rule_loader_reader.cpp:47).
  - `s_rgx_barestr` (rule_loader_reader.cpp:48).
  - `s_rgx_prometheus_time_duration` (falco_utils.cpp:38).
  - `ip_address_re` (configuration.cpp:46).
  - Function-local `static re2::RE2 …(…)` does get `re2.RE2#<init>` (falco_metrics.cpp:267).
- **The implicit `<init>` → field edge is missing for the stats_writer.h:88 initializer: 1.** This is open defect cpp/10.

## Spec gaps (not counted as wrong)
- **G1. Function-like macros from headers outside the scan: 22 edges.**
  - These are `S_ISSOCK` 6, `htole16` 5, `htole32` 3, `PPM_API_VERSION_MAJOR/MINOR/PATCH` 6, `PPME_IS_ENTER` 1, `ASSERT` 1. All are emitted low/direct.
  - Other system macros are emitted as macro/medium: `S_ISLNK`, `FD_SET`, `WIFEXITED`.
  - Construct: `return S_ISSOCK(second.st_mode) && …` (reload_control.cpp:51).
  - Question: when a callee is a function-like macro defined only in an external header (system or libscap/libsinsp), is it call_type `macro` or `direct`, and at which tier? This is the same question CAPABILITIES c/13 leaves open for C; SPEC has no C++ ruling.
- **G2. `auto` local bound to a field access rather than a call: 5 edges, plus sample S44.**
  - Construct: `const auto& configs = s.config->m_plugins; … configs.size()`.
  - Question: the 2026-11-12 let-bound rule types a local bound to a *call result*, and decision A types `obj.field` chains. Does an `auto` local initialized from a field of declared type take that field's type?
- **G3. Argument-dependent lookup: 1 edge.**
  - Construct: `rule_info["priority"] = format_priority(r.priority, false);` in falco_engine.cpp:569. There is no using-directive for `falco_common`. `r.priority` is `falco_common::priority_type`, so ADL finds the scanned `falco_common::format_priority`. The tool emits a bare `format_priority`, low.
  - Question: must a bare C++ call be resolved through ADL to a scanned namespace function (high), or does it stay a bare low guess?
- **G4. `->` on `std::optional`: 1 edge.**
  - Construct: `if(arg && !arg->empty())` with `const std::optional<std::string>& arg` (filter_details_resolver.cpp:27), emitted `arg.empty` low.
  - Question: the smart-pointer rule lists `unique_ptr`/`shared_ptr`/`T*`. Does an `optional<T>`'s `->` name the pointee `T`?
- **G5. Object-like macro under a preprocessor conditional, used as a function name: 3 edges.**
  - Construct: in test_pidfile.cpp, `#else … #define getpid _getpid … #endif`, then `getpid()`. The tool emits `getpid` (high, macro).
  - Question: SPEC defines `macro` for function-like macros. Is `getpid()` here a macro edge, or the libc call of the non-Windows branch (and with which callee and tier)?
- **G6. Default-initialized class objects: no edge emitted (recall side; seen 2 times in the recall functions).**
  - Construct: `std::ostringstream os; sinsp inspector;` (list_plugins.cpp:31–32).
  - Question: the default constructor runs with no written call. Is that a `T#<init>` constructor edge, an `implicit` edge, or no edge?
