# zuul (java) call-graph review, v3

Summary: precision 50/50; recall: 0 missed of 72 real calls; 0 non-calls

Scope: 7,971 of 20,115 edges are in non-test Java (3,505 high, 3,276 medium, 1,190 low, 0 unknown; 6,452 method, 1,038 constructor, 481 implicit). This is the same scope as v2: zuul-sample and src/jmh are counted, test directories are not.

The sample is 50 edges drawn with seed 3303: 22 high, 20 medium and 8 low, which is roughly proportional to the tier counts. They come from 34 files, and 47 of the 50 are in src/main (3 are in jmh). All 50 are correct on every criterion: real call, caller, callee ID, tier and line.

Edges in the sample that test the v2 fixes:
- `input.getContext()` resolves to `com.netflix.zuul.message.ZuulMessage#getContext`, high (HttpSyncEndpoint.java:57).
- `fireCompleteEventIfNotAlready` inside a nested class resolves through the enclosing class to its superclass `HttpLifecycleChannelHandler`, high.
- A record accessor `entry.name()` resolves to `HeaderEntry#name`, high.
- `super.channelRead`, where the superclass is outside the scan, is `.channelRead`, low.
- The lambda parameter `chunk.retain` is low.

On its own, 50/50 cannot separate 95% from 99%: the 95% Wilson lower bound is about 93%. The scripted sweeps in "Systematic patterns" find about 61 wrong edges in the whole output, about 0.8% of 7,971, so the estimated precision is about 99.2%.

Recall functions:
- `ClientConnectionsShutdown#initDiscoveryListener`: 9 of 9. These include the instanceof-bound `sce.getPreviousStatus` / `sce.getStatus`, which are now `com.netflix.discovery.StatusChangeEvent#…`, medium.
- `ClientRequestReceiver#buildZuulHttpRequest` (95 lines): 47 of 47.
  - The catch parameter `ex.getReason()` is `java.net.URISyntaxException#getReason`, medium.
  - The instanceof binding `defaultFullHttpRequest.content()` is `io.netty.handler.codec.http.DefaultFullHttpRequest#content`, medium.
  - The inherited `request.setHasBody` is `ZuulMessage#setHasBody`, high.
  - Each call in a multi-line chain is on its own line.
  - The method references `HttpRequest::uri` and `SessionContext::getUUID` correctly produce no edge.
- `AccessLogChannelHandler.AccessLogInboundChannelHandler#userEventTriggered`: 16 of 16.
  - The instanceof binding `completeEvent.getReason()` is `HttpLifecycleChannelHandler.CompleteEvent#getReason`, high.
  - The typed field chain `state.request.uri()` is `io.netty.handler.codec.http.HttpRequest#uri`, medium.
  - `LOG` from the enclosing class is `org.slf4j.Logger#debug`.

## Mismatch table

The sample has no mismatches. The rows below are wrong edges and spec gaps that the whole-output sweeps found, outside the sample. One example is listed per pattern, and counts are in the next section.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| zuul-core/.../zuul/netty/filter/BaseZuulFilterRunner.java:116 | `zuulMesg.getContext().put(runningFilterIndexSessionKey, idx);` (class `BaseZuulFilterRunner<I extends ZuulMessage, O extends ZuulMessage>`, param `I zuulMesg`) | `BaseZuulFilterRunner#initRunningFilterIndex → I#getContext`, medium, method | `com.netflix.zuul.message.ZuulMessage#getContext`, high | wrong callee / wrong confidence | type variable used as a type name; its bound is not substituted |
| zuul-core/.../zuul/exception/OutboundErrorType.java:31 | `ERROR_TYPE_READ_TIMEOUT_STATUS.get(),` (field declared in interface `ErrorType` as `DynamicIntProperty`) | `OutboundErrorType#<clinit> → ERROR_TYPE_READ_TIMEOUT_STATUS#get`, medium | `com.netflix.config.DynamicIntProperty#get`, medium | wrong callee | field inherited from an interface, used by an enum, is not looked up, and the ALL_CAPS name is treated as a type |
| zuul-sample/.../SampleSSEPushChannelInitializer.java:42 | `pushAuthHandler = new SamplePushAuthHandler(PushProtocol.SSE.getPath());` (`PushProtocol` is an in-scan enum) | `→ SSE.getPath`, low | `com.netflix.zuul.netty.server.push.PushProtocol#getPath`, high | wrong callee / wrong confidence | enum constant of an in-scan enum is not typed as the enum (typed static fields such as `CommonContextKeys.X.name()` do resolve) |
| zuul-core/.../zuul/netty/ZuulToNettyHttpHeaders.java:300 | `return this.nextIndex < ZuulToNettyHttpHeaders.this.size();` | `→ this.size`, low | `com.netflix.zuul.netty.ZuulToNettyHttpHeaders#size`, high (declared at line 150) | wrong callee / wrong confidence | qualified `Outer.this` is treated as an untyped field chain |
| zuul-core/.../netty/common/close/ConnectionCloseEvent.java:46 | `if (maxJitter.toMillis() < 1) {` (inside the compact constructor `public GracefulDelayed {`) | `ConnectionCloseEvent.GracefulDelayed#<clinit> → java.time.Duration#toMillis`, medium | caller `com.netflix.netty.common.close.ConnectionCloseEvent.GracefulDelayed#<init>` | wrong caller | record compact canonical constructor is treated as a static initializer |
| zuul-core/.../zuul/netty/server/BaseZuulChannelInitializer.java:199 | `this.perEventLoopConnectionMetricsHandler = perEventLoopMetricsHandler.new Connections();` | `→ Connections#<init>`, medium, constructor | `com.netflix.netty.common.metrics.PerEventLoopMetricsChannelHandler.Connections#<init>`, high (the type is in the scan) | wrong callee / wrong confidence | qualified inner-class creation `outer.new Inner()` is not resolved against the outer type |
| zuul-core/.../com/netflix/config/DynamicIntegerSetProperty.java:23 | `super(propName, defaultValue);` (`extends DynamicSetProperty<Integer>`, no import, same package `com.netflix.config`, type not in scan) | `→ DynamicSetProperty#<init>`, medium | Probably `com.netflix.config.DynamicSetProperty#<init>`, medium. The spec only says external types are qualified "through its explicit import". | spec gap | unimported same-package external type is left unqualified |
| zuul-core/.../zuul/netty/server/http2/DynamicHttp2FrameLogger.java:257 | `String b = direction.name() + …` (`Direction` is a nested type inherited from external superclass `Http2FrameLogger`) | `→ Direction#name`, medium | Probably `io.netty.handler.codec.http2.Http2FrameLogger.Direction#name`, medium | spec gap | nested type inherited from an external supertype is not qualified |
| zuul-core/.../netty/common/close/Http2ConnectionCloseHandler.java:67 | `log.debug("Graceful delayed close disabled, …");` (`log` is generated by Lombok `@Slf4j` at line 47) | `→ log.debug`, low | `log.debug`, low is correct per spec because the field is not in the source. v2 called this an inherited field, which was wrong. | spec gap | Lombok-generated members |
| zuul-core/.../passport/PassportState.java:20 | `IN_REQ_HEADERS_RECEIVED,` | `PassportState#<clinit> → PassportState#<init>`, high | unchanged from v2 | spec gap | enum constants |
| zuul-core/.../zuul/netty/server/ClientConnectionsShutdown.java:145 | `cancelTimeoutTask.run();` (local `Runnable` holding a lambda) | `→ Runnable#run`, medium | unchanged from v2 | spec gap | functional-interface call versus callback rule |

## Systematic patterns

All counts are scripted over the 7,971 in-scope edges. The checks used are:
- An index of the 500 scanned types (supertypes, declared methods, fields and enum constants).
- A re-implementation of scope-chain → explicit-import → package resolution, run against every constructor and `Type.m(` edge: 795 constructor checks and 1,206 static-call checks, 0 disagreements.
- A receiver-shape classification of every low edge.

Wrong edges, by how much fixing each would raise precision:

1. **Type variables used as type names: 27 edges, about 0.34%.** These are `I#…` (13), `O#…` (8) and `T#…` (6), all medium, in BaseZuulFilterRunner (`<I extends ZuulMessage, O extends ZuulMessage>`), ZuulFilterChainRunner (`<T extends ZuulMessage>`) and PassportStampingFilter. With the bound substituted, they would be `com.netflix.zuul.message.ZuulMessage#getContext` / `#hasCompleteBody` / `#disposeBufferedBody` / …, high. The 4 `getClass` edges would be `ZuulMessage#getClass`, medium.
2. **Enum constants of in-scan enums not typed: 11 edges, about 0.14%.**
   - 7 `PushProtocol.SSE|WEBSOCKET.getPath|getHandshakeCompleteEvent|sendErrorAndClose` and 1 `ZuulStatusCategoryGroup.SUCCESS.getId`. These should be `Type#m`, high.
   - 3 `.name()` calls: `ExecutionStatus.FAILED|SUCCESS.name()` and `SocketAddressProperty.BindType.ANY.name()`. These should be `Type#name`, medium, the same as the tool already gives typed locals (`CompleteReason#name`).
   - External constants such as `HttpResponseStatus.BAD_REQUEST.code` → `BAD_REQUEST.code`, low, are correct per spec and not counted.
3. **ALL_CAPS fields inherited from an interface, used by an enum: 9 edges, about 0.11%.** All are in OutboundErrorType.java (lines 31-39 area), `ERROR_TYPE_*#get`, medium. They should be `com.netflix.config.DynamicIntProperty#get`.
4. **Qualified `Outer.this.m()`: 8 edges, about 0.10%.** All are in ZuulToNettyHttpHeaders.java (lines 300, 316, 322, 328, 362, 366, and 367 ×2), emitted as `this.size` / `this.name` / `this.value` / `this.nameEquals`, low. They should be `com.netflix.zuul.netty.ZuulToNettyHttpHeaders#…`, high, since all four methods are declared there.
5. **Compact canonical constructor as `<clinit>`: 4 edges, about 0.05%.** These are ConnectionCloseEvent.java:46-47 and ListenerSpec.java:32-33. The caller should be `#<init>`. These are the only two compact constructors in the repo.
6. **`outer.new Inner()` unqualified: 2 edges.** These are `Connections#<init>` and `HttpRequests#<init>` at BaseZuulChannelInitializer.java:199-200.

Total: about 61 wrong edges, about 0.8%. Fixing patterns 1 and 2 removes 38 of them.

Spec gaps, not counted as errors:
- enum constant → own `<init>` from `<clinit>`: 161 edges.
- Functional-interface calls through locals or fields holding lambdas: 19 edges (`Consumer#accept` 5, `BiConsumer#accept` 3, `Runnable#run` 3, `Supplier#get` 2, `BiPredicate#test` 2, `Callable#call` 2, `BiFunction#apply` 1, `Predicate#test` 1). The output still has 0 callback/unknown edges.
- Unimported same-package external types: 5 edges.
- Nested type inherited from an external supertype: 1 edge.
- Lombok `@Slf4j` `log.debug`: 3 low edges, correct per the spec text.

Rules that could not be exercised: non-test code has no static-imported methods, only constants and nested types. The static-imported nested types `CompleteEvent` and `CompleteReason` in ClientRequestReceiver resolve correctly (lines 233 and 268).

## Previous findings

Mismatch-table rows from v2:
- **HttpResponseMessageImpl.java:189, `ClientCookieDecoder.STRICT.decode` → `.decode`: fixed.** It is now `STRICT.decode`, low.
- **ZuulToNettyHttpHeaders.java:96, `CharSequenceValueConverter.INSTANCE.convertToTimeMillis`: fixed.** It is now `INSTANCE.convertToTimeMillis`, low.
- **PassportState.java:20, enum `<clinit> → <init>` (spec gap): still present, unchanged at 161 edges.** This is still a spec question.
- **ClientConnectionsShutdown.java:145, `Runnable#run` (spec gap): still present, 19 functional-interface edges (was 20).** There are 0 callback edges.
- **ClientConnectionsShutdown.java:86-88, `sce.getPreviousStatus` / `sce.getStatus` low: fixed.** They are now `com.netflix.discovery.StatusChangeEvent#…`, medium (3 of 3).

v2 systematic patterns:
1. **instanceof pattern bindings untyped (about 87): fixed.** 0 low edges remain on an instanceof-bound receiver. For example, `h2e.error` is now `io.netty.handler.codec.http2.Http2Exception#error`, `httpContent.content` is `io.netty.handler.codec.http.HttpContent#content`, and `headersFrame.isEndStream` is `io.netty.handler.codec.http2.Http2HeadersFrame#isEndStream`, all medium.
2. **Multi-segment named receiver emitted as `.member` (59): fixed, with an 11-edge remainder in a new form.**
   - 0 low `.m` edges have a named receiver. All 1,050 remaining `.m` edges are computed receivers, chain continuations, `super.m()` with an out-of-scan superclass (109), or `X.class.m()` (10).
   - `java.security.Security.addProvider` is now `java.security.Security#addProvider`, medium.
   - `state.future.complete` is now `java.util.concurrent.CompletableFuture#complete`, medium.
   - `hqp2.delegate.entries` is now `com.google.common.collect.ListMultimap#entries`, medium.
   - `System.err.println` is now `err.println`, low (3 edges, correct per spec).
   - `this.context.getSecurityParametersHandshake` is now `context.getSecurityParametersHandshake`, low. This is correct because `context` is inherited from the external BouncyCastle superclass.
   - The remainder is the in-scan enum case in the v2 list (`PushProtocol.SSE.getPath`). It is now `SSE.getPath`, low, rather than `PushProtocol#getPath`, high. That is 11 edges, pattern 2 above.
3. **Inherited in-scan member attributed to the subtype at medium (147): fixed. 0 remain.**
   - Every edge whose callee is an in-scan `Type#m` names the type that declares `m` (2,382 high). `HttpRequestMessage#getContext` and `HttpResponseMessage#getHeaders` now have 0 edges, and `ZuulMessage#getContext` is high (71).
   - The 85 medium edges on in-scan types are all members not declared in the scan (`getClass`, `name`, Lombok getters, members inherited from external supertypes), which is correct.
   - The 40 "not found" high edges were checked by hand and are gaps in my index, not tool errors. They are `ZuulToNettyHttpHeaders#firstValue` (annotated return type, declared at line 249) and the components of the multi-line record `ConnectionPoolMetrics`.
   - A related residual not seen in v2 is type-variable receivers (27, pattern 1 above).
4. **Other untyped variable kinds (about 30): mostly fixed. 9 remain.**
   - Fixed:
     - catch parameters: `ex.getReason` is `java.net.URISyntaxException#getReason`.
     - `static {}` locals: `runningFilterIndexKeys.put` is `java.util.Map#put`, and `context.getSocketFactory` is `javax.net.ssl.SSLContext#getSocketFactory`.
     - record components: `maxJitter.toMillis` is `java.time.Duration#toMillis`.
     - inherited fields: `logger.debug` at CurrentPassport.java:474 is `org.slf4j.Logger#debug`, and `MAX_*.get` at PushChannelInitializer.java:50 is `com.netflix.config.CachedDynamicIntProperty#get` ×3.
   - The record-component edge now has a wrong caller (`#<clinit>`, pattern 5 above).
   - Correction: `log.debug` at Http2ConnectionCloseHandler.java:67 is not an inherited field. `log` is generated by Lombok `@Slf4j`, so low is correct (3 such edges).

v2 "Previous findings" items:
- **A. ALL_CAPS static fields treated as types (271 in v1, 12 in v2): partly fixed, 9 remain.** The 3 PushChannelInitializer edges are fixed. The 9 in OutboundErrorType are still present (interface fields used by an enum, pattern 3 above).
- **B. Empty caller_id: fixed. Still 0.** There are 481 implicit edges (422 `<clinit>`, 59 `<init>`), the same as v2.
- **C. Declared types of locals, parameters and fields: fixed, apart from the residuals listed above.** The low edges with a named receiver fell from 168 in v2 to 129. Of those 129, 58 are untyped lambda parameters (correct) and about 60 are external static-constant, Lombok or external-inherited-field receivers (correct per spec). Only 19 are errors: 11 enum constants and 8 qualified-`this` calls.
- **D. External types package-qualified: fixed.** The inline fully qualified `java.security.Security.addProvider` is now qualified. The only unqualified non-`java.lang` external types left are the 5 same-package `com.netflix.config` supertypes and 1 inherited nested type, both spec gaps above.
- **v1 method reference `nativeHeaders::add`: still correct.** Method references produce no edges. This was confirmed again for `HttpRequest::uri` and `SessionContext::getUUID` in `buildZuulHttpRequest`.
