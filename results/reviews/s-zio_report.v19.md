# Blind call-graph review: s-zio (scala), round 19

precision 45/50; census ≈98.9% (481 wrong of 44521 in-scope); recall: 8 missed of 29 real calls; 0 non-calls

## Scope
Tool output `<scans>/final29-A/s-zio.v2.json` has 95,964 edges. In scope: 44,521 edges from `.scala` files in 469 files. Out of scope: 1,466 edges from other languages (796 .jsx, 628 .js, 38 .ts, 4 .java) and 49,977 Scala edges under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment. Vendored, generated and fixture code (`scalafix/input`, `scalafix/output`, `benchmarks/`, `project/`, `documentation/`, `specs/`, `zio-examples/`) is in scope.
- Confidence: high 26,557, low 10,838, medium 5,614, unknown 1,512.
- call_type: method 35,477, direct 3,947, constructor 2,232, callback 1,512, implicit 1,353.

I ignored the `measured_accuracy` field. I did not read earlier reports or other rounds' helper scripts. Helpers (all `s-zio_r19_*` in the fanout folder): `_load.py`, `_sample.py` (sample, seed 19), `_show.py`, `_index.py` (a text-only Scala definition index: types, companion and class members kept apart, declared return types, parents), `_typer.py` (receiver typer), `_census_typed.py`, `_census_misc.py`, `_census_misc2.py`, `_localfn.py`, `_highcheck.py`, `_medcheck.py`, `_final.py` (union), `_recall.py`.

## Precision sample
I took 50 edges, stratified by confidence: high 28, low 11, medium 6, unknown 5. They come from 36 files, at most 2 per file, with `random.seed(19)`.
- 45 are correct.
- 2 are wrong: #29 and #37, both typed receivers left as low guesses.
- 3 are spec gaps: #10 and #24 (case-class apply) and #21 (Scala 3 top-level def).

Some correct items worth noting:
- `suite`/`test` resolve to `zio.test.ZIOSpec#suite`/`#test`, which ZIOSpecDefault inherits.
- `equalTo` resolves to `zio.test.AssertionVariants#equalTo`, through `object Assertion extends AssertionVariants`.
- `ZIO.succeed` resolves to `zio.ZIOCompanionVersionSpecific#succeed`, the superclass in the scan.
- `chunk.filterNot` gives `zio.Chunk#filterNot` medium: it is inherited from an external base.
- `AtomicLongArray` is qualified through the file's single wildcard `java.util.concurrent.atomic._`.
- `new Thread` gives `java.lang.Thread#<init>`.
- Callbacks through parameters and lambda parameters (`f`, `p`, `failure`, `restore`, `showType`) are unknown.
- The local defs `zioMap.sumTo` and `fromAppArgs.stripKey` are high direct.
- `case object CompressionLevel3 extends CompressionLevel(3)` gives `CompressionLevel#<init>` from `CompressionLevel3#<clinit>`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| core/shared/src/main/scala/zio/ZIO.scala:4673 (sample #29) | `mergeAllPar(all)(Option.empty[A])((acc, elem) => Some(acc.fold(elem)(f(_, elem)))).map(_.get)` | zio.ZIO#reduceAllPar → `.map`, low, method | `zio.ZIO#map`, high: `mergeAllPar` is declared `: ZIO[R, E, B]` in the scan | wrong callee / wrong confidence | typed call result (curried) not typed |
| core/shared/src/main/scala/zio/Chunk.scala:806 (sample #37) | `while (continue && iterator.hasNextAt(i)) {` | zio.Chunk#splitWhere → `iterator.hasNextAt`, low, method | `zio.Chunk.ChunkIterator#hasNextAt`, high: `val iterator = self.chunkIterator`, with `def chunkIterator: Chunk.ChunkIterator[A]` | wrong callee / wrong confidence | let-bound parameterless member with declared type not typed |
| core/shared/src/main/scala/zio/Chunk.scala:3106 (sample #10) | `else BooleanArray(array, self.offset + offset, self.length - offset min length)` | zio.Chunk.BooleanArray#sliceIterator → zio.Chunk.BooleanArray#apply, high, method | undecided (scala/16) | spec gap | case-class apply |
| core/shared/src/main/scala/zio/internal/macros/Graph.scala:30 (sample #24) | `Graph(nodes.map(_.map(f)), keyEquals, unknownLayerFactory(_).map(_.map(f)))` | zio.internal.macros.Graph#map → zio.internal.macros.Graph#<init>, high, constructor | undecided (scala/16) | spec gap | case-class apply (note: same construct as #10, different ID form) |
| specs/snippet-check/showcase.scala:48 (sample #21) | `def connectDatabase(): Task[DbConn] = ZIO.succeed(new DbConn)` | `connectDatabase` → zio.ZIOCompanionVersionSpecific#succeed, high, method | callee correct; caller ID undecided (scala/18) | spec gap | Scala 3 top-level def |
| core/shared/src/main/scala/zio/stm/TRef.scala:44 | `this(new AtomicReference(versioned.value), todo.get())` | zio.stm.TRef#<init> → `this`, low, direct | `zio.stm.TRef#<init>`, constructor | wrong callee | auxiliary-constructor `this(...)` emitted as a bare name |
| core/shared/src/main/scala/zio/Config.scala:67 | `case ex if nonFatal(ex) => Left(Config.Error.InvalidData(Chunk.empty, ex.getMessage))` | zio.Config#mapAttempt → `zio.Config.Error#InvalidData`, medium, method | not any undecided-option ID; `zio.Config.Error` has no member `InvalidData` (C2) | wrong callee | nested case class rendered as a method of its outer type |
| scalafix/output/src/main/scala/fix/ZManagedSpec.scala:40 | `program  = res(1) *> res(2) *> res(3)` (with `res = (x: Int) => ZManaged.acquireReleaseWith(...)`) | zio.ZManagedSpec#spec → `res`, low, direct | named nested function `spec.res` high, or callback `res` unknown; never a low bare direct name | wrong callee / wrong call_type | local function value treated as unresolved bare name |
| core/shared/src/main/scala/zio/ZIO.scala:3779 | `case s: Success[A] => k(Exit.succeed(s.value))` | zio.ZIO#fromFuture → `k`, low, direct | `k`, callback, unknown (parameter holding a function) | wrong call_type / confidence | call through parameter not classified as callback |
| scalafix/input/src/main/scala/fix/ZManagedSpec.scala:1200 | `res    <- managed.timeout(Duration.Zero).use(...)` | zio.ZManagedSpec#spec → `zio.managed.timeout`, medium, direct | `managed.timeout`, low, method (local generator binding) | wrong callee | local named `managed` resolved to the scanned package `zio.managed` |
| core/native/src/main/scala/zio/QueuePlatformSpecific.scala:14 | `offer(a)` in `final class ConcurrentDeque[A <: AnyRef] extends ConcurrentLinkedQueue[A]` | …ConcurrentDeque#addFirst → `offer`, low, direct | `zio.QueuePlatformSpecific.ConcurrentDeque#offer`, medium, method | wrong callee / confidence | open defect scala/03 (inherited external member) |
| streams/jvm/src/main/scala/zio/stream/platform.scala:545 | `new ZStreamConstructor[StreamLike[A]] {` | … → `ZStreamConstructor#<init>`, low, constructor | no edge: `trait ZStreamConstructor` | not a call | anonymous trait instantiation emits a constructor edge |
| core/jvm-native/src/main/scala/zio/SystemPlatformSpecific.scala:27 | `private[zio] val environmentProvider = new EnvironmentProvider {` | … → `scala.jdk.CollectionConverters.EnvironmentProvider#<init>`, medium, constructor | no edge (`private[zio] trait EnvironmentProvider` in zio.System) | not a call | anonymous trait instantiation; also misqualified |
| core/shared/src/main/scala/zio/internal/FiberRuntime.scala:1206 | `cur = flatmap.successK(sync.eval())` (`case flatmap: FlatMap[Any, Any, Any, Any] =>`) | zio.internal.FiberRuntime#runLoop → `FlatMap#successK`, low, method | `zio.ZIO.FlatMap#successK`, high (pattern-typed; `FlatMap` is scanned, reached through `import ZIO._`) | wrong callee / confidence | scanned nested type left unqualified low |
| core/shared/src/main/scala/zio/internal/FiberRuntime.scala:897 | `if (isEnabled(patch, RuntimeFlag.CurrentFiber.mask)) {` after `import RuntimeFlags.Patch.{isDisabled, isEnabled}` | … → `isEnabled`, low, direct | `zio.RuntimeFlags.Patch#isEnabled`, high, method | wrong callee / confidence | explicit selective import not resolved |
| core/shared/src/main/scala/zio/ConfigProvider.scala:413 | `consoleProvider()` (in `lazy val consoleProvider: ConfigProvider =`) | zio.ConfigProvider#consoleProvider → `consoleProvider`, low, direct | `zio.ConfigProvider#consoleProvider`, high, method (overloaded member of the enclosing object) | wrong callee / confidence | bare call of an enclosing member not resolved |
| core/shared/src/main/scala-2/zio/=!=.scala:32 | `private val instance: =!=[Any, Any] = new =!=[Any, Any] {}` | `core/shared/src/main/scala-2/zio/=!=` → `zio.instance`, high, implicit; `zio.instance` → `=!=#<init>`, medium | `zio.=!=#<clinit>` → `zio.=!=#instance`; `zio.=!=#instance` → `zio.=!=#<init>`, high | wrong caller / callee | symbolic type name `=!=` not parsed |
| core/shared/src/main/scala/zio/internal/WeakConcurrentBag.scala:81 | `finally if (lockAcquired) gcStatus.set(false)` | zio.internal.WeakConcurrentBag#gc → `set`, low, direct | a receiver call (`gcStatus.set` or the typed form), method | wrong callee | receiver dropped after `finally if` |
| scalafix/rules/src/main/scala/fix/Zio2Upgrade.scala:660 | `case zManagedNormalized(_) =>` | fix.Zio2Upgrade#fix → `zManagedNormalized`, low, direct | no edge (pattern, C3) | not a call | extractor pattern emitted as a call |
| core/shared/src/main/scala/zio/ZIO.scala:4673 (recall) | `...Some(acc.fold(elem)(f(_, elem)))).map(_.get)` | (no edges for `Option.empty[A]`, `_.get`) | `scala.Option#empty` medium, `.get` low | missed call | open defect scala/12 (calls without parentheses) |
| core/shared/src/main/scala/zio/ZIO.scala:4669 (recall) | `override def iterator: Iterator[Z] = Iterator(z) ++ zs.iterator` | (no edges for `++`, `zs.iterator`) | `++` and `zs.iterator` edges | missed call | open defects scala/13 (infix operators), scala/12 |
| core/shared/src/main/scala/zio/Chunk.scala:803 (recall) | `val iterator = self.chunkIterator` | (no edge) | `zio.Chunk#chunkIterator`, high | missed call | open defect scala/12 |
| core/jvm-native/src/main/scala/zio/internal/ZScheduler.scala:107-108 (recall) | `val currentState = state.get`; `if (worker.nextRunnable ne null)` (×2, lines 88/100) | (no edges) | `java.util.concurrent.atomic.AtomicInteger#get`; `ne` edges | missed call | open defects scala/12, scala/13 |

## Systematic patterns (scripted counts, ordered by count; union 481, no overlaps)
1. **Typed receiver left as a low guess: 261.** These receivers are typed by decision A, the parameterless-member rule, "Typed call results" or the let-bound rule. The declared type is a scanned type that defines the method, so the edge should be `T#m` high. Examples:
   - `self.step(now, in, state).flatMap` → `zio.ZIO#flatMap`
   - `iterator.nextAt` / `hasNextAt` after `val iterator = self.chunkIterator` (46)
   - `self.unsafe.update` → `zio.metrics.Metric.UnsafeAPI#update`
   - `size.map`, where `size: USTM[Int]` → `zio.stm.ZSTM#map`
   - `semaphore.withPermit`, `outgoing.offer` after `val outgoing = Queue.unsafe.bounded[…](…)`.

   Owners: zio.ZIO 75, ChunkIterator 46, ZManaged 26, ZSTM 18, Metric.UnsafeAPI 15, Enqueue 12, ZStream 10, others under 10. The script (`_census_typed.py`) types the receiver from declarations only, keeping companion and instance members apart. It skips generic, function, overload-ambiguous and alias-in-value-position types, `zio.Task`, and scalafix/input receivers typed as `zio.managed.ZManaged`, which that file does not import. 30 random hits were checked by hand; all were correct after those exclusions.
2. **Function value called as a low bare `direct` name: 103.**
   - 79 are locals bound to a function literal: `res = (x: Int) => …` (40), `push` (26), `managed`, `make`, `swap`, `finalize`. These are named nested functions, or at least callbacks.
   - 18 are values holding functions: `memoized <- ZIO.memoize(...)`, `log = makeLogger(ref)`, `shouldProcess <- decide(a)`, `k1`.
   - 6 are parameters: `k`, `cb`.

   None is a "bare name not found in the scan".
3. **Nested case class or object rendered as a member of its outer type: 42.** Examples: `zio.Config.Error#InvalidData`/`#MissingData`/`#SourceUnavailable`, `zio.Fiber.Status#Running`, `zio.stream.ZChannel.MergeDecision#Await`, `zio.stream.ZStream.Handoff.State#Empty`, `zio.ZIO.FinalizersRestorer#MakeParallelN`, `fix.Zio2Upgrade#Renames`, all medium method. The construct itself is undecided (scala/16). These IDs are wrong under every option, because they name a member of a scanned type that does not exist (C2).
4. **Local `managed` resolved as the package `zio.managed`: 18.** Examples: `zio.managed.timeout`, `.use`, `.use_`, `.useDiscard`, `.withEarlyReleaseExit`, medium direct, in scalafix ZManagedSpec.
5. **Bare call of a member inherited from an external base left low: 16** (open defect scala/03). Examples:
   - `ConcurrentDeque` `poll`/`offer`
   - `Chunk#dedupe` `foreach`
   - `FiberFailure`/`ChannelFailure` `addSuppressed`/`getSuppressed`
   - `FiberRuntime.AsyncContWith.Callback` (extends `AtomicBoolean`) `compareAndSet`
   - `MutableSetCompat` `add`/`remove` (2 files)
   - `Config.Error#getMessage` `toString()`.
6. **Anonymous `new Trait {…}` emits a constructor edge: 10.** Examples: `ZStreamConstructor` (6), `EnvironmentProvider` (2), `UnsafeAPI` (2).
7. **`this(...)` auxiliary-constructor delegation emitted as bare `this`, low direct: 9.**
8. **Scanned nested type left unqualified low: 8.** These are in FiberRuntime: `FlatMap#successK`, `Stateful#onState`, `UpdateRuntimeFlagsWithin.DynamicNoBox#f` (2), `WhileLoop#body`/`#process`, and `UnsafeAPI#addObserver`/`#removeObserver`.
9. **Imported or enclosing member called bare, left low: 7.**
   - `log` after `import scala.math.log` (2)
   - `isEnabled`/`isDisabled` after a selective import
   - `attemptOrDieZIO` inside `ZIO.ReleaseExit`, which should be `zio.ZIOCompanionVersionSpecific#attemptOrDieZIO` (2)
   - `consoleProvider()`.
10. **Symbolic type name `=!=` not parsed: 5.** These have a file-path caller, the callee `zio.instance`, `=!=#<init>` medium, and the caller `zio.unexpected`, in the Scala 2 and Scala 3 files.
11. **Misc: 2.** These are the bare `set` for `gcStatus.set(false)`, and the extractor pattern `case zManagedNormalized(_)`.

Checked and not counted as wrong:
- **External types behind several wildcard imports, kept unqualified and low.** Examples: `AtomicReference#compareAndSet` in UnboundedHub, which imports `java.util.concurrent.atomic._` plus `UnboundedHub._`, and `Charset#newDecoder`. SPEC's honest-low rule covers these.
- **Medium edges on scanned types inherited from external bases.** Examples: `ChunkBuilder#result`, `OneShot#lock`, `Chunk#foreach`.
- **High edges.** `_highcheck.py` flagged 52, all of them parser limits of my index (Scala 3 indentation files, NewEncodingBenchmark), not tool errors.

## Missed-call patterns (recall)
I picked 3 functions:
- `zio.ZIO#reduceAllPar` (ZIO.scala:4660–4674): 12 real calls, 4 missed.
- `zio.Chunk#splitWhere` (Chunk.scala:802–815): 5 real calls, 1 missed.
- `zio.internal.ZScheduler#metrics` (ZScheduler.scala:65–112, including its folded anonymous `ExecutionMetrics` members): 12 real calls, 3 missed.

That is 8 missed of 29 real calls. I did not count primitive Int/Boolean operators (`&&`, `+=`, `!=`, `&`, `>>`) as calls. There were no non-calls. All misses fall under open defects:
- **Calls without parentheses (scala/12): 5.** These are `zs.iterator`, `Option.empty[A]`, `_.get`, `self.chunkIterator` and `state.get`.
- **Infix operator calls (scala/13): 3.** These are `++` and `ne` ×2.

The recall functions also hit census patterns: `.map` (pattern 1), and `iterator.hasNextAt`/`nextAt` (pattern 1).

## Spec gaps (counted separately; 2,518 edges, none overlapping the wrong set)
1. **Case-class apply: 867 edges**, all high: 765 `X#<init>` constructor and 102 `X#apply` method. The construct is `BooleanArray(array, self.offset + offset, …)` or `Graph(nodes.map(_.map(f)), …)` on a scanned case class with no written `apply` (CAPABILITIES scala/16). Open question: is `Point(0, 0)` data construction (no edge), `T#<init>` constructor, or `T#apply`? If it is `T#apply`, is it high although `apply` has no written definition? The tool uses both forms for the same construct.
2. **Scala 3 top-level definitions: 22 edges** in `specs/snippet-check/showcase.scala`. The constructs are `def connectDatabase(): Task[DbConn] = …` and `val tortoise = runFast("tortoise")`; the tool gives bare IDs such as `connectDatabase` and the file-path caller `specs/snippet-check/showcase` (scala/18). Open question: what is the ID of a top-level `def`, and what is the caller of a top-level `val` initializer?
3. **Calls to members of an anonymous class from inside it: 53 edges**, low bare direct. Examples: `loop(prefix, fallback.first, split)` where `def loop` is a member of `new ConfigProvider { … }` in `fromFlat`, `findNextKey`, `prefetch`, Semaphore `reserve`/`releaseN`, and `hook(fullKey)`. Open question: SPEC folds such members into the enclosing function as callers, but does not say what callee ID a call to one of them gets.
4. **Bare names brought in by importing a value's members: 12 edges**, low bare direct. The construct is `import folder._` (with `folder: Folder[C, E1, Z]`) followed by `failCase(context, e, trace, …)`, in `Cause#foldContext` and `Config.Error#foldContext`. Open question: does decision A typing reach names imported from a typed parameter or value (`import x._`)?
5. **Apply on a value that is not known to be a function: 12 edges**, low bare direct. Examples: `tmp <- buffer(i1)` (a TArray from a generator), `val ch = cs(i)`, `header(0)`, `crc16Bytes(0)`, `mappings(key)`. Open question: is `v(x)` on such a value a callback `v` (unknown), a receiver guess `v.apply` (low, method), or a bare name?
6. **Bare names in a type whose base is outside the scan, defined by no scanned ancestor or import: 1,554 edges**, low bare direct: `testM` 998, `assertM` 461, `checkM` 91, `checkAllM` 2, `checkNM` 2. They occur in `scalafix/input` specs written as `object ZIOSpec extends DefaultRunnableSpec` with `import zio.test._`, where the scanned `zio.test` is ZIO 2 and lacks these names. Open question: SPEC says a member inherited from an external superclass is `Type#m` medium. Should a bare name that may come from that external base, or from an external version of an imported package, be `Type#m` medium or a low bare name? The scan cannot show which it is.
