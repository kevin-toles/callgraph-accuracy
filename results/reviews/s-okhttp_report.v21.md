# s-okhttp (kotlin) blind call-graph review, round 21

precision 45/50; census ≈99.68% (176 wrong of 54736 in-scope); recall: 0 missed of 51 real calls; 0 non-calls

(Of the 50 sampled edges, 45 are correct, 1 is wrong and 4 are spec gaps.)

## Scope
Tool output: `<scans>/kr40-A/s-okhttp.v2.json`, 63,859 edges. In scope: `.kt` source files with no path segment named exactly `test`, `tests`, `spec`, `examples` or `docs`. Segments such as `jvmTest`, `commonTest`, `androidTest` and `androidHostTest` are not exact matches, so they are in scope (Decisions 2026-11-09). 1,376 `.java` edges are out of scope. That leaves **54,736 in-scope edges in 459 files**.
- Confidence: high 26,199 / medium 19,211 / low 9,261 / unknown 65.
- call_type: method 32,255 / direct 14,890 / constructor 6,006 / implicit 1,520 / callback 65.

Coverage note: `Android10Platform.kt` is partial (syntax_error from line 110). The `measured_accuracy` field was ignored. Helper scripts are `fanout/s-okhttp_r21_*.py`, and the sample seed is 21.

## Method
- **Precision sample:** seed 21. Quotas: high 22, medium 16, low 7, unknown 5. At most one edge per file per tier, except unknown, giving 42 files.
- **Recall:** three functions:
  - `DiskLruCache#edit` (okhttp/src/commonJvmAndroid/.../cache/DiskLruCache.kt:479-532)
  - `Punycode#decodeLabel` (.../idn/Punycode.kt:180-264)
  - `DerReader#readHeader` (okhttp-tls/.../der/DerReader.kt:104-161)

  Operator-convention calls (`a[k]`, `+=`, `in`, `..`) are left out of the recall counts; see spec gap G7.
- **Census:** every pattern is counted by script, checked by hand, and the counts are unioned.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/OkHttpClient.kt:1115 (sample #48) | `callTimeout(duration.toMillis(), MILLISECONDS)` | `OkHttpClient.Builder#callTimeout → callTimeout`, unknown, callback | `okhttp3.OkHttpClient.Builder#callTimeout`, high, method (bare call of an enclosing-type member: the `(Long, TimeUnit)` overload) | wrong callee / call_type / confidence | the name collides with the `internal var callTimeout = 0` property (Int, not a function type) and is taken as a call through a value |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/connection/RealCall.kt:373 | `return callDone(e)` | `RealCall#messageDone → callDone`, unknown, callback | `okhttp3.internal.connection.RealCall#callDone`, high, method | wrong callee / call_type / confidence | the local `var callDone = false` (Boolean) shadows the name; the call resolves to the method |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/connection/RealCall.kt:85 | `timeout(client.callTimeoutMillis.toLong(), MILLISECONDS)` (inside `object : AsyncTimeout() {…}.apply { }`) | `RealCall#timeout → timeout`, unknown, callback | a method call on the apply receiver. Under 2026-11-17 an anonymous-subclass receiver is `.timeout`, low, method | wrong call_type / confidence | same-name property `timeout` taken as a function value |
| okhttp/src/jvmTest/kotlin/okhttp3/SocketChannelTest.kt:152 | `sslSocketFactory(sslSocketFactory, handshakeCertificates.trustManager,)` inside `.apply {` on a builder | `→ sslSocketFactory`, unknown, callback | a method call on the apply receiver (`OkHttpClient.Builder#sslSocketFactory`). The local `val sslSocketFactory: SSLSocketFactory` has no `invoke` | wrong call_type / confidence | the local val name shadows the method |
| okhttp/src/jvmTest/kotlin/okhttp3/EventListenerTest.kt:1799 | `Interceptor { chain: Interceptor.Chain ->` | `→ Interceptor`, unknown, callback | not a call through a value. Elsewhere in the same repo the same construct is `okhttp3.Interceptor#invoke`, high, method (46 edges; C2). Which of the two is right is spec gap G4 | wrong call_type / confidence (C2) | C2 inconsistency: only occurs with a typed lambda parameter |
| okhttp/src/jvmTest/kotlin/okhttp3/EventListenerTest.kt:1802 | `return@Interceptor chain.proceed(chain.request())` | `→ chain.proceed`, `chain.request`, low, method | `okhttp3.Interceptor.Chain#proceed` / `#request`, high (declared lambda parameter `chain: Interceptor.Chain`, decision A; body-less interface member of a scanned type, 2026-11-09) | wrong callee / confidence | explicitly typed lambda parameters are not typed |
| okhttp/src/jvmTest/kotlin/okhttp3/InterceptorTest.kt:684 | `chainB.proceed(chainA.request())` | `→ chainA.request`, low | `okhttp3.Interceptor.Chain#request`, high | wrong callee / confidence | same as above |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/cache/DiskLruCache.kt:515 (recall) | `.writeUtf8(DIRTY)` after `val journalWriter = this.journalWriter!!` | `DiskLruCache#edit → journalWriter.writeUtf8`, low | `okio.BufferedSink#writeUtf8`, medium. The property is declared `BufferedSink?`; `!!` unwraps (2026-11-17), and the let-bound rule applies | wrong callee / confidence | a local bound to a declared-type property (`this.p!!` / `p`) is not typed |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/cache/DiskLruCache.kt:519 (recall) | `journalWriter.flush()` | `→ journalWriter.flush`, low | `okio.BufferedSink#flush`, medium | wrong callee / confidence | same as above |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/connection/RealCall.kt:306 | `val connection = exchangeFinder.find()` after `val exchangeFinder = this.exchangeFinder!!` | `→ exchangeFinder.find`, low | `okhttp3.internal.connection.ExchangeFinder#find`, high | wrong callee / confidence | same as above |
| okhttp-tls/src/main/kotlin/okhttp3/tls/internal/der/DerReader.kt:111 (recall) | `if (limit == -1L && source.exhausted()) return END_OF_DATA` | `DerReader#readHeader → okio.Source#exhausted`, medium | `okio.BufferedSource#exhausted`, medium. In a member body, `source` is the property `private val source: BufferedSource`; the constructor parameter `source: Source` is visible only in initializers | wrong callee | a plain constructor parameter shadows the same-name property inside member functions |
| okhttp-tls/src/main/kotlin/okhttp3/tls/internal/der/DerReader.kt:114 (recall; also :124, :138, :145) | `val tagAndClass = source.readByte().toInt() and 0xff` | `→ okio.Source#readByte`, medium | `okio.BufferedSource#readByte`, medium | wrong callee | same as above |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/http2/Hpack.kt:206 | `while (!source.exhausted()) {` | `Hpack.Reader#readHeaders → okio.Source#exhausted`, medium | `okio.BufferedSource#exhausted`, medium (`private val source: BufferedSource = source.buffer()`) | wrong callee | same as above |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/internal/-UtilJvm.kt:201 | `this.skipAll(timeout, timeUnit)` | `okhttp3.internal.discard → okio.Source#skipAll`, medium | `okhttp3.internal.skipAll`, high, direct (`internal fun Source.skipAll(` is defined in the scan; C1) | wrong callee / confidence / call_type | a scanned extension function is named as a member of its receiver type |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/RequestBody.kt:224 | `): RequestBody = content.toRequestBody(contentType)` | `→ String#toRequestBody`, medium | `okhttp3.RequestBody#toRequestBody`, high (companion extension, flattened). Sample #15 gives exactly this ID for the same function (C1/C2) | wrong callee / confidence | same as above |
| okhttp/src/commonJvmAndroid/kotlin/okhttp3/Request.kt:456 | `append("curl ${url.toString().shellEscape()}")` | `→ String#shellEscape`, medium | `okhttp3.Request#shellEscape`, high (`private fun String.shellEscape()` is a member extension of Request) | wrong callee / confidence | same as above |

## Systematic patterns (scripted counts, by count)
1. **W3: explicitly typed lambda parameters are not typed: 117 edges.**
   - Script: `s-okhttp_r21_lambdaparam.py`.
   - Construct: `{ p: T -> … p.m() … }` where `p.m` is left as a low guess. 115 edges are on `Interceptor.Chain` and 2 on `Response` (the `proxyAuthenticator { _: Route?, response: Response -> response.challenges() }` lambdas in CallTest).
   - Correct: `okhttp3.Interceptor.Chain#m` / `okhttp3.Response#m`, high.
   - Hand-checked: CallTest.kt:1102/1105, EventListenerTest.kt:1802, InterceptorTest.kt:684/689, CallTest.kt:4094.
   - Not counted: calls on locals bound from those parameters (`val chainB = chainA.withConnectTimeout(...)`).
2. **W5: a constructor parameter shadows a same-name property inside member bodies: 19 edges.**
   - Script: `s-okhttp_r21_ctorshadow.py`.
   - 15 in DerReader.kt and 4 in Hpack.kt (`Hpack.Reader`). The tool gives `okio.Source#readByte|exhausted|readByteString|readByteArray|readUtf8`; correct is `okio.BufferedSource#…`.
   - Every one of these names a member that `okio.Source` does not have.
3. **W4: a local bound to a declared-type property (`val x = this.p!!`, `val x = p`) is not typed: 15 edges.**
   - Script: `s-okhttp_r21_bangprop.py`.
   - Cases: WebSocketRecorder `delegate` (6), DiskLruCache `journalWriter` (2), RealWebSocket `extensions` (2), RealRoutePlanner `existingRouteSelection` (2), RealCall `exchangeFinder` and `connection` (1 each), DiskLruCache `removeSnapshot` (1).
4. **W1: a bare call of an enclosing-type or apply-receiver method is emitted as a callback because a property or local has the same name: 12 edges.**
   - Script: `s-okhttp_r21_census.py`.
   - Cases: OkHttpClient.Builder `callTimeout`, `connectTimeout`, `readTimeout`, `writeTimeout`, `pingInterval`, `webSocketCloseTimeout`; RealCall `timeout`, `callDone`×2, `timeoutEarlyExit`; RealConnection `noNewExchanges`; SocketChannelTest `sslSocketFactory`.
   - In each case the colliding value is not of function type.
5. **W6: a scanned extension function is named `ReceiverType#ext`, medium: 8 edges.**
   - Script: `s-okhttp_r21_ext.py`.
   - Excluded from the count: 12 `Int#and` edges (the built-in member `Int.and(Int)` wins over the scanned `Int.and(Long)`) and 2 ambiguous `String#codePoints` edges.
   - Cases: `String#toRequestBody`×2, `okio.ByteString#toRequestBody`, `java.io.File#asRequestBody`, `String#toResponseBody`, `ByteArray#toResponseBody`, `String#shellEscape`, `okio.Source#skipAll`.
   - These are C1 violations: elsewhere the same definitions are reached as `okhttp3.RequestBody#toRequestBody`, high.
6. **W2: `Interceptor { chain: Interceptor.Chain -> … }` as a callback to `Interceptor`: 5 edges.** The same construct with an untyped parameter gives `okhttp3.Interceptor#invoke`, high (46 edges), so this is a C2 violation.

Union: 176 edges, with no overlap between the patterns. Census precision = 1 − 176/54,736 ≈ **99.68%**.

## Missed-call patterns (recall)
| function | real calls | emitted | missed | wrong ID among emitted |
|---|---|---|---|---|
| `DiskLruCache#edit` | 11 | 11 | 0 | 2 (W4: `journalWriter.writeUtf8`, `journalWriter.flush`) |
| `Punycode#decodeLabel` | 9 | 9 | 0 | 0 (`String#regionMatches` and `String#lastIndexOf` fall under spec gap G2) |
| `DerReader#readHeader` | 31 | 31 | 0 | 5 (W5) |

No named calls were missed and no edge was a non-call. Infix calls (`and`, `shl`, `until`, `step`) are emitted, so the open defect kotlin/15 did not show in these functions.

## Spec gaps (counted separately, never as wrong)
- **G1: Kotlin default-import standard-library functions, qualified: 1,749 edges.** Examples: `kotlin.collections.listOf` (388), `kotlin.apply` (248), `kotlin.check`, `kotlin.TODO` (sample #27: `HostnameVerifier { _, _ -> TODO() }`), `kotlin.io.println`. Open question (CAPABILITIES kotlin/16 (1)): is a default-imported stdlib function `kotlin.io.println`, direct, medium, or a bare `println`, low? What is the ID of a scope function such as `apply {}`?
- **G2: Kotlin built-in and `java.lang` types named unqualified: 1,414 edges.** Examples: `System#nanoTime` (101), `AssertionError#<init>`, `Int#toLong`, `ByteArray#<init>`, `Thread#sleep`, `String#substring`, `Class#forName` (sample #31), `String#format` (sample #35: `String.format("[%1\$tF …", …)`, which is the Kotlin `String.Companion.format` extension). Open question: the "Implicitly imported names are qualified" decision lists only Java/Scala/Groovy. Is Kotlin's implicit `java.lang.*` / `kotlin.*` written `java.lang.System#nanoTime` / `kotlin.Int#toLong`, or as written? And is a stdlib extension on `String` named `String#m`?
- **G1b/G3: stdlib extension and scope functions on a receiver: 459 edges.**
  - 387 on computed receivers: `.also`, `.use`, `.apply`, `.map`, …. Sample #42 `return cookies?.unmodifiable().orEmpty()` falls here.
  - 72 named on scanned types: `okhttp3.Response#use` (43), `DiskLruCache#also`, ….
  - Open question (kotlin/16 (2)): is the ID the extension's top-level ID (`kotlin.io.use`), the receiver type's member (`okhttp3.Response#use`), or a low guess?
- **G4: SAM constructors `T { … }` of fun interfaces and Java interfaces: 70 edges.** The tool gives `okhttp3.Interceptor#invoke` (46), `javax.net.ssl.HostnameVerifier#<init>` (7), `okhttp3.EventListener.Factory#<init>` (4), `java.util.concurrent.ThreadFactory#<init>`, `Runnable#<init>`, …. Open question: `Interceptor { chain -> … }` names a `fun interface` whose companion declares `inline operator fun invoke(crossinline block: …): Interceptor = Interceptor { block(it) }`. Is the call an invocation of the companion `invoke`, a SAM-constructor call (and with what ID, given that interfaces have no constructor and the anonymous-subclass rule gives no edge), or not a call?
- **G5: a property bound to an object reference: 96 edges.** `private val verifier = OkHostnameVerifier` (HostnameVerifierTest.kt:44), then `verifier.verify(...)`, low. Open question: does a property or local initialized with a reference to a scanned `object` take that object's type? The typing rules cover `= T(...)`, call results and property getters, but not a bare object reference.
- **G6: `Response#body` is shared by a typed property and an undeclared function: 50 edges, counted only for `get(url).body.m()` in CacheTest.kt.** `@get:JvmName("body") val body: ResponseBody` (Response.kt:80) and `fun body() = body` (Response.kt:246, deprecated ERROR) share one ID. Open question: does the 2026-11-12 reading "overload-ambiguous includes declarations of one ID … of which one declares none" apply to a property access `x.body` that only the property can satisfy? If not, `get(url).body.string()` is `okhttp3.ResponseBody#string`, high.
- **G7: operator-convention calls, which have no edges** (recall side; not counted): `lruEntries[key]`, `lruEntries[key] = entry`, `codePoints += codePoint.code`, `in 'a'..'z'`, `string[pos++]`. Open question: is a Kotlin operator-convention call (`get`/`set`/`plusAssign`/`rangeTo`/`contains`) an invocation edge, and with what ID? SPEC lists indexing only as a "computed receiver".
- **G8: implicit lambda parameters of SAM conversions: 30 `chain.*` low edges.** Example: `Interceptor { chain -> chain.proceed(chain.request()) }`. Open question: does a lambda parameter with no written type take its type from the SAM method's declared parameter (`fun intercept(chain: Chain)`, scanned), or does it stay a low guess?
