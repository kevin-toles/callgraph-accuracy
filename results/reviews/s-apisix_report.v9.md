# Blind call-graph review: s-apisix (lua), round 9

precision 49/50; census ≈98.65% (207 wrong of 15381 in-scope); recall: 0 missed of 28 real calls; 0 non-calls

## Scope
Tool output `<scans>/final12-A/s-apisix.v2.json` has 16,994 edges. 15,381 have a `.lua` source file. None of them is under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment. apisix's test tree is `t/`, which is in scope, as are `example/` and `benchmark/`. All 15,381 are in scope: 13,896 under `apisix/`, 1,470 under `t/`, 9 under `example/` and 6 under `benchmark/`, across 381 files.

| | count |
|---|---|
| Confidence | high 4,570 · medium 6,888 · low 3,744 · unknown 179 |
| call_type | direct 13,443 · method 1,759 · callback 179 |

The precision sample has 50 edges: high 14, medium 20, low 11, unknown 5. They were drawn with `random.Random(9)`, one draw per tier, and cover 42 files. Of the 50, 43 are correct, 6 depend on a spec gap and are not counted as wrong (#12, #29, #32 and #33 are t/lib module IDs, #34 is a field alias, #42 is `ngx.req`), and 1 is wrong (#39). I ignored `measured_accuracy`. Helper scripts are in the fanout folder under the `s-apisix_r9_*` prefix.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| apisix/plugins/zipkin.lua:36 (sample #39) | `local lrucache = core.lrucache.new({` | apisix.plugins.zipkin → `lrucache.new`, low, direct | `core.lrucache` is the field `lrucache = require("apisix.core.lrucache")` of the table that apisix/core.lua returns. `new` is a field of the table constructor that lrucache.lua returns (`new = new_lru_fun`), so the call is a member of a scanned module (2026-11-12 final5 reading). The tool itself emits `apisix.core.lrucache#new`, medium, for the same function in apisix/core/schema.lua:25 (`lrucache.new(...)` through a direct require). | wrong callee / wrong confidence | Through the `core.X` chain, a constructor-field member of `apisix.core.lrucache` is not resolved. That breaks C2 and C4. |
| apisix/ssl.lua:27 | `local cert_cache = core.lrucache.new {` | apisix.ssl → `lrucache.new`, low | `apisix.core.lrucache#new`, as in schema.lua | wrong callee | Same as above |
| apisix/plugins/cors.lua:260 | `multiple_origin, err = core.lrucache.plugin_ctx(` | → `lrucache.plugin_ctx`, low | `apisix.core.lrucache#plugin_ctx` (constructor field `plugin_ctx = plugin_ctx`) | wrong callee | Same as above |
| apisix/plugins/prometheus/exporter.lua:818 | `metrics.llm_latency:observe(tonumber(vars.apisix_upstream_response_time),` | apisix.plugins.prometheus.exporter#http_log → `tonumber`, unknown, callback | `_G#tonumber`, medium, direct. The file declares `local tonumber = tonumber` twice (lines 19 and 52), and both are aliases of the same builtin (Lua/Zig alias decision, 2026-10-29). | wrong callee / confidence / call_type | A duplicated top-level alias is treated as an unknown value. |
| apisix/discovery/consul_kv/init.lua:141 | `for _, node in ipairs(data) do` | → `ipairs`, unknown, callback | `_G#ipairs`, medium, direct (`local ipairs = ipairs` on lines 25 and 32) | wrong callee / confidence / call_type | Same as above |
| t/lib/fixture_loader.lua:127 | `local content, err = _M.load(fixture_name)` | `t.lib.fixture_loader#dispatch` → `t.lib.fixture_loader#load`, high | `lib.fixture_loader#dispatch` → `lib.fixture_loader#load`. The scan's require strings name this file `lib.fixture_loader` (`require("lib.fixture_loader")` in t/lib/server.lua:819/970 and t/lib/ai_cache_mock.lua:25). | wrong caller / wrong callee | The definition-side module ID ignores the require name. |
| t/lib/server.lua:977 | `local content, err = fixture_loader.load(fixture_name)` | t.lib.server#aliyun_moderation → `lib.fixture_loader#load`, **medium** | `lib.fixture_loader#load`, **high**, because it is defined in the scan | wrong confidence | C1: the reference uses `lib.…` but the node is `t.lib.…`, so the call never reaches the definition. |
| t/lib/server.lua:522 | `local openid_data = t.read_file("t/plugin/openid-connect/configuration.json")` | → `lib.test_admin#read_file`, medium | `lib.test_admin#read_file`, high (node exists as `t.lib.test_admin#read_file`) | wrong confidence | Same C1 split as above |
| apisix/cli/apisix.lua:37 | `local env = require("apisix.cli.env")(apisix_home, pkg_cpath_org, pkg_path_org)` | only `_G#require` | `_G#require`, plus an edge for calling the loaded module's value | missed call | A call on a `require(...)` result is dropped (C4). This is recall, not precision. |
| t/lib/test_redis.lua:134 (sample #12) | `release(red, host, port, opts)` | `t.lib.test_redis.flush_single` → `t.lib.test_redis.release`, high | Depends on the module ID of a file no require names: `t.lib.test_redis` or `lib.test_redis` | spec gap | CAPABILITIES lua/15 |
| t/lib/server.lua:930 (sample #42) | `ngx.print(ngx.req.get_body_data() or "{}")` | → `req.get_body_data`, low, direct | Is it `ngx.req#get_body_data`, medium, or a low guess? | spec gap | `ngx.req` is a global external table that apisix/patch.lua:420 patches. |
| apisix/core/config_etcd.lua:1170 (sample #34) | `table.insert(curr_dir_data, etcd_apisix.kvs_to_node(item))` | → `apisix.core.table#insert`, medium | Should the call name the field `apisix.core.table#insert` or the alias target `table#insert`? | spec gap | Module-table field alias (`insert = table.insert`) |

The other 43 sample edges are correct. They include:
- The `_G#require` medium direct edges.
- Aliases resolved to their targets (`str_byte` → `string#byte`, `worker_id` → `ngx.worker#id`, `original_check_ssl_conf` → `apisix.ssl#check_ssl_conf`, high).
- `_M.gcd = gcd` resolved to `apisix.core.math.gcd`, high.
- Object-literal methods folding into the module (`apisix.patch` for `luasocket_wrapper = { send = function … }`).
- Receiver guesses on locals bound to call results.
- Callbacks through lrucache-produced locals and parameters, unknown.
- `core.log.error` → `log.error`, low. This is correct because apisix/core/log.lua defines its levels only through `setmetatable(_M, {__index = function …})`, so there is no static member.

## Systematic patterns (scripted census, union 207)
1. **Required t/lib module named `t.lib.X` at its definition and `lib.X` at its references: 104 edges** (`s-apisix_r9_census.py`, P3).
   - This affects `t/lib/test_admin.lua` and `t/lib/fixture_loader.lua`.
   - Every edge with a caller or callee `t.lib.test_admin…` or `t.lib.fixture_loader…` (96 callers, 9 callees in-file) is wrong, plus the 8 cross-file references `lib.{fixture_loader,test_admin}#…` emitted at medium instead of high.
   - It violates C1: two IDs for one definition.
   - Hand-checked: fixture_loader.lua:127, server.lua:522, server.lua:977, ai_cache_mock.lua:42.
2. **Members of `apisix.core.lrucache` reached through `core.lrucache.<f>` left as low `lrucache.<f>`: 92 edges** (`s-apisix_r9_chain.py`).
   - The breakdown is `new` 66, `plugin_ctx` 18, `global` 3, `plugin_ctx_id` 3, `init_worker` 2.
   - All five are fields of the table constructor that lrucache.lua returns. The same member through a direct require resolves (`apisix.core.lrucache#new`, schema.lua:25), so the low guess breaks C2.
   - The script resolves the written chain `core.lrucache` → `apisix/core.lua`'s returned table → `apisix/core/lrucache.lua`, and checks that `f` is a static member. It found no other `core.X` or required-module member with this problem. Other `core.X.f` calls resolve at high or medium.
   - Caveat on `global` (3 edges): its field holds `global_lru_fun`, a value returned by `new_lru_fun()`. The edge is wrong as an unresolved guess on a static module, but the exact correct form (member ID vs callback) is less certain.
   - Hand-checked: zipkin.lua:36, ssl.lua:27, ewma.lua:27, api_router.lua:101, cors.lua:260.
3. **Duplicate top-level `local X = X` alias of a builtin, emitted as callback unknown: 11 edges** (`s-apisix_r9_dupalias.py`, `s-apisix_r9_dup2.py`). These are `tonumber` in prometheus/exporter.lua (8) and `ipairs` in consul_kv/init.lua (3). Every other file's builtin aliases give `_G#…` medium. Hand-checked: exporter.lua:813/818, consul_kv/init.lua:141.

census precision = 1 − 207/15381 ≈ **98.65%**.

Checked and found clean:
- call_type `direct`/`method` versus the written `.` and `:` (`s-apisix_r9_ctype.py`): 0 mismatches.
- Every high callee is in `nodes`.
- Every medium `mod#f` that names a scanned module is a real member: 442 edges (`s-apisix_r9_medscan.py`).
- Caller IDs versus the enclosing named function (`s-apisix_r9_callers.py`): every difference is a correct fold (constructor-field functions, functions stored on parameters, and functions stored on external requires such as `id_generator.new_ids = function`).

## Missed-call patterns (recall)
- The recall check covered 3 functions, all fully matched:
  - `apisix.plugins.key-auth.find_consumer`: 8 calls, 8 edges.
  - `apisix.plugins.response-rewrite#body_filter`: 10 calls, 10 edges.
  - `apisix.utils.redis.redis_cli`: 10 calls, 10 edges.
- **Immediate call of a `require(...)` result is dropped: 5 sites** (`s-apisix_r9_missed.py`): apisix/cli/apisix.lua:37, plugins/azure-functions.lua:61, plugins/openfunction.lua:34, plugins/serverless-pre-function.lua:17, plugins/serverless-post-function.lua:17. Only `_G#require` is emitted. The second invocation gets no edge, not even a low guess (C4).

## Spec gaps (counted separately, never as wrong)
1. **Module ID of an in-scope file that no require string names, outside `apisix/`: 1,374 edges** in t/ and example/ files (`s-apisix_r9_gaps.py`; 1,378 minus 4 my_hook edges whose caller is `apisix#…`).
   - Construct: t/lib/server.lua, t/lib/test_redis.lua and the like (`local function release(red, host, port, opts)`), named `t.lib.server`. Meanwhile the only requires of sibling files use the root `t/` (`require("lib.test_admin")`).
   - Open question (CAPABILITIES lua/15): is the module ID of such a file the path below the scan root (`t.lib.server`), the name under the require root its siblings use (`lib.server`), or something else?
   - This covers sample #12, #29, #32 and #33.
2. **`ngx.req` members: 173 low edges plus 23 high edges.**
   - Construct: apisix/patch.lua:420 `ngx.req.set_body_data = function(data)` and :403 `ngx_socket.tcp = function ()`. The tool then emits 137 in-place `ngx.req.get_headers()` calls and 36 aliased ones (`local get_method = ngx.req.get_method`) as low `req.<f>`. Unpatched siblings are medium (`ngx.re.match` → `ngx.re#match`).
   - It also emits `ngx.req#set_body_data`, `ngx.socket#tcp` and `ngx.socket#udp` at high for every call, including the saved originals (`original_tcp()`, `_orig_set_body_data(data)`).
   - Open question: does storing a function on a member of a global external table (not a `require`) make that table "scanned", so that its other members are low guesses and the patch defines the global's ID? The 2026-11-10 "Lua tables of external modules" ruling covers only locals bound to `require`.
   - This covers sample #42.
3. **Field alias on a module table: 442 medium edges.**
   - Construct: apisix/core/table.lua `local _M = { … insert = table.insert, … }`, apisix/core/request.lua:447 `_M.get_method = ngx.req.get_method`, grpc-transcode/proto.lua:125 `compile_proto = compile_proto`. Calls through them are named `apisix.core.table#insert` and so on, at medium. By contrast, `_M.gcd = gcd` resolves to the target `apisix.core.math.gcd`, high.
   - Open question: the final5 reading says such fields are module members, so the ID is not invented. Does a call through the field name the member (`mod#f`) or the alias target (`table#insert`, or the scanned local function's ID at high)?
   - This covers sample #34.
4. **Calling a module whose chunk returns a function literal: 3 edges.**
   - Construct: apisix/plugins/serverless/generic-upstream.lua:22 `return function(plugin_name, …)`, called as `serverless_obj(...)` after `local serverless_obj = require("apisix.plugins.serverless.generic-upstream")`. The tool emits callee `apisix.plugins.serverless.generic-upstream`, medium, direct.
   - Open question: the Lua notes give no ID for a module's returned anonymous function (JS has `mod.default`), and do not say which tier it takes.
5. **Alias of a global the tool does not know as a builtin: 1 edge.**
   - Construct: apisix/core/table.lua:22 `local newproxy = newproxy`, then `newproxy(true)`, emitted as `newproxy`, unknown, callback.
   - Open question: does the alias rule resolve to a bare-global target (`newproxy` / `_G#newproxy`) when the target is not a known builtin or scanned function, or is the local a value of unknown kind?

The report is at `<fanout>/s-apisix_report.v9.md`.
