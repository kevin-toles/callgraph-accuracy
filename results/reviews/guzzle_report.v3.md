# guzzle (php) call-graph review, v3

Summary: precision 49/50; recall: 1 missed of 32 real calls; 0 non-calls

Scope: 3,463 of the 22,603 edges come from in-scope PHP files (3,454 from `src/` and 9 from `.php-cs-fixer.dist.php`). By confidence they are 1,445 high, 1,637 medium, 318 low and 63 unknown. I drew a sample with seed 3031: 18 high, 22 medium, 5 low and 5 unknown edges, across 22 files. Strict proportion would be about 21/24/5/2. I took 3 from high and 2 from medium so that low and unknown each get the 5-edge minimum.

On the sample alone, 49/50 has a 95% Wilson interval of about 89.5% to 99.6%. That cannot separate 95% from 99%. The scripted counts in the systematic-patterns section are the better guide. There are 26 edges that clearly break the spec, which is 0.75% of the in-scope edges, so precision is about 99.2%. Another 27 edges are wrong if declared property types are meant to be used (pattern 4). Counting those as well gives 53 edges, 1.5%, or about 98.5% precision.

Recall functions (none of them is one the previous report used):
- `GuzzleHttp.Pool#__construct` (src/Pool.php:130-162): 7 real calls, 7 edges, none missed. The 5 calls inside the `$requestGenerator` closure have the wrong caller, and the call `$requestGenerator()` has the wrong callee (pattern 1).
- `GuzzleHttp.Handler.CurlFactory#createHeaderFn` (src/Handler/CurlFactory.php:3051-3133): 9 real calls, 9 edges, all correct. `$easy->createResponse()`, where `$easy` reaches the closure through `use`, now resolves to `GuzzleHttp.Handler.EasyHandle#createResponse` with high confidence.
- `GuzzleHttp.RedirectMiddleware#checkRedirect` (src/RedirectMiddleware.php:100-153): 16 real calls, 15 edges. 1 is missed (line 130, a callable stored in an array element; pattern 5). `$this(...)` still gives callee `this` (a spec gap).

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/Pool.php:154 (sample #50) | `yield $key => $rfn($keyedOpts);` (inside `$requestGenerator = static function () use (...) {`) | `GuzzleHttp.Pool#__construct → rfn`, unknown, callback | caller `GuzzleHttp.Pool#__construct.requestGenerator`. The callee `rfn`, unknown, callback is correct | wrong caller | a closure bound to a local is not treated as a named nested function |
| src/Pool.php:149, 152, 153, 156 | `$keyedOpts = self::keyedRequestOptions($opts, $key);` etc. (same closure) | caller `GuzzleHttp.Pool#__construct` | caller `GuzzleHttp.Pool#__construct.requestGenerator` | wrong caller | same as above |
| src/Pool.php:161 | `$this->each = new EachPromise($requestGenerator(), $config);` | `GuzzleHttp.Pool#__construct → requestGenerator`, unknown, callback | `GuzzleHttp.Pool#__construct.requestGenerator`, high ("calls to it are high") | wrong callee / wrong confidence | same as above |
| src/Handler/CurlFactory.php:2830-2834 (5 edges) | `if ($progress(` / `TransferByteCounter::progressValueToInt($downloadSize),` (inside `$progressCallback = static function (...) use ($easy, $progress): int {`) | caller `GuzzleHttp.Handler.CurlFactory#applyHandlerOptions` | caller `GuzzleHttp.Handler.CurlFactory#applyHandlerOptions.progressCallback` | wrong caller | same as above |
| src/Exception/TransferException.php:22 | `parent::__construct($message, $code, $previous);` (`class TransferException extends \RuntimeException`) | `→ parent.__construct`, low, method | `RuntimeException#<init>`, medium, constructor | wrong callee / wrong confidence | `parent::` is not resolved when the parent class is outside the scan |
| src/Cookie/FileCookieJar.php:47, SessionCookieJar.php:47, Exception/NetworkException.php:20, RequestException.php:25, ResponseException.php:26 | `parent::__construct();` | `→ GuzzleHttp.Cookie.CookieJar#__construct` (etc.), high, method | `GuzzleHttp.Cookie.CookieJar#<init>` (etc.), high, constructor | wrong callee | `parent::__construct` is not mapped to `#<init>`/constructor |
| .php-cs-fixer.dist.php:5-28 (9 edges) | `$config = (new PhpCsFixer\Config())` / `->setRiskyAllowed(true)` | caller `''` | the spec says "A caller is never empty". It does not say how to name file-level code in PHP | wrong caller (spec gap for the form) | top-level script code gets no caller |
| src/Handler/CurlFactory.php:538 etc. (27 sites) | `$easy->request->getUri()` (`EasyHandle $easy`; `public RequestInterface $request;`) | `→ request.getUri`, low, method | spec: `prop.m` is for receivers of unknown type. Here the property's type is declared, and `$this->prop->m()` is already resolved through declared property types. Per the stated intent ("untyped property names `prop.m`") this should be `Psr.Http.Message.RequestInterface#getUri`, medium | spec gap (likely wrong per intent) | declared property types are used only for `$this->prop`, not for `$var->prop` |
| src/RedirectMiddleware.php:130 | `($options['allow_redirects']['on_redirect'])(` | no edge | a callback edge, unknown. The spec names callbacks after a variable or property; an array-element callee is not covered | missed call (spec gap for the name) | a call through an array element is not emitted |
| src/RedirectMiddleware.php:141 | `$promise = $this($nextRequest, $options);` | `→ this`, unknown, callback | not covered by the spec; `GuzzleHttp.RedirectMiddleware#__invoke`, high would be natural | spec gap | `$this(...)` is not mapped to `__invoke` |
| src/RedirectMiddleware.php:121 (sample #45), Client.php:1542 (sample #42) | `if (defined('\CURLOPT_HTTPAUTH') && defined('\CURLOPT_USERPWD')) {` | `→ defined`, low, direct | low matches the spec (a bare name not in the scan), but `\defined` is medium (sample #19) | spec gap | unqualified global builtins are not resolved to the global namespace |

The other 49 sampled edges are correct on every count: real call, caller, callee, confidence, call_type and line. They include `self::` statics (high), in-scan exception constructors (high), `\RuntimeException#<init>` (medium), `P\Create::rejectionFor` through `use GuzzleHttp\Promise as P` (medium) and `catch (\Throwable $e)` → `Throwable#getMessage` (medium). They also include typed parameters → `Psr.Http.Message.*` (medium), computed receivers `.wait` / `.getScheme` (low), `ProxyEnv::resolveProxySelection()` result → `proxy.hasProxy` (low, since the spec does not use return types) and callable params, locals and properties (unknown, callback).

## Systematic patterns

Counts come from scripts run over the JSON and the source, in scope (`src/` + `.php-cs-fixer.dist.php`, 3,463 edges) and across the whole output (22,603, including tests/).

1. **A closure bound to a local (`$f = function`/`fn`) is not a named nested function.** There are 0 PHP callers of the form `#m.f` anywhere in the output. In scope there are 2 sites: Pool.php:147 and CurlFactory.php:2815. They give 10 edges with the wrong caller plus 1 call (`$requestGenerator()`) that is unknown/callback instead of high. That is **11 edges**. tests/ has 82 such sites, with about 73 edges inside them that have the wrong caller and about 129 callback calls to those variables later in the same method (a heuristic count). That is roughly **213 edges in the whole output**. This fix would help precision the most outside `src/`.
2. **`parent::__construct(...)` is a method call on `#__construct` instead of `Parent#<init>`, constructor.** All 6 sites in `src/` do this. 5 resolve to the in-scan parent as `#__construct` (high, method). 1, whose parent `\RuntimeException` is outside the scan, gives `parent.__construct` (low). tests/ has 5 more, all `parent.__construct`, low. That is **11 edges in the whole output**. As a side effect, `new X()` (`X#<init>`) and `parent::__construct` (`X#__construct`) give the same constructor two different IDs.
3. **Empty caller for top-level script code.** 9 in-scope edges (all of `.php-cs-fixer.dist.php`) and 27 in tests/, so **36 edges in the whole output**. This breaks "A caller is never empty". The spec has no PHP rule for naming file-level code.
4. **`$var->prop->m()` gives `prop.m` even when the property has a declared type** (spec gap, likely wrong per the stated intent). All 27 such sites in `src/` now give `prop.m`, low. All 27 are on typed properties of the typed parameter `EasyHandle $easy`: `RequestInterface $request` (19), `?ResponseInterface $response` (1), `?\Throwable ...Exception` (6) and `?\OverflowException $responseBodySizeException` (1). `$this->prop->m()` resolves through declared property types (e.g. ResponseException.php:44 → `Psr.Http.Message.ResponseInterface#getStatusCode`). If these are meant to resolve too, that is **27 edges**.
5. **Calls through a callable stored in an array element are not emitted** (recall). There are 5 sites in `src/`: RedirectMiddleware.php:130, StreamHandler.php:375 and :499, MockHandler.php:273, HandlerStack.php:216 (`$fn[0]($prev)`). All 5 have no edge. The spec does not say what to name these.
6. **Spec gap: unqualified global builtins are low.** There are 69 in-scope edges (unchanged from v2) and 44 in tests/, **113 in the whole output**. The same builtins written with `\` are medium.
7. **Spec gap: `$this(...)` gives callee `this`.** 2 edges (RedirectMiddleware.php:141, RetryMiddleware.php:135).

Breakdown of the 318 low edges in scope, by script:
- 88 receivers assigned from a method or variable expression
- 69 bare builtins
- 64 computed `.m`
- 43 receivers assigned from a static call
- 27 property chains (pattern 4)
- 19 foreach variables
- 4 untyped parameters
- 2 untyped closure parameters
- 2 other: `parent.__construct`, and `$requestFactory` assigned from a variable

0 remain where the receiver is a typed parameter of the enclosing method, a `catch` variable or `= new T`. Except for patterns 2 and 4, I found no low edge where the spec's type sources (declarations, `new`, catch, `use`/arrow capture) should have given a type.

## Previous findings

Mismatch-table rows of the v2 report:
- **CurlFactory.php:2173 `$easy->request->getHeaders()` → `.getHeaders`: fixed.** It is now `request.getHeaders`, low. (See pattern 4 for the remaining question about the typed property.)
- **HandlerStack.php:58 `new self` → `GuzzleHttp.self#<init>`: fixed.** It is now `GuzzleHttp.HandlerStack#<init>`, high.
- **HandlerStack.php:59-63 `$stack->push` → `GuzzleHttp.self#push` (5 edges): fixed, 5/5.** It is now `GuzzleHttp.HandlerStack#push`, high.
- **CurlFactory.php:3087 `$easy->createResponse()` through `use` (spec gap): fixed.** It is now `GuzzleHttp.Handler.EasyHandle#createResponse`, high.
- **Middleware.php:267 `$formatter->format` through `use` (spec gap): fixed.** It is now `GuzzleHttp.MessageFormatterInterface#format`, high. Lines 268, 280 and 281 are also fixed: `Psr.Log.LoggerInterface#log` / `#error`, medium.
- **Idn.php:49 `array_filter` low while `\array_filter` is medium (spec gap): still present.** The same holds for `array_keys` and `get_defined_constants` on that line.

Systematic patterns of the v2 report:
1. **`new self` / `new static` become a fake `<ns>.self` / `<ns>.static` class: fixed.** All 16/16 sites now give `<Enclosing>#<init>`, high. All 7/7 follow-on edges are fixed: `HandlerStack#push` x5, `CookieJar#setCookie` (CookieJar.php:68) and `Pool#promise` (Pool.php:278). There are 0 `self#`/`static#` callees left in the whole output. 23/23.
2. **`$var->prop->m()` gives `.m` instead of `prop.m`: fixed.** All 27/27 sites now give `prop.m`. What remains is the typed-property question in pattern 4.
3. **Declared types dropped through closure `use` and `catch` (spec gap): fixed.** Low edges whose receiver is a typed parameter of the enclosing method went from 36 to 0. CookieJar.php:432-435 `$cookie->getName()` etc. are now `GuzzleHttp.Cookie.SetCookie#*`, high, and StreamHandler.php:822 `$sink->write` is now `Psr.Http.Message.StreamInterface#write`, medium. Low `e.member` edges from `catch` variables went from 23 to 0. They now resolve to the catch type, e.g. `Exception#getMessage` x15, `Throwable#getMessage` x5. Total low edges went from 379 to 318.
4. **Unqualified global functions low but `\`-qualified ones medium (spec gap): still present.** 69/69 are unchanged (22 in CurlVersion.php).

The v2 report's own "Previous findings" items:
- The `($this->prop)(...)` callbacks are still fixed: 14/14.
- There are still 0 `isset`/`empty`/`unset` edges.
- `$this(...)` → `this` is still present: 2/2.

New in this review: patterns 1, 2, 3 and 5. The v2 report did not mention them. I cannot tell from v2's data whether they were already there.
