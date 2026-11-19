# Blind call-graph review: h-replicate (java), round 5

precision 49/50; census ≈98.97% (35 wrong of 3392 in-scope); recall: 0 missed of 34 real calls; 0 non-calls

## Scope
Tool output `<scans>/final13-A/h-replicate.v2.json` has 5747 edges: 5364 from `.java` files and 383 from `.py` files. The `.py` edges are out of scope (wrong language), and so are the 1972 Java edges under `src/test/`. **In scope: 3392 edges, all under `src/main/java/replicate/`, across 137 files.**
- By confidence: high 1916, medium 1214, low 262, unknown 0.
- By call_type: method 2537, constructor 692, implicit 163. No direct, callback or macro edges.
- By tier and type: high/method 1272, high/constructor 481, high/implicit 163, medium/method 1005, medium/constructor 209, low/method 260, low/constructor 2.

I ignored the `measured_accuracy` field. I did not read any earlier report for this repo. I wrote and ran only scripts with the `h-replicate_r5_` prefix: `_load`, `_sample`, `_dot`, `_chain`, `_new`, `_thisfield`, `_misc`, `_ids`, `_impl`, `_line`, `_recall` and `_census` (`.py`).

**Precision sample.** Seed `20261113`, stratified high 27, medium 18, low 5, over 27 files. 49 of the 50 edges are correct. The wrong one is #47, `vsr/ViewStampedReplication.java:123` (pattern P3).

**Recall.** I checked three functions:
- `replicate.common.Replica#handlePeerMessage`: 11 calls.
- `replicate.wal.WALEntry#serialize`: 11 calls.
- `replicate.multipaxos.MultiPaxos#sendProposalRequestsForUnCommittedEntries`: 12 calls. `new CompletableFuture[0]` is array creation, so I did not count it as a call.

Every call has an edge. No edge is a non-call. One recall edge has the wrong callee: `MultiPaxos.java:223` `.get` (pattern P1b, already counted in the census).

**Other whole-scope checks, no defects found:**
- All 163 implicit edges name a field with an initializer, from the right `<init>` or `<clinit>`. Every field-initializer caller has its implicit edge.
- All 114 `this(...)` and `super(...)` delegations have a constructor edge.
- Every high callee is in `nodes`.
- Every callee name appears on its reported line. The two exceptions are enum constants followed by a trailing comment, and both are correct.
- The anonymous `new RequestCallback<…>() {…}` (an interface) has no constructor edge, and its body folds into `ChainReplication#handleClientOperation`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| multipaxos/MultiPaxos.java:223 | `byte[] proposedValue = logEntry.acceptedValue().get();` | MultiPaxos#sendProposalRequestsForUnCommittedEntries → `.get`, low, method | `java.util.Optional#get`, medium, method | wrong callee | record-accessor result (`Optional<byte[]> acceptedValue` component) not typed (P1b) |
| multipaxos/MultiPaxos.java:300 | `if (paxosState == null \|\| paxosState.committedValue().isEmpty()) {` | MultiPaxos#addAndApplyIfAllThePreviousEntriesAreCommitted → `.isEmpty`, low, method | `java.util.Optional#isEmpty`, medium | wrong callee | P1b |
| multipaxos/MultiPaxos.java:303 | `byte[] committed = paxosState.committedValue().get();` | MultiPaxos#addAndApplyIfAllThePreviousEntriesAreCommitted → `.get`, low, method | `java.util.Optional#get`, medium | wrong callee | P1b |
| multipaxos/MultiPaxos.java:358 | `if (paxosState.committedValue().isEmpty()) {` | MultiPaxos#getUncommitedValues → `.isEmpty`, low, method | `java.util.Optional#isEmpty`, medium | wrong callee | P1b |
| mpaxoswithheartbeats/MultiPaxosWithHeartbeats.java:260 | `byte[] proposedValue = logEntry.acceptedValue().get();` | MultiPaxosWithHeartbeats#sendProposalRequestsForUnCommittedEntries → `.get`, low, method | `java.util.Optional#get`, medium | wrong callee | P1b |
| mpaxoswithheartbeats/MultiPaxosWithHeartbeats.java:332 | `if (paxosState == null \|\| paxosState.committedValue().isEmpty()) {` | MultiPaxosWithHeartbeats#addAndApplyIfAllThePreviousEntriesAreCommitted → `.isEmpty`, low, method | `java.util.Optional#isEmpty`, medium | wrong callee | P1b |
| mpaxoswithheartbeats/MultiPaxosWithHeartbeats.java:335 | `byte[] committed = paxosState.committedValue().get();` | MultiPaxosWithHeartbeats#addAndApplyIfAllThePreviousEntriesAreCommitted → `.get`, low, method | `java.util.Optional#get`, medium | wrong callee | P1b |
| mpaxoswithheartbeats/MultiPaxosWithHeartbeats.java:394 | `if (paxosState.committedValue().isEmpty()) {` | MultiPaxosWithHeartbeats#getUncommitedValues → `.isEmpty`, low, method | `java.util.Optional#isEmpty`, medium | wrong callee | P1b |
| paxos/SingleValuePaxos.java:135 | `return (SetValueCommand) Command.deserialize(paxosState.acceptedValue().get());` | SingleValuePaxos#getAcceptedCommand → `.get`, low, method | `java.util.Optional#get`, medium | wrong callee | P1b |
| paxos/SingleValuePaxos.java:238 | `if (paxosState.promisedGeneration().isAfter(generation)) {` | SingleValuePaxos#handlePrepare → `.isAfter`, low, method | `replicate.common.MonotonicId#isAfter`, high | wrong callee | P1b (component `MonotonicId promisedGeneration`, scanned) |
| common/Replica.java:200 | `clientConnection.write(new RequestOrResponse(requestId, serialize(throwable.getMessage()), correlationId).setError());` | Replica#respondToClient → `.setError`, low, method | `replicate.common.RequestOrResponse#setError`, high | wrong callee | in-place `new T(..).m()` receiver not typed (P2) |
| paxos/SingleValuePaxos.java:105 | `return doPaxos(new SetValueCommand(setValueRequest.getKey(), setValueRequest.getValue()).serialize())…` | SingleValuePaxos#handleSetValueRequest → `.serialize`, low, method | `replicate.wal.Command#serialize`, high (inherited from scanned superclass) | wrong callee | P2 |
| paxoskv/PaxosKVStore.java:84 | `return doPaxos(monotonicId, key, new SetValueCommand(key, value == null?"":value).serialize())` | PaxosKVStore#doPaxos → `.serialize`, low, method | `replicate.wal.Command#serialize`, high | wrong callee | P2 |
| wal/DurableKVStore.java:36 | `Long aLong = wal.writeEntry(new SetValueCommand(key, value).serialize());` | DurableKVStore#appendLog → `.serialize`, low, method | `replicate.wal.Command#serialize`, high | wrong callee | P2 |
| quorum/QuorumKVStore.java:115 | `return new ReadRepairer(this, responses, config.isAsyncReadRepair()).readRepair();` | QuorumKVStore#handleClientGetValueRequest → `.readRepair`, low, method | `replicate.quorum.ReadRepairer#readRepair`, high | wrong callee | P2 |
| quorumconsensus/QuorumConsensus.java:102 | `return new ReadRepairer(this, nodesToValues).readRepair();` | QuorumConsensus#handleClientGetValueRequest → `.readRepair`, low, method | `replicate.quorumconsensus.ReadRepairer#readRepair`, high | wrong callee | P2 |
| quorum/QuorumKVStore.java:127 | `new File(systemWalDir).mkdirs();` | QuorumKVStore#makeSystemWalDir → `.mkdirs`, low, method | `java.io.File#mkdirs`, medium (`import java.io.File;`) | wrong callee | P2 (external T) |
| chain/ChainReplication.java:67 | `private final Set<String> keysWithPendingWrites = new ConcurrentHashMap<String, Boolean>().keySet(true);` | ChainReplication#keysWithPendingWrites → `.keySet`, low, method | `java.util.concurrent.ConcurrentHashMap#keySet`, medium | wrong callee | P2 (external T, single import) |
| quorum/ReadRepairer.java:57 | `int requestId = new Random().nextInt();` | ReadRepairer#requestId → `.nextInt`, low, method | `java.util.Random#nextInt`, medium (one wildcard `java.util.*`; tool's own ctor edge is `java.util.Random#<init>` medium) | wrong callee | P2 (external T) |
| net/NIOConnection.java:87 | `getLogger().trace("Did not finish reading, … " + socketChannel.getRemoteAddress());` | NIOConnection#read → `.trace`, low, method | `org.apache.logging.log4j.Logger#trace`, medium | wrong callee | result of scanned `default Logger getLogger()` (interface `replicate.common.Logging`) not typed (P1a) |
| net/NIOSocketListener.java:56 | `getLogger().error(e);` | NIOSocketListener#run → `.error`, low, method | `org.apache.logging.log4j.Logger#error`, medium | wrong callee | P1a |
| net/NIOSocketListener.java:79 | `getLogger().warn("Interrupted",e);` | NIOSocketListener#shudown → `.warn`, low, method | `org.apache.logging.log4j.Logger#warn`, medium | wrong callee | P1a |
| net/NIOSocketListener.java:81 | `getLogger().error("Unexpected exception", e);` | NIOSocketListener#shudown → `.error`, low, method | `org.apache.logging.log4j.Logger#error`, medium | wrong callee | P1a |
| net/SocketListener.java:28 | `getLogger().info("Listening on " + listenIp);` | SocketListener#<init> → `.info`, low, method | `org.apache.logging.log4j.Logger#info`, medium | wrong callee | P1a |
| net/SocketListener.java:52 | `getLogger().debug(e);` | SocketListener#run → `.debug`, low, method | `org.apache.logging.log4j.Logger#debug`, medium | wrong callee | P1a |
| net/SocketListener.java:116 | `getLogger().debug(e);` | SocketListener.SocketHandlerThread#run → `.debug`, low, method | `org.apache.logging.log4j.Logger#debug`, medium | wrong callee | P1a |
| vsr/ViewStampedReplication.java:123 (sample #47) | `this.heartBeatScheduler.stop();` | ViewStampedReplication#handleStartView → `heartBeatScheduler.stop`, low, method | `replicate.heartbeat.HeartBeatScheduler#stop`, high (field `protected HeartBeatScheduler heartBeatScheduler` in superclass `Replica`) | wrong callee | `this.`/`super.` + field inherited from scanned superclass not typed (P3). The bare form `heartBeatScheduler.stop();` at line 54 of the same file resolves high, so this is also a C2 inconsistency |
| vsr/ViewStampedReplication.java:124 | `this.heartbeatChecker.start();` | ViewStampedReplication#handleStartView → `heartbeatChecker.start`, low, method | `replicate.heartbeat.HeartBeatScheduler#start`, high | wrong callee | P3 |
| vsr/ViewStampedReplication.java:177 | `… " at " + super.clock.now());` | ViewStampedReplication#handleCommit → `clock.now`, low, method | `replicate.common.SystemClock#now`, high (`protected SystemClock clock;` in Replica) | wrong callee | P3 |
| vsr/ViewStampedReplication.java:289 | `this.heartbeatChecker.stop();` | ViewStampedReplication#shutdown → `heartbeatChecker.stop`, low, method | `replicate.heartbeat.HeartBeatScheduler#stop`, high | wrong callee | P3 |
| vsr/ViewStampedReplication.java:290 | `this.heartBeatScheduler.stop();` | ViewStampedReplication#shutdown → `heartBeatScheduler.stop`, low, method | `replicate.heartbeat.HeartBeatScheduler#stop`, high | wrong callee | P3 |
| wal/WALSegment.java:178 | `String[] prefixAndOffset = nameAndSuffix[0].split("_");` | WALSegment#getBaseOffsetFromFileName → `.split`, low, method | `java.lang.String#split`, medium (`String[] nameAndSuffix` declared at line 177) | wrong callee | index receiver on a declared array not typed (P4) |
| wal/WALSegment.java:179 | `if (prefixAndOffset[0].equals(logPrefix))` | WALSegment#getBaseOffsetFromFileName → `.equals`, low, method | `java.lang.String#equals`, medium | wrong callee | P4 |
| vsr/ViewStampedReplication.java:39 | `singularUpdateQueueExecutor.submit(()-> {` | ViewStampedReplication#checkPrimary → `ScheduledExecutorService#submit`, medium, method | `ScheduledExecutorService#submit`, low | wrong confidence | the field is declared in Replica.java, which has two wildcard imports (`java.util.*`, `java.util.concurrent.*`), so the type stays unqualified. The same ID is low in Replica.java:169/186 but medium in the subclass (C2/C5) (P5) |
| mpaxoswithheartbeats/MultiPaxosWithHeartbeats.java:137 | `singularUpdateQueueExecutor.submit(()-> {` | MultiPaxosWithHeartbeats#checkLeader → `ScheduledExecutorService#submit`, medium, method | `ScheduledExecutorService#submit`, low | wrong confidence | P5 |

## Systematic patterns (scripted counts, ordered by count; union = 35, no overlap)
1. **P1b: record-accessor results are not typed. 10 edges.** The tool resolves the accessor call itself at high, for example `replicate.multipaxos.PaxosState#committedValue`. A method chained on the accessor's result stays `.m` low, although the record component declares its type: `Optional<byte[]> committedValue`, `MonotonicId promisedGeneration`.
   - Rules: the parameterless-member rule (2026-11-09) and Typed call results (2026-11-10).
   - Script `h-replicate_r5_chain.py` finds low `.m` edges whose receiver is a call with a resolved edge on the same line. I then filtered by hand to receivers whose declared type is in the scan.
   - Hand-checked: MultiPaxos.java:223/303, SingleValuePaxos.java:238, and both `PaxosState` records.
2. **P2: in-place `new T(..).m()` receivers are not typed. 9 edges.** 6 have a scanned T (should be high); 3 have an external T, singly imported or reachable through one wildcard (should be medium).
   - Script: `h-replicate_r5_new.py`.
   - Excluded: `new Random().nextInt()` at Replica.java:294. That file has two wildcard imports, so low is correct there.
3. **P1a: the result of `Logging#getLogger()` is not typed. 7 edges.** The interface default method is declared `default Logger getLogger()` with `import org.apache.logging.log4j.Logger;`. The tool resolves `replicate.common.Logging#getLogger` at high, but the chained `.info`/`.debug`/`.error`/`.warn`/`.trace` stays low.
   - Script: `h-replicate_r5_chain.py`.
4. **P3: `this.f.m()` / `super.f.m()` on a field inherited from a scanned superclass stays a `f.m` low guess. 5 edges.** The bare `f.m()` form resolves correctly elsewhere: VSR:54/95/97/146/147 and MultiPaxos.
   - Script: `h-replicate_r5_thisfield.py`, which matches low `recv.m` edges with `this.`/`super.` on the line.
   - Hand-checked: all 5 fields are declared in `replicate.common.Replica`.
5. **P4: an index receiver on a locally declared array is not typed. 2 edges.**
   - Script: `h-replicate_r5_misc.py`, index section.
6. **P5: an unqualified wildcard-ambiguous type is reported at medium when the field is inherited. 2 edges.** The same callee ID is low in the declaring file.
   - Script: `h-replicate_r5_ids.py`, which lists medium edges with unqualified type IDs.

Census precision = 1 − 35/3392 = 98.97%.

## Missed-call patterns (recall)
None found. 0 missed of 34 calls in the three recall functions.

Whole-scope scripted checks found no missing edges:
- no field initializer without its implicit edge;
- no `this(...)`/`super(...)` delegation without a constructor edge;
- no missing enum-constant `<clinit>` → `<init>` edges in the sampled enums (ServerRole, ViewStampedReplication.Status, MessageId, OperationType, NodeRole).

## Spec gaps (counted separately, not wrong): 19 edges
1. **Functional-interface calls: 9 edges.** This is CAPABILITIES `java/18-functional-interface-calls`, undecided.
   - 7 edges are calls on JDK functional interfaces that hold lambdas or method references: `java.util.function.Function#apply` ×4, `java.util.function.Supplier#get`, `java.util.function.Consumer#accept` and `java.lang.Runnable#run`, all medium/method. One example is Replica.java:189 `handler.apply(deserializedRequest)` with `Function<Object, CompletableFuture<?>> handler = messageHandler.handler;`.
   - 2 edges are `replicate.net.RequestConsumer#accept`, high, on an in-scan single-abstract-method interface that holds `this::handlePeerMessage`. One example is NIOConnection.java:83 `requestConsumer.accept(new Message<RequestOrResponse>(request, header, this))`.
   - Open question (quoted from CAPABILITIES): is `f.apply(s)` "the decision-A typed call … method, medium, or the callback rule's `f`, callback, unknown?" The same question applies to an in-scan interface: high, or callback?
2. **Literal receivers: 7 edges.** All are `.m` low:
   - `"COUNT".equals(aggregateType)` and `"SUM".equals(aggregateType)` (ChainReplication.java:449/451);
   - `"".getBytes()` (RequestOrResponse.java:26);
   - `"Success".equals(responseMessage)` (QuorumCallback.java:48);
   - `!"".equals(attachLease)` (SetValueCommand.java:52);
   - `StopableThread.class.getName()` (StopableThread.java:7) and `SocketClient.class.getName()` (SocketClient.java:15).

   Open question: the Typed call results ruling types "a call result, an index or a literal … when its static type can be determined from declarations: a declared return type in the scan, or the language's type checker (Go)". Is a Java string literal (`java.lang.String`) or a class literal (`java.lang.Class`) typed by the language itself, giving `java.lang.String#equals` medium, or does it stay `.equals` low because no declaration in the scan gives its type?
3. **Cast-typed receivers: 2 edges.**
   - `return ((SetValueCommand) command).getValue();` (PaxosKVStore.java:106): `.getValue`, low.
   - `var socketChannel = (SocketChannel)key.channel();` then `socketChannel.getRemoteAddress()` (NIOConnection.java:67/87): `socketChannel.getRemoteAddress`, low.

   Open question: SPEC lists casts as "not calls". Decision A types receivers from declarations and `= new T(...)`, and the let-bound rule types a local from a call's declared return type. No rule says whether a cast expression, used in place or as a `var` initializer, gives its receiver the cast type.
4. **A method type parameter as the return type: 1 edge.** `return SetValueCommand.deserialize(daos).withClientId(clientId).withRequestNumber(requestNumber);` (wal/Command.java:63) gives `.withRequestNumber`, low. The declaration is `public <T extends Command> T withClientId(long clientId)`.

   Open question: Decision A says "A type variable resolves to its declared bound". The let-bound and Typed call results rules say "A generic … return type leaves the call a low guess". When a call's declared return type is a bounded method type variable, is the receiver typed by the bound (`replicate.wal.Command#withRequestNumber`, high) or is it a low guess?
