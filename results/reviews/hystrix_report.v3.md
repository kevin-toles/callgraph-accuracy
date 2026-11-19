# hystrix (java) call-graph review, v3

**Summary:** precision 50/50 (4 of them spec gaps); recall: 0 missed of 58 real calls; 0 non-calls

Scope: 9,092 of 31,477 edges are in scope (`.java` files outside test/ etc.; `src/jmh/` is included because the spec does not exclude it). In-scope confidence: high 4,381 / medium 3,486 / low 1,225 / unknown 0. Compared with v2, 311 edges moved to high, 217 out of medium and 94 out of low. Call types: method 7,136 / constructor 1,505 / implicit 451. No in-scope edge has an empty `caller_id`.

Sample: 50 edges, drawn at random with a fixed seed and stratified roughly by tier (24 high, 19 medium, 7 low; no unknown edges exist). They come from 34 files in 7 modules, and 1 edge is in `src/jmh`.

**Precision caveat:** with 0 errors in 50, the sample alone only shows precision is above about 94% (rule of three, 95% confidence). It cannot separate 95% from 99%. The scripted census in "Systematic patterns" settles that question. It finds 14 wrong edges among the 9,092 in-scope edges (about 99.8%), plus 4 spec-gap families covering about 450 edges.

## Precision sample verdicts

| # | file:line | tool said | verdict |
|---|---|---|---|
| 0 | HystrixRequestCacheManager.java:52 | `#clearCache` → `com.netflix.hystrix.HystrixRequestCache#getInstance` high | OK |
| 1 | HystrixYammerMetricsPublisherCommand.java:143 | `#initialize` → `#safelyCreateCumulativeGauge` high | OK (declared line 411) |
| 2 | HystrixCommandAspect.java:346 | `#setFallbackMethod` → `...utils.FallbackMethod#getMethod` high | OK (local `FallbackMethod fallbackMethod`; chain call on its own line) |
| 3 | HystrixRollingPercentile.java:520 | `...ListState#incrementTail` → `...BucketCircularArray.ListState#<init>` high ctor | OK |
| 4 | HystrixMetricsPoller.java:387 | `MetricsPoller#getCommandJson` → `com.netflix.hystrix.HystrixCommandProperties#requestCacheEnabled` high | OK (local `HystrixCommandProperties commandProperties`, line 358) |
| 5 | AbstractCommand.java:570 | `#executeCommandAndObserve` → `...HystrixRequestContext#getContextForCurrentThread` high | OK |
| 6 | HystrixCodaHaleMetricsPublisherCommand.java:42 | `#<clinit>` → `#logger` high implicit | OK (on the field's line) |
| 7 | HystrixCommandExecutionHookDefault.java:25 | `#INSTANCE` → `#<init>` high ctor | OK |
| 8 | CommandExecutionAndConcurrentMetricsReadPerfTest.java:118 (jmh) | → `HystrixCommandMetrics#getExecutionTimeMean` high | OK |
| 9 | HystrixYammerMetricsPublisherCommand.java:290 | → `#createTotalLatencyPercentileGauge` high | OK |
| 10 | HystrixCommandAspect.java:251 | `CollapserMetaHolderFactory#create` → `...command.ExecutionType#getExecutionType` high | OK |
| 11 | HystrixCodaHaleMetricsPublisherCollapser.java:73 | → `#safelyCreateCumulativeCountForEvent` high | OK |
| 12 | HystrixYammerMetricsPublisherCommand.java:181 | → `#safelyCreateRollingGauge` high | OK |
| 13 | HystrixEventNotifierDefault.java:26 | `#INSTANCE` → `#<init>` high ctor | OK |
| 14 | HystrixRequestEvents.java:46 | → `com.netflix.hystrix.HystrixInvokableInfo#getCommandKey` high | OK |
| 15 | HystrixEventType.java:133 | `HystrixEventType.Collapser#<clinit>` → `HystrixEventType.Collapser#<init>` high ctor (3 edges for `BATCH_EXECUTED, ADDED_TO_BATCH, RESPONSE_FROM_CACHE;`) | spec gap (Java enum-constant declarations; see table) |
| 16 | HystrixYammerMetricsPublisherCollapser.java:59 | → `#createMetricName` high | OK |
| 17 | HystrixYammerMetricsPublisherCommand.java:270 | → `#createCurrentValueGauge` high | OK |
| 18 | HystrixDynamicPropertiesSystemProperties.java:44 | `#getString` → `...HystrixDynamicProperty#<init>` high ctor | spec gap (anonymous class of an interface) |
| 19 | MetaHolder.java:323 | `#getRaiseHystrixExceptions` → `MetaHolder#nonEmptyList` high | OK (`this.<HystrixException>nonEmptyList()`) |
| 20 | HystrixYammerMetricsPublisherCollapser.java:261 | → `#createMetricName` high | OK |
| 21 | HystrixCommandAspect.java:347 | → `FallbackMethod#getMethod` high | OK |
| 22 | MetaHolder.java:243 | `#getCommandIgnoreExceptions` → `...javanica.annotation.HystrixCommand#ignoreExceptions` high | OK (field `private final HystrixCommand hystrixCommand` is the javanica annotation) |
| 23 | HystrixServoMetricsPublisherCommand.java:577 | → `HystrixServoMetricsPublisherAbstract.InformationalMetric#<init>` high ctor | OK (abstract class with a constructor, line 39) |
| 24 | Hystrix.java:168 | `ConcurrentStack#pop` → `java.util.concurrent.atomic.AtomicReference#get` medium | OK |
| 25 | HystrixCommandAspect.java:91 | → `IllegalStateException#<init>` medium ctor | OK (java.lang) |
| 26 | HealthCountsStream.java:77 | → `java.util.concurrent.ConcurrentMap#putIfAbsent` medium | OK (declared `ConcurrentMap`) |
| 27 | HystrixObservableCollapser.java:402 | `#observe` → `rx.functions.Action0#<init>` medium ctor | spec gap (anonymous class of an external interface) |
| 28 | HystrixServoMetricsPublisherThreadPool.java:127 | → `org.slf4j.Logger#error` medium | OK |
| 29 | FallbackMethod.java:284 | `#regularEquals` → `com.google.common.base.Objects#equal` medium | OK (explicit import line 19) |
| 30 | FallbackMethod.java:275 | `#equals` → `java.lang.reflect.WildcardType#getUpperBounds` medium | OK (local `final WildcardType wt1`) |
| 31 | HystrixRollingPercentile.java:126 | `#<init>` → `IllegalArgumentException#<init>` medium | OK |
| 32 | EnvUtils.java:41 | `#getWeavingMode` → `java.util.Arrays#toString` medium | OK |
| 33 | Striped64.java:324 | `Striped64#<clinit>` → `Class#getDeclaredField` medium | OK (`static {}` block; continuation line `(sk.getDeclaredField("base"));`) |
| 34 | HystrixPropertiesFactory.java:143 | → `java.util.concurrent.ConcurrentHashMap#get` medium | OK |
| 35 | HystrixYammerMetricsPublisherCommand.java:503 | `#rollingMaxConcurrentExecutionCountThunk` → `rx.functions.Func0#<init>` medium ctor | spec gap (anonymous class of an external interface); caller as a field initializer is OK |
| 36 | HystrixRequestContext.java:84 | → `ThreadLocal#get` medium | OK |
| 37 | TypeHelper.java:92 | → `java.lang.reflect.ParameterizedType#getActualTypeArguments` medium | OK (local `ParameterizedType pType = (ParameterizedType) root`) |
| 38 | SerialHystrixDashboardData.java:161 | → `com.fasterxml.jackson.core.JsonGenerator#writeNumberField` medium | OK |
| 39 | HystrixConfigurationJsonStream.java:133 | → `JsonGenerator#writeNumberField` medium | OK |
| 40 | HystrixCircuitBreaker.java:165 | `#subscribeToStream` → `rx.Subscriber#<init>` medium ctor | OK (abstract class) |
| 41 | MethodProvider.java:240 | `#unbride` → `org.objectweb.asm.ClassVisitor#<init>` medium ctor | OK |
| 42 | HystrixConfigurationJsonStream.java:82 | → `JsonGenerator#writeObjectFieldStart` medium | OK |
| 43 | HystrixServoMetricsPublisherThreadPool.java:197 | → `.build` low | OK (call-result receiver) |
| 44 | HystrixCircuitBreaker.java:165 | → `.subscribe` low | OK (chain, own line) |
| 45 | HystrixCommandProperties.java:447 | `#getProperty` → `.add` low | OK (chain on `forString()` result) |
| 46 | HystrixYammerMetricsPublisherCommand.java:365 | → `.get` low | OK |
| 47 | AbstractCommand.java:1727 | `#isRequestCachingEnabled` → `.get` low | OK |
| 48 | AopUtils.java:174 | `#getMethodInfo` → `.append` low | OK (the first `info.append` on the line is separately `StringBuilder#append` medium) |
| 49 | HystrixServoMetricsPublisherAbstract.java:54 | `CounterMetric#<init>` → `.withAdditionalTag` low | OK |

Callers, lines and call_types were correct on all 50. The random sample did not hit a wrong edge. The wrong edges below come from scripted searches for each previous pattern and for residual `recv.m` / unqualified edges.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| hystrix-core/.../ExecutionResult.java:86 | `newBitSet.set(HystrixEventType.EMIT.ordinal());` | `ExecutionResult.EventCounts#<init>` → `EMIT.ordinal`, low, method | `com.netflix.hystrix.HystrixEventType#ordinal`, medium (`ordinal` is inherited from `java.lang.Enum`, outside the scan) | wrong callee / wrong confidence | enum constant `Type.CONST` not typed as `Type` (13 edges, pattern 1) |
| hystrix-core/.../HystrixCommandMetrics.java:424 | `long successCount = eventTypeCounts[HystrixEventType.SUCCESS.ordinal()];` | `HealthCounts#plus` → `SUCCESS.ordinal`, low | `com.netflix.hystrix.HystrixEventType#ordinal`, medium | wrong callee / wrong confidence | same as above |
| hystrix-contrib/hystrix-javanica/.../EnvUtils.java:30 | `WEAVING_MODE = System.getProperty("weavingMode", WeavingMode.RUNTIME.name()).toUpperCase();` | `EnvUtils#<clinit>` → `RUNTIME.name`, low | `com.netflix.hystrix.contrib.javanica.aop.aspectj.WeavingMode#name`, medium | wrong callee / wrong confidence | same as above |
| hystrix-core/.../HystrixCommand.java:388 | `if (HystrixCommand.this.getProperties().executionIsolationThreadInterruptOnFutureCancel().get()) {` | `HystrixCommand#queue` → `this.getProperties`, low | `com.netflix.hystrix.AbstractCommand#getProperties`, high (declared AbstractCommand.java:1331; HystrixCommand extends AbstractCommand) | wrong callee / wrong confidence | qualified `Outer.this.m()` treated as an unknown receiver named `this` (1 edge) |
| hystrix-core/.../HystrixThreadPoolKey.java:52 | `super(name);` (in `private static class HystrixThreadPoolKeyDefault extends HystrixKeyDefault`, line 50; `HystrixKeyDefault` is a member of the superinterface `HystrixKey`, HystrixKey.java:17) | `HystrixThreadPoolKey.Factory.HystrixThreadPoolKeyDefault#<init>` → `HystrixKeyDefault#<init>`, medium, constructor | `com.netflix.hystrix.HystrixKey.HystrixKeyDefault#<init>`, high (HystrixCommandKey.java and HystrixCommandGroupKey.java, which write `HystrixKey.HystrixKeyDefault`, get this right) | wrong callee / wrong confidence | simple name of a member type inherited through the enclosing interface's superinterface is not resolved (1 edge) |
| hystrix-core/.../HystrixEventType.java:133 | `BATCH_EXECUTED, ADDED_TO_BATCH, RESPONSE_FROM_CACHE;` (enum `Collapser`, no explicit constructor) | `HystrixEventType.Collapser#<clinit>` → `HystrixEventType.Collapser#<init>`, high, constructor ×3 | Java enum-constant declarations do run the constructor during `<clinit>`. The spec lists "enum-variant/data construction" as not a call, but its examples are Rust/Haskell. It does not say whether a Java enum-constant declaration counts, or whether an implicit constructor counts as "defined" | spec gap | 91 edges |
| hystrix-core/.../strategy/properties/HystrixDynamicPropertiesSystemProperties.java:44 | `return new HystrixDynamicProperty<String>() {` (`public interface HystrixDynamicProperty<T>`) | → `HystrixDynamicProperty#<init>`, high, constructor | The spec does not cover anonymous-class instantiation of an interface, which has no constructor | spec gap | 63 in-scan edges, ≥303 external |
| hystrix-core/.../strategy/concurrency/HystrixContextScheduler.java:150 | `subscription.unsubscribe();` (field `CompositeSubscription subscription`; type comes from `import rx.subscriptions.*;`) | → `CompositeSubscription#unsubscribe`, medium | The spec says external types are qualified "through its explicit import". It does not cover wildcard imports (`rx.subscriptions.CompositeSubscription` would be the full name) | spec gap | 18 edges, all in this file |

## Recall detail

| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| `com.netflix.hystrix.HystrixCollapser#toObservable` (lines 381–412; body is an anonymous `Func0.call`) | 17 | 17 | 0 | 0 |
| `com.netflix.hystrix.HystrixCollapser#execute` (lines 426–443) | 8 | 8 | 0 | 0 |
| `com.netflix.hystrix.serial.SerialHystrixRequestEvents#convertExecutionToJson` (lines 64–100, hystrix-serialization) | 33 | 33 | 0 | 0 |

Every edge had the correct line, caller, callee and tier:
- The anonymous-class body in `toObservable` is folded into the enclosing method. Fields resolve to their in-scan types, high: `HystrixRequestCache#get`/`#putIfAbsent`, `HystrixCollapserMetrics#markResponseFromCache`, `RequestCollapserFactory#getRequestCollapser`.
- The catch parameter `e` in `execute` gives `Throwable#getCause` medium (2 edges, lines 434 and 435). `getClass()` gives `HystrixCollapser#getClass` medium (inherited from Object, outside the scan).
- Enum locals give `HystrixEventType#name` / `#equals` / `#values` medium, and `ExecutionResult.EventCounts#contains` is high. Chained receivers are `.name` / `.contains` low.

The functions are in 2 modules. I chose `HystrixCollapser.java` twice on purpose, to exercise the catch-parameter and anonymous-class paths. I also checked `toJsonString` in the same file as the third function: the inherited field `jsonFactory` now gives `com.fasterxml.jackson.core.JsonFactory#createGenerator` medium.

## Systematic patterns

All counts are scripted over the 9,092 in-scope edges.

1. **Enum constant used as a receiver (`Type.CONST.m()`) gives `CONST.m`, low.** 13 edges: `HystrixEventType.{EMIT, FALLBACK_EMIT, COLLAPSED}.ordinal()` 6 (ExecutionResult.java), `HystrixEventType.{SUCCESS, FAILURE, TIMEOUT, THREAD_POOL_REJECTED, SEMAPHORE_REJECTED}.ordinal()` 5 (HystrixCommandMetrics.java:424–428), `WeavingMode.RUNTIME.name()` 1, and `UnpooledByteBufAllocator.DEFAULT.buffer` 1. The last one is an external static field of unknown type, so `DEFAULT.buffer` low is spec-correct. That leaves **12 wrong edges**. Root cause: a static field reached through a type name is not typed, even when it is an enum constant of a scanned enum. Fixing it moves 12 edges from low to medium with the correct callee.
2. **Qualified `Outer.this.m()` gives `this.m`, low.** 1 edge (HystrixCommand.java:388).
3. **Simple name of a member type inherited from a superinterface of the enclosing type is not resolved.** 1 edge (HystrixThreadPoolKey.java:52 → `HystrixKeyDefault#<init>` medium).
4. **Remaining `recv.m` low edges are spec-correct.** 30 such edges remain (41 in v2). 12 are pattern 1 and 1 is pattern 2. The other 17 are spec-correct:
   - 8 `prop.getX`: `prop` is inherited from the external `com.netflix.config.PropertyWrapper`, so its type is unknown.
   - 1 `DEFAULT.buffer` (external).
   - 8 field chains on a call result, which the spec covers as `a.b.c()` → `b.c`: `getInstance().notifier.set` and similar ×5, `...getInstance(threadPoolKey).concurrentExecutionCount.get`, `getContextForCurrentThread().state.put`, `getCurrentBucket().data.addValue`.
5. **Spec gap: Java enum-constant declarations give `Enum#<clinit>` → `Enum#<init>` constructor edges, high.** 91 edges, one per constant on the constant's line. This is the largest unaddressed family. If the spec ruled them "not a call", it would cost about 1% of precision.
6. **Spec gap: anonymous classes of interfaces give `Iface#<init>`.** In-scan: 63 high (`HystrixPropertiesManager.PropSetter` 39, `HystrixProperty` 9, `HystrixDynamicProperty` 4, `InternMap.ValueConstructor` 3, `HystrixRequestVariableLifecycle` 3, `HystrixCollapserBridge` 2, 3 others). External, at least 303 medium (`rx.functions.Func0` 182, `Func1` 43, `Action0` 34, `Action1` 15, `Func2` 12, `Runnable` 7, `Callable` 4, ...).
7. **Spec gap: types reached only through wildcard imports stay unqualified, medium.** 18 edges, all in HystrixContextScheduler.java (`import rx.*; import rx.subscriptions.*; import java.util.concurrent.*;`): `CompositeSubscription` 5, `Worker` 4, `FutureTask` 3, `ThreadPoolExecutor` 2, `RejectedExecutionException` 2, `Scheduler` 1, `Subscriptions` 1.
8. **Not errors:** 129 medium edges target in-scan types. Every one is a member inherited from outside the scan, which the spec says is medium: `Enum#ordinal`/`name`/`values`/`valueOf`, `Object#getClass`/`equals`/`hashCode`, `Throwable#getCause`, `ThreadLocal#get`, `PropertyWrapper#getValue`/`addCallback`/`getName`. There are also 3 `isNotTimedOut` edges, the spec gap from v2.

**Effect on precision:** fixing patterns 1–3 corrects 14 edges, about 0.15% of the in-scope edges. Settling the spec on patterns 5 and 6 decides up to about 460 edges (about 5%), so the spec wording now matters more than any remaining tool bug.

## Previous findings

| previous item | status | counts |
|---|---|---|
| Table rows HystrixCommandProperties.java:105, :115; HystrixCollapserProperties.java:64; HystrixCommand.java:201 (`Setter` → `HystrixCollapser.Setter`) | **Fixed** | They now give `HystrixCommandProperties.Setter#<init>` / `#getCircuitBreakerEnabled`, `HystrixCollapserProperties.Setter#getMaxRequestsInBatch` and `HystrixCommand.Setter#<init>`, all high. |
| Table rows HystrixCommandAspect.java:202/205/215/228 and :275 (javanica annotation lost to a same-package class) | **Fixed** | They now give `...javanica.annotation.HystrixCollapser#batchMethod` ×4 and `...javanica.annotation.HystrixCommand#observableExecutionMode` ×2. 0 edges still target the core classes. |
| Table row HystrixCommandAspect.java:242 (`Builder#ajcMethod` medium) | **Fixed** | `...command.MetaHolder.Builder#ajcMethod` high. 19 `MetaHolder.Builder` edges are high, and 0 bare `Builder#` edges remain. |
| Table row HystrixPropertiesManager.java:224 | **Fixed** | `com.netflix.hystrix.HystrixCommandProperties.Setter#withMetricsRollingStatisticalWindowInMilliseconds` high. |
| Table row HystrixRequestEventsJsonStream.java:73 (`Entry#getKey`) | **Fixed** | `java.util.Map.Entry#getKey`/`#getValue` medium: 26 edges, 0 bare `Entry#`. |
| Table row HystrixCodaHaleMetricsPublisherCommand.java:53 (`HystrixCommandKey#name`) | **Fixed** | `com.netflix.hystrix.HystrixKey#name` high. |
| Table row HystrixEventType.java:95 (`EXCEPTION_PRODUCING_EVENT_TYPES#add`) | **Fixed** | `java.util.List#add` medium, 6 edges in that file. |
| Table row AbstractHystrixCommand.java:51 (`com#<init>`) | **Fixed** | `com.netflix.hystrix.HystrixCommand#<init>` high. |
| Table row BatchHystrixCommand.java:76 (`CommonUtils#createArgsForFallback`) | **Fixed** | `com.netflix.hystrix.contrib.javanica.utils.CommonUtils#createArgsForFallback` high in all 3 callers. |
| Table row HystrixCollapser.java:434 (catch param `e.getCause`) | **Fixed** | `Throwable#getCause` medium (lines 434 and 435, confirmed in recall). |
| Table row SerialHystrixRequestEvents.java:39 (inherited field `jsonFactory`) | **Fixed** | `com.fasterxml.jackson.core.JsonFactory#createGenerator` medium. |
| Table row HystrixProperty.java:53, spec gap (anonymous class of an interface) | **Still present (spec gap)** | Still `HystrixProperty#<init>` high. The family is 63 in-scan edges and at least 303 external (pattern 6). |
| Table row MetaHolder.java:249, spec gap (annotation elements medium) | **Changed: now high** | All 32 javanica annotation-element edges are high (`HystrixCommand` 9, `DefaultProperties` 9, `HystrixCollapser` 6, `HystrixProperty` 5, `ObservableExecutionMode` 2, `HystrixException` 1). This is consistent with "defined in the scanned source"; the spec is still silent on it. |
| Pattern 1: nested `Setter` resolves to `HystrixCollapser.Setter` | **Fixed** | 6 edges target `HystrixCollapser.Setter#` (was 62). 4 are in HystrixCollapser.java itself, 1 is GenericSetterBuilder.java:108 `HystrixCollapser.Setter.withCollapserKey` (`import com.netflix.hystrix.HystrixCollapser`), and 1 is CollapserPerfTest.java:102 (a subclass of HystrixCollapser). All 6 are correct. Each class's own `Setter` now resolves correctly: `HystrixCommandProperties.Setter` 72, `HystrixCollapserProperties.Setter` 31, `HystrixThreadPoolProperties.Setter` 26, and so on. |
| Pattern 2: `Outer.Inner` types emitted as the bare inner name (103 edges) | **Fixed (only the wildcard-import spec gap remains)** | 0 bare `Setter#`/`Entry#`/`Builder#`/`DefaultProperties#`/`Collapser#`/`OnSubscribe#` edges remain. `ImmutableList.Builder` becomes `com.google.common.collect.ImmutableList.Builder` (2) and `OnSubscribe` becomes `rx.Observable.OnSubscribe` (1). The 4 `Worker#` edges remain, but they come through `import rx.*` (pattern 7, spec gap). |
| Pattern 3: inherited superinterface members keep the receiver type (`HystrixCommandKey#name` 64, ...) | **Fixed** | `com.netflix.hystrix.HystrixKey#name` high: 114 edges. 0 `HystrixCommandKey#name` / `HystrixThreadPoolKey#name` / `HystrixCommandGroupKey#name` edges remain. |
| Pattern 4: explicit import loses to a same-package type (6 edges) | **Fixed** | 0 remaining. |
| Pattern 5: receivers outside the declaration scope stay `recv.m` low (41 edges) | **Fixed (new residue, different cause)** | 30 `recv.m` edges remain, and 17 of those are spec-correct. The 24 inherited-field and 13 catch-parameter edges from v2 are all resolved; 0 edges have a catch-parameter receiver (`e.`, `ex.`, `t.`, `throwable.`). The `prop` 8 are spec-correct (inherited from an external class). New residue: 12 enum-constant receivers (pattern 1) and 1 `Outer.this` (pattern 2). |
| Pattern 6: static field name used as type (`EXCEPTION_PRODUCING_EVENT_TYPES#add` 5, `TERMINAL_EVENT_TYPES#add` 1) | **Fixed** | 0 remaining. |
| Pattern 7: fully qualified `extends` gives `com#<init>` (1) | **Fixed** | 0 remaining. |
| Pattern 8: static import `CommonUtils#createArgsForFallback` unqualified (3) | **Fixed** | 0 remaining. All are qualified and high. |
| v2's "Previous findings" spec gap: anonymous class of an interface (HystrixCommandKey.java:33 `InternMap.ValueConstructor#<init>`) | **Still present (spec gap)** | Unchanged: `com.netflix.hystrix.util.InternMap.ValueConstructor#<init>` high. |
