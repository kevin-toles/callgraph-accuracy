# s-codepropertygraph (scala): blind call-graph review, round 13

precision 49/50; census ≈98.69% (226 wrong of 17266 in-scope); recall: 24 missed of 68 real calls; 0 non-calls

## Scope
Tool output: `final13-A/s-codepropertygraph.v2.json`, which has 17813 edges in total. 17266 are in scope: `.scala` source files across 278 files, with no path segment named test/tests/spec/examples/docs. The 425 `.java` edges are out of scope. Generated code (`domainClasses/src/main/generated`), `project/` (sbt build) and `samples/` are in scope, per Decisions 2026-11-09.
- Confidence split: medium 11786, low 3354, high 2119, unknown 7.
- call_type split: method 15246, implicit 1106, constructor 892, direct 15, callback 7.

I ignored the `measured_accuracy` field. Helper scripts are in the fanout folder with the prefix `s-codepropertygraph_r13_`: load, sample, recall, typedresult, typedrecv and census.

**Sample.** Seed 13. It is stratified as medium 30, low 9, high 6 and unknown 5 (unknown is raised to the 5-per-tier minimum). It covers 47 files.
- 39 edges are correct.
- 1 edge is wrong (#2, `edges.TryBody#<init>`).
- 10 edges are spec gaps, not counted as wrong:
  - #8, #19, #28: external `Constant(...)` apply (G5).
  - #22, #31: class-body statement caller (G1).
  - #32, #35–#38: `get.seq` receiver form (G3).

**Recall.** I checked three functions:
- `ProtoCpgLoader#loadFromListOfProtos` (ProtoCpgLoader.scala:39–77)
- `CpgPassBase#runWithBuilderLogged` (CpgPass.scala:273–287)
- `NewAnnotationParameter.InsertionHelpers.NewNodeInserter_AnnotationParameter_order#insertNewNodeProperties` (NewAnnotationParameter.scala:2146–2170)

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| generated/GraphSchema.scala:204 (sample #2) | `(s, d, subseq, p) => new edges.TryBody(s, d, subseq, p)` | GraphSchema#edgeFactories → `edges.TryBody#<init>`, medium, constructor | `io.shiftleft.codepropertygraph.generated.edges.TryBody#<init>`, high (class at edges/EdgeTypes.scala:274) | wrong callee + wrong confidence | relative subpackage reference `edges.`/`nodes.` not resolved against enclosing package (P1) |
| generated/GraphSchema.scala:126 | `(g, seq) => new nodes.Annotation(g, seq),` | → `nodes.Annotation#<init>`, medium | `io.shiftleft.codepropertygraph.generated.nodes.Annotation#<init>`, high | wrong callee + confidence | P1 |
| generated/nodes/RootTypesTraversals.scala:5 | `final def _aliasOfOut: Iterator[StoredNode] = iterator.flatMap(_._aliasOfOut)` (inside `extension (iterator: Iterator[StoredNode])`) | → `iterator.flatMap`, low | `scala.collection.Iterator#flatMap`, medium (declared parameter type) | wrong callee + confidence | extension parameter not typed (P2) |
| generated/Properties.scala:7 | `val AliasTypeFullName = flatgraph.OptionalPropertyKey[String](kind = 0, name = "ALIAS_TYPE_FULL_NAME")` | → `flatgraph.OptionalPropertyKey`, low, method | statically named external (`flatgraph.OptionalPropertyKey#apply` or `#<init>` medium, or no edge if data construction — none of the options is a low `flatgraph.X` receiver guess) | wrong callee/confidence | fully-qualified external package path treated as an unknown receiver (P3) |
| generated/Cpg.scala:16 | `flatgraph.help.TraversalHelp(searchPackageNames).forTraversalSources(verbose = false)` | Cpg#help → `help.TraversalHelp`, low | as above, statically named external, medium | wrong callee/confidence | P3 |
| schema/Tags.scala:66 | `.addContainedNode(tag, "tag", Property.Cardinality.One(Property.Default(null)))` | → `Cardinality.One`, low | `flatgraph.schema.Property.Cardinality.One…` medium (imported `flatgraph.schema.Property`) | wrong callee/confidence | P3 (note `Property.Default` on the same line resolves to `flatgraph.schema.Property.Default#apply` medium — C2) |
| cpgloading/ProtoCpgLoader.scala:53 | `nodesIter(protoCpg).foreach { protoNode =>` | → `.foreach`, low | `scala.collection.Iterator#foreach`, medium (`nodesIter` declares `: Iterator[CpgStruct.Node]`) | wrong callee + confidence | typed call result not applied (P4) |
| cpgloading/ProtoCpgLoader.scala:57 | `.getOrElse(throw new ConversionException(...))` after `.findGNode(protoNode)` | → `.getOrElse`, low | `scala.Option#getOrElse`, medium (both `findGNode` overloads declare `Option[GNode]`) | wrong callee + confidence | P4 |
| cpgloading/ProtoCpgLoader.scala:60 | `diffGraph.setNodeProperty(gNode, ...)` with `val diffGraph = Cpg.newDiffGraphBuilder` | → `diffGraph.setNodeProperty`, low | `flatgraph.DiffGraphBuilder#setNodeProperty`, medium (`def newDiffGraphBuilder: DiffGraphBuilder`, generated/Cpg.scala:43, imports `flatgraph.DiffGraphBuilder`) | wrong callee + confidence | let-bound local typed by parameterless in-scan def not applied (P4) |
| samples/.../SamplePass.scala:11 | `val fileNode = NewFile().name("foo")` | → `.name`, low | `io.shiftleft.codepropertygraph.generated.nodes.NewFile#name`, high (`def apply(): NewFile`) | wrong callee + confidence | P4 |
| schema/Protogen.scala:31 | `new ProtoGen(builder.build).run(outputDir)` | → `.run`, low | `flatgraph.codegen.ProtoGen#run`, medium (receiver `new T(...)`) | wrong callee + confidence | P4 |
| passes/CpgPass.scala:230 | `externalBuilder.absorb(diff)` | → `_root_.flatgraph.DiffGraphBuilder#absorb`, medium | `flatgraph.DiffGraphBuilder#absorb` | wrong callee (C1) | `_root_` qualifier kept when expanding `type DiffGraphBuilder = _root_.flatgraph.DiffGraphBuilder` (P5) |
| passes/CpgPass.scala:161 | `baseLogger.info(s"Start of pass: $name")` | ForkJoinParallelCpgPassWithAccumulator#createAndApply → `baseLogger.info`, low | `org.slf4j.Logger#info`, medium (`protected def baseLogger: Logger` in scanned base `CpgPassBase`; the same call in CpgPassBase:274 resolves) | wrong callee + confidence (C2) | parameterless member inherited from scanned base not typed (P6) |
| generated/GraphSchema.scala:1896 | `nodePropertyDescriptors(propertyOffsetArrayIndex(nodeKind, propertyKind))` | → `propertyOffsetArrayIndex`, low, direct | `io.shiftleft.codepropertygraph.generated.GraphSchema#propertyOffsetArrayIndex`, medium, method (inherited from external `flatgraph.Schema`) | wrong callee/confidence | open defect scala/03 (P7) |
| codepropertygraph/Cpg.scala:15 | `def apply(implicit graph: Graph) = generated.Cpg(graph)` | → `io.shiftleft.codepropertygraph.generated.Cpg`, medium, direct | generated `object Cpg` has no `apply`; Scala 3 creator application runs `new Cpg(graph)`: `...generated.Cpg#<init>`, high, constructor | wrong callee | type name emitted as a function ID (P8) |
| samples/.../SamplePass.scala:12 | `builder.addNode(fileNode)` (`builder: DiffGraphBuilder`, inherited member alias → `flatgraph.DiffGraphBuilder`) | → `DiffGraphBuilder#addNode`, medium | `flatgraph.DiffGraphBuilder#addNode`, medium | wrong callee | inherited type alias not expanded (P9) |
| SerializedCpg.scala:21 | `this()` (inside `def this(filename: String)`) | SerializedCpg#<init> → `this`, low, method | `io.shiftleft.SerializedCpg#<init>`, high, constructor | wrong callee | auxiliary constructor call not recognized (P10) |
| samples/.../SamplePass.scala:19 | `val loaderConfig  = CpgLoaderConfig().withOverflowConfig(odbConfig)` | → `io.shiftleft.codepropertygraph.cpgloading.CpgLoaderConfig#apply`, medium | `CpgLoaderConfig` is not defined in the scanned package: a low guess (C2: an ID is never invented) | wrong callee/confidence | invented ID in scanned package (P11) |
| ProtoCpgLoader.scala:51,54,58… (recall) | `val diffGraph = Cpg.newDiffGraphBuilder`, `protoNode.getKey`, `protoNode.getPropertyList…asScala` | no edge | `...generated.Cpg#newDiffGraphBuilder` high; `getKey`, `getPropertyList`, `asScala` guesses | missed call | calls without parentheses (open defect scala/12) |

## Systematic patterns (wrong; scripted counts, `s-codepropertygraph_r13_census.py`)
| # | pattern | count |
|---|---|---|
| P1 | `new nodes.X(..)` / `new edges.X(..)` (relative subpackage of the enclosing package `io.shiftleft.codepropertygraph.generated`) → `nodes.X#<init>` / `edges.X#<init>` medium instead of the fully qualified scanned class, high | 77 |
| P2 | Scala 3 `extension (iterator: Iterator[StoredNode])` parameter used as receiver → `iterator.flatMap` low instead of `scala.collection.Iterator#flatMap` medium (all in RootTypesTraversals.scala) | 68 |
| P3 | Fully-qualified external companion/constructor call (`flatgraph.SinglePropertyKey[Int](..)`, `flatgraph.OptionalPropertyKey`, `flatgraph.MultiPropertyKey`, `flatgraph.help.TraversalHelp(..)`, `Property.Cardinality.One(..)`) emitted as a low receiver guess | 57 |
| P4 | Typed call results / let-bound locals left as low guesses: `nodesIter(..).foreach`, `findGNode(..).getOrElse`, `typeFullNameMaybe(..).flatMap`, `find(..).map`, `NewFile().name`, `new ProtoGen(..).run`, `new overflowdb.Config().withStorageLocation`, and 3 × `diffGraph.*` from `val diffGraph = Cpg.newDiffGraphBuilder` | 10 |
| P5 | `_root_.` kept in ID (`_root_.flatgraph.DiffGraphBuilder#<init>`/`#absorb`) | 3 |
| P6 | Inherited parameterless member with declared type (`baseLogger: Logger`) not typed in subclass (resolved in the declaring trait) | 3 |
| P7 | Bare call of member inherited from external base → low bare name (open defect scala/03) | 3 |
| P8 | Scala 3 creator application `generated.Cpg(graph)` → bare type ID, direct | 2 |
| P9 | Inherited type alias `DiffGraphBuilder` not expanded | 1 |
| P10 | Auxiliary constructor `this()` → `this` low | 1 |
| P11 | Invented medium ID in a scanned package (`CpgLoaderConfig#apply`) | 1 |
| | **union** | **226** |

I hand-checked each pattern on 2–6 edges: GraphSchema.scala:126, 171 and 204; RootTypesTraversals.scala:5, 24 and 38; Properties.scala:7, 16 and 25; and the rows in the mismatch table. The patterns do not overlap.

I checked these frequent callees and they are correct: `scala.collection.Iterator#flatMap`/`#filter` on `traversal: Iterator[..]` (2081/914), `scala.collection.immutable.Set#apply` (2038), `scala.Array#update`/`#apply` on `offsets: Array[Int]`, `scala.collection.mutable.ArrayBuffer#apply`, `java.util.HashMap#put` on `new java.util.HashMap`, and `flatgraph.BatchedUpdateInterface#countProperty`. The low guesses on receivers whose types come only from libraries are also correct: `matcher.reset`, `matchers.exists`, `valueSet.contains`, and the `.addOutEdge`/`.protoId` chains on `builder.addNodeType(..)`.

## Missed-call patterns (recall)
- **Calls without parentheses are never emitted** (open defect scala/12): 24 of 24 missed calls. Examples: `Cpg.newDiffGraphBuilder`, `cpg.graph`, `protoNode.getKey`, `.asScala`, `builder.size`, `name`, `newNodes.isEmpty`, `newNodes.head`, `storedRef.get`, `newNodes.length`.
  - Function 1: 14 missed of 43 calls.
  - Function 2: 5 missed of 13 calls.
  - Function 3: 5 missed of 12 calls.
- All 49 calls written with parentheses or as `x(i)` / `x(i) = v` apply/update calls were emitted. No non-calls were emitted.
- I excluded infix operators such as `+=` and `-` (open defect scala/13) and string-interpolator calls from M.

## Spec gaps (not counted as wrong)
| # | construct (quoted) | count | question SPEC leaves open |
|---|---|---|---|
| G1 | Statements directly in a class body, for example Pdg.scala:223 `.addOutEdge(edge = reachingDef, inNode = ret)` and Hidden.scala:258 `importNode.addProperty(importedEntity)`, which the tool reports with caller `…Schema#<init>` | 860 | The caller of a Scala class-body statement: `Type#<init>` or `Type`? This is CAPABILITIES scala/17. |
| G3 | `nn.storedRef.get.seq()` → `get.seq`; `values.iterator.flatMap` → `iterator.flatMap`; `Source.fromFile(..).getLines.filter` → `getLines.filter` | 927 | The receiver is a parameterless method call (`get`, `iterator`, `getLines`) of unknown type. Is it a computed receiver (`.seq`) or the last receiver segment (`get.seq`)? SPEC's `a.b.c()` → `b.c` example assumes a field, but Scala's uniform access makes `b` a call. |
| G4 | `matchers.exists { _.reset(item.fullName).matches }` → `.reset` | 253 | Is a receiver that is the anonymous placeholder `_` written `.m`, or `_.m`, or something else? |
| G2 | `this.columnNumber.foreach { p => res.put("COLUMN_NUMBER", p) }` in `AnnotationBase#propertiesMap` → `columnNumber.foreach` low. `columnNumber` is not a member of `AnnotationBase`. It comes from an implicit conversion to `AccessAstnodeBase` (`def columnNumber: Option[Int]`, Accessors.scala:951) through `import …accessors.languagebootstrap.*`. | 177 | Does the parameterless-member rule reach members that exist only through an implicit conversion or extension in the scan? If so, is the callee `scala.Option#foreach`? |
| G5 | `Constant(name = "JAVA", value = "JAVA", …)`, `Some(x)`, `ProtoOptions(…)`, `Property.Default(null)` → `…#apply` medium | 135 | CAPABILITIES scala/16 asks whether a case-class `Name(args)` is data construction, `#<init>` or `#apply`. For these external types the scan cannot show whether the `apply` is synthesized. |
| G6 | Scala 3 top-level `extension (iterator: …) { final def _aliasOfOut … }` gives caller `io.shiftleft.codepropertygraph.generated.nodes._aliasOfOut` | 68 (overlaps P2) | The ID of a Scala 3 top-level def or extension method. This is CAPABILITIES scala/18. |
| G9 | `project.in(file("codepropertygraph"))` with only `import sbt._` → `file`, low | 5 | The one-on-demand-import rule names only types. Does it also qualify a bare function name (`sbt.file`, medium)? |
| G7 | `protoCpgs().foreach { … }` with `protoCpgs: () => Iterator[CpgStruct]` → `.foreach`, low | 2 | Does the declared function-type parameter's result type the call result (`scala.collection.Iterator#foreach`)? |
| G8 | `val (leftDiff, leftAcc) = leftConsumedArg` with `leftConsumedArg: (DiffGraphBuilder, Accumulator)` → `leftDiff.absorb`, low | 1 | Does a tuple pattern over a declared tuple type type its bindings? The let-bound rule excludes tuple return types, while decision A lists pattern bindings. |
