# Blind call-graph review: h-uptime-kuma (javascript), round 10

precision 48/50; census ≈99.74% (25 wrong of 9469 in-scope); recall: 0 missed of 48 real calls; 0 non-calls

(Sample: 0 wrong edges and 2 spec gaps. The spec gaps are not counted as wrong, but they cannot be confirmed correct either, which is why the score is 48 and not 50.)

## Scope
The tool JSON has 12,925 edges. The in-scope set is the edges whose `source_file` is `.js`/`.mjs` and not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment. That gives **9,469 edges in 315 files** (8,998 .js, 471 .mjs). I excluded 3,282 JS edges under test directories, plus all .ts/.go/.java/.php/.cs/.py edges. Vendored code under `server/modules/` (apicache, axios-ntlm, dayjs plugin) and `server/utils/knex` is in scope, per Decisions 2026-11-09.
- Confidence: high 2,366 · medium 3,535 · low 3,172 · unknown 396.
- call_type: method 4,637 · direct 3,447 · constructor 741 · callback 396 · implicit 248.
- I ignored the `measured_accuracy` field.

## Method
- **Precision:** 50 edges stratified by tier (medium 17, low 16, high 12, unknown 5), `random.seed(10)`, spread over 39 files.
- **Recall:** three functions:
  - `server/util-server.kafkaProducerAsync` (32 calls)
  - `server/notification-providers/bark.Bark#postNotification` (7 calls)
  - `server/database.Database#patch` (9 calls)
- **Census:** scripted with the `h-uptime-kuma_r10_*.py` helpers in the fanout folder. The union script is `h-uptime-kuma_r10_census.py`.
- **Contract checks:**
  - C1: every high callee is in `nodes` (0 violations).
  - C7: no empty or `<global>` callers.
  - Line check: the callee name is on the edge's line for every non-implicit edge, except aliased imports, all of which I checked as correct.
  - Implicit edges: all 248 are on initialised fields, with `<clinit>`/`<init>` matching `static`.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| server/socket-handlers/status-page-socket-handler.js:509 (and 12 more `apicache.clear()` sites) | `apicache.clear();` | statusPageSocketHandler → `server/modules/apicache.clear` (medium, direct) | not this ID. index.js defines no `clear`; it re-exports `require("./apicache")`, whose `module.exports = new ApiCache()` and `clear` is `this.clear = function` inside `ApiCache` (C1/C2: ID invented, re-export not followed) | wrong callee | invented member ID on a re-exported instance |
| server/modules/apicache/apicache.js:799 (and 4 more) | `let cached = !redis ? memCache.getValue(key) : null;` | ApiCache.cache → `server/modules/apicache/memory-cache#getValue` (medium, method) | `server/modules/apicache/memory-cache.MemoryCache#getValue`, high, method. It is defined at memory-cache.js:69 as `MemoryCache.prototype.getValue = function` and listed in nodes under that ID (C1) | wrong callee / wrong confidence | `module.exports = MemoryCache` importer uses a second ID |
| server/proxy.js:122 | `httpAgent = new HttpCookieProxyAgent(proxyUrl.toString(), {` | Proxy#createAgents → `HttpCookieProxyAgent#<init>` (medium, constructor) | `HttpCookieProxyAgent`, callback, unknown. It is a local bound at :118 to `createCookieAgent(HttpProxyAgent)`; the same construct in grpc.js:54, `new Client(...)`, is emitted as `Client` callback/unknown (C2) | wrong callee / wrong confidence | local declared in a `switch` case block not seen as a local |
| server/proxy.js:126, :138 | `httpsAgent = new HttpsCookieProxyAgent(...` / `agent = new SocksCookieProxyAgent(...` | → `HttpsCookieProxyAgent#<init>` / `SocksCookieProxyAgent#<init>` (medium, constructor) | `HttpsCookieProxyAgent` / `SocksCookieProxyAgent`, callback, unknown | wrong callee | same as above |
| server/model/domain_expiry.js:111 | `const tld = DomainExpiry.parseTld(domain).publicSuffix;` | getRdapDomainExpiryDate → `server/model/domain_expiry.DomainExpiry#parseTld` (high, method) | `parseTld`, callback, unknown. `static parseTld = parseTld;` (:189) is a stored property holding a value (tldts `parse`) | wrong callee / conf / call_type | call through a value-holding class field resolved as a method |
| server/utils/limit-queue.js:38 | `this.__onExceed(item);` | LimitQueue#push → `server/utils/limit-queue.LimitQueue#__onExceed` (high, method) | `__onExceed`, callback, unknown. The field is `__onExceed = null;` (:20), set from outside | wrong callee / conf / call_type | same as above |
| server/monitor-types/mqtt.js:18 | `new ConditionVariable("json_value", defaultStringOperators.concat(defaultNumberOperators)),` | MqttMonitorType#conditionVariables → `server/monitor-conditions/operators.defaultStringOperators.concat` (medium, direct) | `defaultStringOperators.concat`, low, method. operators.js:279 binds an array literal and defines no `concat` (C2) | wrong callee | builtin method on an imported value named as a module member |
| server/monitor-types/tcp.js:162 | `doReject("Connection timed out");` | TCPMonitorType#performStartTls.onTimeout → `doReject` (low, direct) | `server/monitor-types/tcp.TCPMonitorType#performStartTls.doReject`, high, direct. It is the sibling `const doReject = (error) => {` at :179, which the same function's :217 call resolves (C2) | wrong callee / wrong confidence | reference to a later-declared sibling nested function not resolved |
| src/mixins/socket.js:566 (sample) | `socket.emit("add", monitor, callback);` | caller `src/mixins/socket.methods.add` | spec gap G1 | spec gap | nested property object inside `export default {}` |
| server/modules/apicache/apicache.js:898 (sample) | `return this.newInstance(this.options());` | ApiCache → `.newInstance` (low, method) | spec gap G3 | spec gap | `this` inside an ES5 constructor function's assigned function expression |

The other 48 sample edges were correct: the real call, caller, callee, tier, call_type and line all matched the spec. Examples:
- `dayjs.utc` from a `require` binding
- `src/util.dayjs` callback/unknown (a conditional initializer with a `require` branch, so no evidence)
- `Settings.get` → `server/settings.Settings#get` high
- `log.debug` → `src/util.Logger#debug` high (`exports.log = new Logger()`)
- inherited `throwGeneralAxiosError` → `NotificationProvider#…` high
- named nested arrows such as `DnsMonitorType#check.handleConditions` and `RadiusClient#accessRequest.sendRequest`
- multi-line chain lines such as `.notNullable` on its own line
- implicit field edges

## Systematic patterns (scripted counts, by count)
1. **Invented member ID on a re-exported constructor-function instance: 13 edges.** Every in-scope `apicache.clear()` goes to `server/modules/apicache.clear`. Hand-checked status-page-socket-handler.js:509, maintenance-socket-handler.js:270 and monitor.js:983.
2. **`module.exports = <constructor function>` gets a second ID in the importer: 5 edges.** These are `memory-cache#add/#clear/#delete(×2)/#getValue`. The definitions and nodes are `memory-cache.MemoryCache#…`, so C1 is violated, and the edges are medium where the definition is in the scan (high). Hand-checked apicache.js:218, :426 and :799.
3. **`new` on a block-scoped local bound to a call result named as an external type: 3 edges.** All are in proxy.js `switch` cases. grpc.js:54 gets the correct callback/unknown form. A script searched for every bare `T#<init>` whose `T` is a local bound to a call: only these 3.
4. **Call through a value-holding class field resolved as `T#m` high: 2 edges.** These are `DomainExpiry.parseTld` and `this.__onExceed`. A script checked every high `T#m` whose name is a field initializer or only a `this.m =` assignment: only these 2. Steam's `this.lookup`/`this.ping`/`this.getSteamAPIKey` are correctly callback/unknown.
5. **Builtin method on an imported non-function value named as a module member: 1 edge.** This is `operators.defaultStringOperators.concat`. A script checked every medium/high `mod.x` callee for a definition in its module: only this one and pattern 1.
6. **Unresolved reference to a later-declared sibling nested function: 1 edge.** This is tcp.js:162. A script checked every low/unknown bare callee for an enclosing `outer.name` node: only this one.

The union of the wrong edges is **25**, so census precision = 1 − 25/9469 ≈ **99.74%**.

## Missed-call patterns (recall)
None. All 48 real calls in the three functions have edges with the correct caller, callee, tier and line:
- kafkaProducerAsync: 32/32, including the multi-line `producer.connect().then().send().then().catch().finally()` chain, each on its own line, and `client.producer` → `kafkajs.Kafka#producer` typed by `= new Kafka`.
- Bark#postNotification: 7/7.
- Database#patch: 9/9.

None of the edges in those functions is a non-call.

## Spec gaps (counted separately, 204 edges in the union, none counted wrong)
- **G1: 179 edges. Members of a nested property object inside `export default { … }`.** Construct (src/mixins/socket.js:29/78): `export default { data() {…}, methods: { add(monitor, callback) { … } }, computed: {…}, watch: {…} }`. The tool names these `src/mixins/socket.methods.add`, and resolves `this.loginByToken(token)` inside `methods` to `src/mixins/socket.methods.loginByToken`, high, direct. From `created()` it leaves `this.initSocketIO()` as `.initSocketIO`, low. SPEC says the exported object is the module (`mod.f`) and named object literals nest with dots. It leaves open three questions:
  - whether a property-valued object literal inside it (`methods: {…}`) is a named object literal that nests (`mod.methods.f`), or folds into the module (`mod.f`);
  - what `this.m()` inside an object-literal method names;
  - whether that answer differs between sibling members and members of another property object.
- **G3: 16 edges. `this.m()` inside function expressions assigned in an ES5 constructor function or on a prototype.** Construct (apicache.js:897-898): `this.clone = function () { return this.newInstance(this.options()); };` inside `function ApiCache() { … this.newInstance = function (config) {…}; }`. Also memory-cache.js:81, `this.delete(key)` in a `forEach(function…, this)`. SPEC's `this.m()` → `Type#m` presumes a type. Its JS note "`this.x` assigned a value is a callback" does not say whether `this` in a non-class constructor function denotes a type, a callback slot (`newInstance`, unknown), or an unknown receiver (`.newInstance`, low).
- **G2: 5 edges. `new` on a plain constructor function.** Construct: `let instance = new ApiCache();` (apicache.js:887) and `new CachePerformance()` (:738), where `function ApiCache() {…}` is a function declaration, not a class. The tool emits the function's ID (`…apicache.ApiCache`, constructor, high). Across files it emits `memory-cache#<init>` for `let MemoryCache = require("./memory-cache"); new MemoryCache()`. SPEC defines constructor IDs as `Type#<init>` but leaves open whether an ES5 constructor function is a Type (`F#<init>`) or a function (`mod.F`).
- **G4: 2 edges. Members of an instance created from a constructor function.** Construct: `module.exports = new ApiCache();` followed in index.js by `apicache.options({...})` (→ `server/modules/apicache/apicache.options`, medium), and `let instance = new ApiCache(); instance.options(config);` (→ `ApiCache#options`, medium). The members exist only as `this.options = function` assignments inside the constructor. SPEC leaves open whether such assigned members are type members (`F#m`), module members (`mod.m`), or receiver guesses.
- **G5: 2 edges. `new` on a member of a typed local.** Construct (util-server.js:82-83): `const oauthProvider = new oidc.Issuer({...}); let client = new oauthProvider.Client({...});`. The tool gives `oauthProvider.Client#<init>` (medium) and then `client.grant` → `oauthProvider.Client#grant` (medium). SPEC leaves open what ID a constructor reached through a property of a typed instance gets: `Issuer#Client`, a receiver guess, or something else.

## Helper scripts
All in `<fanout>/`:
- `h-uptime-kuma_r10_load.py`, `h-uptime-kuma_r10_sample.py`, `h-uptime-kuma_r10_ctx.py`
- `h-uptime-kuma_r10_checks.py`, `h-uptime-kuma_r10_c2.py`, `h-uptime-kuma_r10_modpath.py`, `h-uptime-kuma_r10_moddef.py`
- `h-uptime-kuma_r10_this.py`, `h-uptime-kuma_r10_fwd.py`, `h-uptime-kuma_r10_newlocal.py`, `h-uptime-kuma_r10_fieldcall.py`
- `h-uptime-kuma_r10_census.py`

I also created a symlink there, `h_uptime_kuma_r10_load.py`, pointing to the loader. It is not used.
