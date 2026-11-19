# s-particular-nservicebus.rabbitmq (C#) blind call-graph review, round 5

precision 50/50; census ≈99.0% (14 wrong of 1383 in-scope); recall: 0 missed of 67 real calls; 0 non-calls

## Scope
- **Edges in scope:** 1,383 of the 2,998 `.cs` edges, over 49 files. I excluded the four test projects (`*.Tests`, `*.AcceptanceTests`, `*.TransportTests`, `*.CommandLine.Tests`). The rest is in scope: the main library, CommandLine, `src/targets` and `src/msbuild`.
- **Confidence split:** medium 617, high 399, low 336, unknown 31.
- **call_type split:** method 1,070, constructor 203, implicit 73, callback 31, direct 6.
- **Sample:** seed 42, stratified 14 high / 20 medium / 11 low / 5 unknown, over 23 files.
- **Script checks on all 1,383 edges:**
  - The callee name or `new` appears on each edge's line.
  - Every high callee and every caller is in `nodes`.
  - Result: no non-calls and no wrong lines.

## Precision sample
All 50 sampled edges match the spec. Five of them fall in spec gaps and are not counted as wrong:
- one implicit edge for a `const` field;
- one call to an in-scan extension method (`BasicProperties#Fill`);
- three low `recv.m` edges whose receiver comes from `var` or `out var`.

## Mismatch table
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| ConfirmsAwareChannel.cs:38 (plus 7 more: MessagePump.cs:501, BasicPropertiesExtensions.cs:27/83/94, DelayCommandHelpers.cs:108, ConvertToVersionRange.cs:47, Broker.cs:83) | `var delay = Convert.ToInt32(delayValue);` | → `NServiceBus.Transport.RabbitMQ.ConnectionConfiguration.Convert#ToInt32`, medium | `Convert#ToInt32` (System.Convert), medium | wrong callee | matched by simple name to the private nested `delegate bool Convert&lt;T&gt;` in ConnectionConfiguration.cs:243 |
| RabbitMQTransport.cs:246 | `var connectionFactory = new ConnectionFactory(` (alias `using ConnectionFactory = Transport.RabbitMQ.ConnectionFactory;` in `namespace NServiceBus`) | `Transport.RabbitMQ.ConnectionFactory#&lt;init&gt;`, medium | `NServiceBus.Transport.RabbitMQ.ConnectionFactory#&lt;init&gt;`, high | wrong callee | namespace-relative alias target not resolved |
| BrokerConnection.cs:12 | `var connection = await connectionFactory.CreateAdministrationConnection(cancellationToken);` (parameter typed `RabbitMQ.ConnectionFactory`) | `RabbitMQ.ConnectionFactory#CreateAdministrationConnection`, medium | `NServiceBus.Transport.RabbitMQ.ConnectionFactory#CreateAdministrationConnection`, high | wrong callee | partially qualified declared type not resolved |
| BrokerVerifier.cs:228 | `var logger = Logging.LogManager.GetLogger(typeof(BrokerVerifier));` | `LogManager.GetLogger`, low | `NServiceBus.Logging.LogManager#GetLogger`, medium | wrong callee / confidence | partially qualified static type taken as an unknown receiver |
| RabbitMQTransportInfrastructure.cs:57 | `var receivingQueues = Receivers.Select(r =&gt; r.Value.ReceiveAddress).ToArray();` | `Receivers#Select`, medium | `Receivers.Select`, low | wrong callee | property inherited from an external base treated as a type |
| ConvertToVersionRange.cs:42 | `Log.LogError("Reference '{0}' ...", ...);` | `Log#LogError`, medium | `Log.LogError`, low | wrong callee | same |
| CommandLine/Program.cs:10 | `var parseResult = rootCommand.Parse(args);` (`var rootCommand = new RootCommand(...)`) | `rootCommand.Parse`, low | `RootCommand#Parse`, medium | wrong callee | `var x = new T()` typing not applied to a top-level-statement local |
| DirectRoutingTopology.cs:29 (and 15 more) | `=&gt; new(channel.QueueUnbindAsync(...));` | no edge | `ValueTask#&lt;init&gt;`, constructor | missed call | target-typed `new(...)` never emitted |

## Systematic patterns (scripted counts, each hand-checked)
1. **`Convert.X` resolved to the private nested delegate `ConnectionConfiguration.Convert`:** 8 edges across 6 files and 3 projects.
2. **Namespace-relative partially qualified type names not resolved:** 3 edges. `global::A.B.T` resolves correctly.
3. **Capitalized property inherited from an external base treated as a static type:** 2 edges.
4. **`var = new T` not typed in top-level statements:** 1 edge.

Census precision = 1 − 14/1383 = 98.99%.

## Missed-call patterns (recall)
- **Recall functions:** `MessagePump#Process` (37 calls), `ConnectionConfiguration#ParseNServiceBusConnectionString` (17) and `QueueMigrateCommand#MoveMessagesToHoldingQueue` (13). All 67 calls are emitted correctly, and there are 0 non-calls.
- **Repo-wide miss scan:** target-typed `new(...)` produces no constructor edge, **16 missed** (sites listed in the report). In field initializers the implicit edge is still there; only the constructor call is missing.

## Spec gaps (not counted as wrong)
- **Inferred receivers left low:** 109 edges. These come from `var`, `out var`, deconstruction, `foreach var` and implicitly typed lambda parameters.
- **`const` implicit `&lt;clinit&gt;` edges:** 28.
- **Top-level statements:** 26 edges. The caller is `Program#&lt;Main&gt;$`, and local functions are `Program#&lt;Main&gt;$.X`.
- **In-scan extension methods named by receiver type:** 22 edges (`Exception#IsCausedBy`, `BasicProperties#Fill`, `Channel.BasicAckSingle`).
- **LINQ/BCL extension methods:** 20 edges.
- **External types under `using` directives left unqualified:** every medium external ID.
- **Bare `object.ReferenceEquals`:** 1 edge, emitted as `ChannelProvider#ReferenceEquals`.
- **Low property chains through external declared types:** 91 edges.

Files are in <fanout>:
- s-particular-nservicebus.rabbitmq_report.v5.md
- helper scripts: s-particular-nservicebus.rabbitmq_r4_load.py, s-particular-nservicebus.rabbitmq_r4_sample.py, s-particular-nservicebus.rabbitmq_r4_linecheck.py, s-particular-nservicebus.rabbitmq_r4_decl.py, s-particular-nservicebus.rabbitmq_r4_tiers.py, s-particular-nservicebus.rabbitmq_r4_miss.py, s-particular-nservicebus.rabbitmq_r4_recall.py, s-particular-nservicebus.rabbitmq_r4_gaps.py

<!-- Recovered  from the reviewer's final message in the session transcript; the report file was removed by /tmp cleanup. -->
