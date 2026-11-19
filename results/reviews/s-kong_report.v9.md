# s-kong (lua) blind call-graph review, round 9

precision 49/50; census ≈99.47% (103 wrong of 19409 in-scope); recall: 0 missed of 34 real calls; 0 non-calls

(The one sample edge not counted correct is a spec gap, not a wrong edge: 0 of 50 sampled edges are wrong.)

## Scope
Tool output `<scans>/final12-A/s-kong.v2.json` has 99,241 edges. 97,602 come from `.lua` files; the rest are go/py/rs/js and are ignored. After dropping Lua edges under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment (Kong's `spec/` tree holds about 78k of them), **19,409 edges are in scope**. They come from 520 files under `kong/`, `scripts/`, `autodoc/` and `build/`.
- Confidence: medium 10,165, high 4,922, low 4,063, unknown 259.
- call_type: direct 16,349, method 2,801, callback 259.
- Pairs: medium/direct 10,073, high/direct 4,622, low/method 2,409, low/direct 1,654, high/method 300, unknown/callback 259, medium/method 92.

Sample: seed 9 (`random.seed(9)`), stratified medium 24 / high 12 / low 9 / unknown 5, spread over 43 files. The `measured_accuracy` field was ignored. Helper scripts are in the fanout folder, prefixed `s-kong_r9_`. The census script is `s-kong_r9_census.py` and the spec-gap counts come from `s-kong_r9_gaps.py`.

Sample result: 49 edges correct, 1 spec gap (#15: `scripts/changelog-helper.lua:117`, the lua/15 module ID of an unrequired entry script), 0 wrong. These were checked and found correct:
- Lua call_type by written form (`:` gives method, `.` and bare give direct). Scripted over 15,615 unambiguous edges with 0 mismatches.
- Aliases: `local fmt = string.format` gives `string#format`, and `local run_hook = hooks.run_hook` gives `kong.hooks#run_hook` high.
- Forward-declared and `do`-block locals: `kong.pdk.log.serialize`, `kong.db.errors.each_foreign_field`.
- Nested local functions (`kong.conf_loader.load.find_dynamic_keys`) and function-local tables (`kong.globalpatches.SharedDict#flush_expired`).
- Folding of table-constructor and anonymous functions into the enclosing function or module.
- Literal receivers (`("(%s)"):format` gives `.format` low) and unknown receivers (`kong.log.warn` gives `log.warn` low).
- Callbacks through parameters and through locals bound to an index or call result.

A scripted line check found no edge on a line without a call token. No high edge has a callee missing from `nodes`, and no caller is empty or `<global>`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| kong/api/routes/certificates.lua:23 | `return endpoints.handle_error(err_t)` | `kong.api.routes.certificates.prepare_params` → `kong.api.endpoints#handle_error`, medium, direct | → `kong.api.endpoints.handle_error`, high, direct. Endpoints is `local Endpoints = { handle_error = handle_error, … }`, `return Endpoints`, and `handle_error` is `local function handle_error` (endpoints.lua:117/873/896). In-file calls already use `kong.api.endpoints.handle_error` (20 edges), so one definition gets two IDs (C1). The same construct written `return { from_hex = from_hex }` (propagation/utils.lua) resolves to the local function, high (C2). | wrong callee + wrong confidence | Constructor-field alias not followed when the constructor is bound to a local and then returned |
| kong/cmd/stop.lua:9 | `log.disable()` | `kong.cmd.stop.execute` → `log.disable`, low, direct | → `kong.cmd.utils.log#disable`, high, direct. `local log = require "kong.cmd.utils.log"`, and that module defines `function _M.disable()` and ends `return setmetatable(_M, {…})`. | wrong callee + wrong confidence | Module returned through `setmetatable(X, mt)` is not recognised as the module table |
| kong/cmd/utils/log.lua:54 (and every edge whose caller is in `_M.set_lvl/disable/enable/log`) | `args[i] = tostring(args[i])` | caller `kong.cmd.utils.log._M#log` | caller `kong.cmd.utils.log#log` (`_M` is the returned table: `return setmetatable(_M, …)`) | wrong caller | same |
| kong/cmd/utils/log.lua:90 | `return _M.log(_LEVELS.info, ...)` | `kong.cmd.utils.log` → `kong.cmd.utils.log._M#log`, high | → `kong.cmd.utils.log#log`, high | wrong callee | same |
| kong/deprecation.lua:77 | `return deprecation.raise(...)` | `kong.deprecation` → `kong.deprecation.deprecation#raise`, high | → `kong.deprecation#raise` (`return setmetatable(deprecation, {…})`) | wrong callee | same |
| kong/globalpatches.lua:651 | `require "kong.deprecation".init(options.cli)` | `kong.globalpatches` → `.init`, low, direct | → `kong.deprecation#init`, high. The same inline form `require "kong.pdk.tracing".new()` does resolve, to `kong.pdk.tracing#new`. | wrong callee + wrong confidence | same |
| kong/db/declarative/export.lua:126 | `local sorted_schemas, err = schema_topological_sort(schemas)` | `kong.db.declarative.export.export_from_db_impl` → `kong.db.schema.topological_sort`, medium, direct | → `kong.db.schema.topological_sort.schema_topological_sort`, high. The module ends `return schema_topological_sort`, a `local function`, and C1 says a require binding reaches the definition's one ID. | wrong callee + wrong confidence | require of a module that returns a named local function stops at the module ID |
| kong/runloop/balancer/targets.lua:513 | `local newQuery, err, try_list = dns_client.resolve(target.name, nil, cacheOnly)` | `kong.runloop.balancer.targets.queryDns` → `kong.resty.dns.client#resolve`, high | → `kong.resty.dns.client.resolve`, high (`_M.resolve = resolve`, client.lua:1604, `local function resolve` at 1165). The only `kong.resty.dns.client#resolve` definitions are spec-file mocks (`client.resolve = function` in spec/01-unit/09-balancer/*). | wrong callee | A test mock outranks the module's own alias of its local function |
| kong/resty/dns/client.lua:1571 | `local targetIp, targetPort, tryList = toip(host, port)` | `kong.resty.dns.client.connect` → `toip`, unknown, callback | → `kong.resty.dns.client.execute_toip`, high, direct (`local toip = execute_toip`, line 1544, never reassigned; Decisions 2026-10-29 Lua alias) | wrong callee + call_type + confidence | Plain local alias of a local function not followed |
| kong/plugins/statsd/log.lua:73 | `for _, range in ipairs(status_code_list) do` | `kong.plugins.statsd.log.is_in_range` → `ipairs`, unknown, callback | → `_G#ipairs`, medium, direct (`local ipairs = ipairs` declared twice, lines 11 and 14, both the builtin) | wrong callee + call_type + confidence | A redeclared identical alias is treated as an unknown value |
| scripts/changelog-helper.lua:117 (sample #15) | `error(stderr)` | caller `scripts.changelog-helper.shell_run` | undecided (lua/15) | spec gap | Module ID of an entry script no require names |

## Systematic patterns (scripted counts, ordered by count)
1. **B: `return setmetatable(X, mt)` module tables are not the module (49 edges).** Seen in `kong.cmd.utils.log` (`_M`) and `kong.deprecation` (`deprecation`).
   - Caller IDs are `mod.X#f` instead of `mod#f`: 20 edges.
   - In-file callees are `mod.X#f`: 3 edges.
   - Calls through `local log = require "kong.cmd.utils.log"` to defined members (`log.disable`, `log.enable`, `log.set_lvl`) are left low `log.f`: 25 edges.
   - Inline `require "kong.deprecation".init` gives `.init` low: 1 edge.

   The 2026-11-12 final5 C2 reading names `setmetatable({ … }, mt)` as a module's returned table, and `setmetatable` returns its first argument. Hand-checked: log.lua:31/37/44/49/88, deprecation.lua:46/55/75, cmd/stop.lua, cmd/config.lua, conf_loader/init.lua:350/542.
2. **A: constructor-field aliases of local functions in a bound-then-returned table (43 edges).** Every case is `kong.api.endpoints` (`local Endpoints = { handle_error = handle_error, select_entity = select_entity, … }; return Endpoints`), called from `kong/api/routes/*`. The tool resolves the same alias in `return { … }` constructors (294+107 cross-file edges, for example `from_hex`) and in `T.f = localfn` assignments (`kong.runloop.wasm`, `kong.plugins.ldap-auth.asn1.asn1_put_object`). Script: `s-kong_r9_alias.py`. Hand-checked: endpoints.lua:117/871-896, routes/certificates.lua:23, routes/consumers.lua:23, routes/plugins.lua:84.
3. **C: require of a module returning a named local function (5 edges).** `kong.db.schema.topological_sort` (3) and `kong.db.migrations.migrate_path_280_300` (2) are called as the module ID at medium instead of `mod.<localfn>` at high. No in-scope edge resolves this form. Script: `s-kong_r9_modcall.py`.
4. **E: plain aliases reported as callbacks (5 edges).**
   - `toip` (dns/client.lua:1571, 1594): 2 edges.
   - Redeclared `local ipairs = ipairs`: 3 edges (statsd/log.lua:73, 376; api_helpers.lua:166, where line 158 re-aliases the file-level alias inside the function). The same file's other `ipairs` calls resolve to `_G#ipairs`.

   Script: `s-kong_r9_cbalias.py`. Aliases whose target is itself an unknown-receiver member (`local escape_literal = connector.escape_literal`) were judged correct as callbacks and are not counted.
5. **D: test mock chosen over the module's own definition (1 edge):** targets.lua:513 (above).

Union: 103 edges, with no overlap between patterns. Census precision = 1 − 103/19,409 = **99.47%**.

## Missed-call patterns (recall)
Recall functions:
- `kong.runloop.balancer.balancers#create_balancers` (balancers.lua:243-267): 9 calls.
- `kong.plugins.request-transformer.access.transform_querystrings` (access.lua:234-272): 9 calls.
- `kong.db.strategies.postgres.connector._mt#query` (connector.lua:510-575): 16 calls.

All 34 calls are present on the right line, with the right callee form and call_type. There are no non-calls. `self:m()` on a table that defines `m` gives `_mt#m` high, method.

Outside the three functions:
- **Unscanned hidden directory:** `.ci/luacov-stats-aggregator.lua` has no edges. It holds 16 real calls (4 `require`, `lfs.dir`, `folder:find`, `luacov_stats.load`, `print`, `luacov_runner.load_config`, `ipairs`, `pairs`, 2 `f_name:sub`, `luacov_runner.save_stats`, `luacov_reporter.report`). CAPABILITIES.md lists only vendor/, node_modules/, build output and fetched dependencies as unsupported, so this is a recall gap with no coverage note. It is not counted in precision.
- No other missed-call pattern was found. The 91 other in-scope `.lua` files without edges hold only SQL or template strings, or data tables.

## Spec gaps (counted separately, never wrong; 637 edges in union)
- **G1, lua/15, unrequired entry scripts (213 edges).** Files: `scripts/changelog-helper.lua`, `autodoc/cli/generate.lua`, `autodoc/pdk/generate.lua`, `autodoc/pdk/ldoc/filters.lua`, `build/luarocks/luarocks_wrap_script.lua`, with callers like `scripts.changelog-helper.shell_run`. The question SPEC leaves open: what is the module ID of a file no require string names? Is it the dotted path, the basename, or something else? (CAPABILITIES lua/15.) Many `kong/` files are named only by computed requires (`require("kong.cmd." .. cmd_name)`, `fmt("kong.db.strategies.%s", …)`); their dotted-path IDs equal the runtime names, so they are not counted here.
- **G7, patches and mocks stored on a global library table (130 edges).** `ngx#get_phase` 48, `ngx#exit` 41, `os#getenv` 22, `ngx#sleep` 19, all high. Their only definitions are `ngx.exit = function() end` and `ngx.sleep = function(s)` in kong/globalpatches.lua:46/73 (a CLI patch), and `ngx.get_phase = function()` and `os.getenv = function()` in spec/ mocks. Open question: the global-table rule ("a global: `T#f`") names these patches, which makes every production call high. The 2026-11-10 ruling that a mock or patch on a library table is not the library's definition covers only locals bound to `require`, and the Lua note puts the standard library (`os`) at medium. Which applies to a function stored on an external global table (`ngx`, `os`)?
- **G5, module fields that alias another module's member or hold a value (134 edges).** Examples: `_M.uuid = uuid.generate_v4` (`kong.tools.uuid#uuid` 14), `_M.get_current_hash = declarative_import.get_current_hash`, `getenv = os.getenv` in a returned constructor, `typedefs.port = Schema.define { … }` (a callable table), all medium `mod#f`. The 2026-11-12 C2 reading makes these fields module members, so the IDs are not invented. Open question: the Lua/Zig alias ruling covers only a local or const alias. Should a call through a field alias resolve to the alias target, and what tier and call_type does a call of a field bound to a non-function value (a call result, a table) get?
- **G2, calls through a `__call` metamethod (73 edges).**
  - `log(…)`, where `kong.cmd.utils.log` returns `setmetatable(_M, { __call = function … })`: 45 edges.
  - `conf_loader(…)`: 23 edges.
  - `deprecation(…)`: 2 edges.
  - `sb_kong(…)`: 1 edge.
  - `log.deprecation(…)`: 1 edge, where the field holds the module.

  All are medium, direct, with the module ID as callee. Open question: what is the callee of calling a table whose metatable defines `__call` (the module ID, the anonymous `__call` function folded into the module, or a callback), and at what tier?
- **G6, `self:m()` in a colon method where `m` is defined neither on that table nor on a static superclass (65 edges).** Examples: `_SNIs:check_list_is_new` calling `self:select_by_name`, and `_mt:init_worker` calling `self:escape_identifier`. The DAO and connector methods are mixed in at runtime. The tool emits `self.m`, low. Open question: does the ID rule "`self.m()` → `Type#m`" apply when `m` is not a member of the enclosing table (giving `T#m` at some tier), or does it stay the `obj.f` guess?
- **G4, function literals as fields of a returned table constructor (9 edges).** Examples: `return { init = function(kong_conf) … }` in kong/reports.lua and `hash = function` in basic-auth/crypto.lua. The bodies' calls fold into the module, and calls of them are `kong.reports#init`, medium. Open question: is such a field a named definition (`mod#f`, its own caller ID, high when called) or an anonymous function that folds?
- **G8, reassigned local aliases (9 edges).** Example: `local re_find = ngx.re.find` (traditional.lua:15), later reassigned in a test-mode block (`re_find = mock_ngx.re.find`, line 267). Also `get_method` and `get_headers`. All are callback, unknown. Open question: does the Lua alias ruling apply to a local that is reassigned to another function later in the file?
- **G3, calling a module that returns an anonymous function (4 edges).** Examples: `kong_error_handlers(ctx)` gives `kong.error_handlers`, medium, and `on_the_fly_migration(dc_table)` gives `kong.db.declarative.migrations.route_path`. Open question: the returned `function(ctx)` has no name and its body's caller is the module ID. Is a call of it `mod` at high (it is defined in the scan), at medium, or something else?
