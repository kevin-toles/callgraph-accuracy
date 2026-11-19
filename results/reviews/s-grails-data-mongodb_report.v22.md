# Blind call-graph review: s-grails-data-mongodb (groovy), round 22

precision 43/50; census ≈98.8% (26 wrong of 2251 in-scope); recall: 0 missed of 63 real calls; 0 non-calls

(Precision: 43 correct, 1 wrong, 6 spec gaps. The 6 gaps are not counted as wrong.)

## Scope
Tool output `<scans>/gk43-A/s-grails-data-mongodb.v2.json` has 10048 edges: 6959 from `.groovy` files and 3089 from `.java` files. In scope: `.groovy` source files with no path segment named test/tests/spec/examples/docs. Most Groovy edges sit under `src/test/` and are excluded. Java edges are excluded as another language, but the Java sources were read where Groovy calls resolve into them (`AbstractMongoSession.java`, `MongoDatastore.java`, `MongoMappingContext.java`). That leaves **2251 in-scope edges in 104 files**.
- By confidence: medium 1199, high 693, low 356, unknown 3.
- By call_type: method 1788, constructor 330, implicit 102, direct 28, callback 3.
- I ignored the `measured_accuracy` field.

Precision sample: seed 22, 50 edges (medium 25, high 15, low 7, unknown 3; the unknown tier holds only 3 edges, so all were taken), over 22 files.

Helper scripts are in the fanout folder, all prefixed `s-grails-data-mongodb_r22_`: `load`, `sample`, `ctx.sh`, `recv`, `fields`, `med`, `med2`, `impl`, `anon`, `anonctor`, `cast`, `defcall`, `chain`, `recall`.

## Mismatch table
Sample rows are marked S#n. Rows marked C were found by the census or by looking. Paths are below the source root.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| S#47 core/.../bootstrap/MongoDbDataStoreSpringInitializer.groovy:104 | `mongo(mongoDatastore: 'getMongoClient')` | `MongoDbDataStoreSpringInitializer#getBeanDefinitions` → `mongo`, unknown, callback | `mongo`, low, direct. A bean-DSL name resolved through the closure delegate is an honest low, like the neighbouring `mongoDatastore(...)`. The field `protected MongoClient mongo` does not hold a function. | wrong confidence / call_type | a call whose name matches a field is taken as a call through a function value |
| S#20 core/.../engine/MongoCodecEntityPersister.groovy:255 | `setVetoed(true)` (in `new PendingInsertAdapter(...) { void run() {...} }`) | `persistEntity` → `MongoCodecEntityPersister#setVetoed`, medium, method | undecided | spec gap | bare call in an anonymous-class body (gap 4) |
| S#32 core/.../bootstrap/MongoDbDataStoreSpringInitializer.groovy:46 | `public static final String DEFAULT_DATABASE_NAME = 'test'` | `#<clinit>` → `#DEFAULT_DATABASE_NAME`, high, implicit | undecided | spec gap | Groovy compile-time constant (gap 1) |
| S#45 core/.../mongo/MongoCodecSession.groovy:163 | `def updateDoc = codec.encodeUpdate(changedObject, entityAccess)` (with `def codec = (PersistentEntityCodec) ...`) | `MongoCodecSession#flush` → `codec.encodeUpdate`, low, method | undecided | spec gap | `def` local bound to a cast (gap 2) |
| S#46 core/.../codecs/PersistentEntityCodec.groovy:359 | `((PropertyEncoder<PersistentProperty>) propertyEncoder)?.encode(` | `#encodeUpdate` → `.encode`, low, method | undecided | spec gap | cast-expression receiver (gap 2) |
| S#48 core/.../bootstrap/MongoDbDataStoreSpringInitializer.groovy:128 | `"${interceptorName}"(ClassUtils.forName(OSIV_CLASS_NAME, classLoader)) {` | `#getBeanDefinitions` → `"${interceptorName}"`, unknown, callback | undecided | spec gap | GString method name (gap 6) |
| S#49 core/.../bootstrap/MongoDbDataStoreSpringInitializer.groovy:135 | `"$serviceName"(DatastoreServiceMethodInvokingFactoryBean, serviceClass) {` | `#getBeanDefinitions` → `"$serviceName"`, unknown, callback | undecided | spec gap | GString method name (gap 6) |
| C bson/.../codecs/CodecExtensions.groovy:178 | `BSON_VALUE_CONVERTERS[BsonInt64] << new Converter<BsonInt64, Long>() {` | `CodecExtensions#<clinit>` → `org.springframework.core.convert.converter.Converter#<init>`, medium, constructor | no edge. Spring's `Converter` is an interface, and an anonymous implementation of an interface gets no constructor edge. | not a call | the kind of an external type (interface or class) is not known, so every anonymous `new X() {}` gets `X#<init>` |
| C core/.../grails/mongodb/MongoEntity.groovy:59 | `DynamicAttributes.super.getAt(name)` | `MongoEntity#propertyMissing` → `super.getAt`, low, method | `.getAt`, low. `super` whose target is outside the scan is a computed receiver. | wrong callee | `super` is used as a receiver name |
| C core/.../mongo/MongoCodecSession.groovy:378 | `def codec = registry.get(type)` (after `def registry = datastore.getCodecRegistry()`; `MongoDatastore.getCodecRegistry()` is declared `public CodecRegistry`) | `MongoCodecSession#decode` → `registry.get`, low, method | `org.bson.codecs.configuration.CodecRegistry#get`, medium (Decisions 2026-11-16, Groovy `def` local bound to a call; `registry` is never reassigned) | wrong callee / confidence | the declared return type of the callee is not carried to the `def` local, even though the binding call itself resolved high |
| C core/.../geo/AbstractShapeCoordsType.groovy:54 | `def coords = value.asList()` (`T value`, `class AbstractShapeCoordsType<T extends Shape>`) | `#writeInternal` → `T#asList`, medium, method | `grails.mongodb.geo.Shape#asList`, high. `Shape` declares `abstract List<? extends Object> asList()`. | wrong callee | open defect groovy/05: the type parameter's name is used instead of its bound |
| C core/.../mongo/MongoConstants.groovy:46 | `if (t.respondsTo(name)) {` (`static <T> T mapToObject(...)`, `T t = ...`) | `#mapToObject` → `T#respondsTo`, medium, method | `t.respondsTo`, low. An unconstrained type variable stays low. | wrong callee / confidence | same as above: the type variable is used as a type name |
| C core/.../mongo/MongoCodecSession.groovy:152 | `def codec = (PersistentEntityCodec) datastore.codecRegistry.get((Class) changedObject.getClass())` | `#flush` → `codecRegistry.get`, low, method | `org.bson.codecs.configuration.CodecRegistry#get`, medium. `getDatastore()` returns `MongoDatastore`, and `MongoDatastore.getCodecRegistry()` returns `CodecRegistry`. | wrong callee / confidence | open defect groovy/14: a getter chain stays low |

## Systematic patterns (wrong), by scripted count
1. **Constructor edge for an anonymous implementation of an external interface: 18.** Every `new Converter<..>() {` in `CodecExtensions.groovy`'s static block gives `org.springframework.core.convert.converter.Converter#<init>` at medium. Scanned interfaces are handled correctly: `new TypeDecoder() {`, `new TypeEncoder() {` and `new IdentityTypeDecoder() {` (37 sites) get no edge. Anonymous subclasses of classes keep their correct edges (`PendingOperationAdapter`, `IdentityEncoder`, and others). Script: `anonctor.py`, plus a callee-ID count.
2. **`def` local bound to a scanned call with a concrete return type, left low: 2.** `MongoCodecSession.groovy` lines 378 and 380, `registry.get`. Every other low `def`-bound receiver was checked by `defcall.py`. Those were either reassigned later (`coll`, `mongoCollection`, `aggregateIterable` in `MongoStaticApi`, correctly untyped under 2026-11-16), bound to an external library call, or bound to a method declared `Object` (`EmbeddedDecoder:50`, after `Object decode(...)`).
3. **Type variable used as a type name (open defect groovy/05): 2.** `T#asList` should be the bound `Shape#asList`, high. `T#respondsTo` is unconstrained and should stay low. Script: callee regex `^[A-Z]\w?#`.
4. **`Trait.super.m()` emitted as `super.m`: 2.** `MongoEntity.groovy` lines 59 and 69.
5. **Getter chain left low (open defect groovy/14): 1.** `MongoCodecSession.groovy:152`. Other getter chains do resolve, for example `mongoSession.mappingContext.getPersistentEntity` → `MongoMappingContext#getPersistentEntity` (14 edges). Every remaining low `a.b.m` chain (`chain.py`, 14 edges) has an external base type.
6. **A DSL name that matches a field, emitted as a callback: 1.** `mongo(...)` at line 104.

Union: 26 wrong of 2251 in-scope, so census ≈98.8%.

Checked and found correct:
- Every high callee is in `nodes`.
- Calls in field initializers, anonymous-class bodies and static blocks get the caller `Type#field` or `Type#<clinit>`.
- Implicit `<init>` edges for instance-field initializers are right.
- A superclass in the scan is used for bare calls (`BsonPersistentEntityCodec#getPropertyEncoder`).
- A typed field in a scanned superclass is used where no local shadows it. I checked all 9 `entity.*` lows: each sits under a local `def entity = access.persistentEntity`.
- Bean-DSL bare names inside the `getBeanDefinitions` closure are honest lows (25).
- No instance of open defect groovy/06: every medium `Type#m` bare call is on a class with an external ancestor.

## Recall
Three functions, each 8+ lines, in different files:
- `BsonPersistentEntityCodec#encode` (lines 205–249): 20 calls, 20 edges.
- `MongoStaticApi#search` (234–260): 20 calls, 20 edges. The `coll` reassignment correctly leaves `coll.withDocumentClass` low.
- `EnumType#putValueToProperPlace` (192–230): 23 calls, 23 edges.

Total: 0 missed of 63, 0 non-calls.

Missed-call pattern found by looking:
- **GString method name on a receiver: 1.** `MongoConstants.groovy:47`, `t."$name"(values.get(name))`, has no edge, although the receiverless GString calls at lines 128 and 135 do get edges. C4 says an unresolved call is preserved, but SPEC gives no callee form for it (gap 6). The other calls on the same line are emitted.

## Spec gaps (not counted as wrong)
1. **Groovy compile-time constants: 40.** 23 `static final` String/primitive fields with literal initializers, plus 17 fields of the interface `MongoSettings` such as `String PREFIX = 'grails.mongodb'`. Each gets an implicit `<clinit>` edge, high. Example: `public static final String DEFAULT_DATABASE_NAME = 'test'`. Question: Decisions 2026-11-16 drops the implicit edge for Java and Kotlin constants. Does it apply to Groovy `static final` and interface fields with constant initializers, and to those initialized from another constant (`MONGO_ID_FIELD = MongoConstants.MONGO_ID_FIELD`, 4 more)?
2. **Cast-typed receivers: 43.** 32 are casts in place, `((PropertyEncoder<PersistentProperty>) encoder)?.encode(` and `((Number) value).intValue()`, emitted as `.m` low. 11 are `def` locals bound to a cast, `def map = (Map) embeddedSets; map.keySet()`, emitted as `recv.m` low. Question: does a cast expression type its receiver, in place or through a `def` binding, as a declaration does? "Typed call results" lists call results, indexes and literals, not casts.
3. **Groovy GDK extension methods on typed receivers: 31.** Examples: `java.util.List#collect` (18), `HashMap#withDefault` (3), `Iterable#collect` (2), `Iterable#toList`, `Collection#toList`, `Object#each`, `BigInteger#toBigDecimal`, `ConcurrentHashMap#withDefault`, `LinkedHashMap#withDefault`, `GeometryCollection#collect`, and `SimpleDecoder.TypeDecoder#is` (on a scanned interface that declares no `is`). Question: is a `DefaultGroovyMethods` method called on a typed receiver `T#m` (decision A), or is it named by the class that defines it? For a scanned type, does C2 ("an ID is never invented") forbid `T#m` when T does not define m?
4. **Bare calls inside anonymous-class bodies: 9.** In `MongoCodecEntityPersister`, inside `new PendingInsertAdapter/PendingUpdateAdapter/PendingDeleteAdapter/PendingOperationAdapter(...) {...}`: `setVetoed(true)` ×3, `addCascadeOperation(...)` ×3, `cancelInsert`, `cancelUpdate`, `firePostUpdateEvent`. None is defined in the file. Each is emitted as `MongoCodecEntityPersister#m` medium. Question: the caller folds into the enclosing method, but which type names the callee when both the anonymous class's superclass and the outer class's superclass are outside the scan, given that Groovy looks the name up on the anonymous class first?
5. **Calls of Groovy property-generated accessors: 4.** `MongoAttribute#isReference` ×3 (from `boolean reference = false`, medium). `MongoConnectionSourceSettings#getConnectionsCollection` ×1, where the property is declared in the scanned superclass `AbstractMongoConnectionSourceSettings`. Question: is an explicit call of a getter or setter generated from a scanned property declaration high (defined in the scan) or medium (generated, no written body)? Is it named by the declaring superclass?
6. **GString method names: 2 edges, plus 1 missing.** `"${interceptorName}"(...)` and `"$serviceName"(...)` are emitted as callback/unknown with the GString as the callee. `t."$name"(...)` has no edge. Question: what callee ID, call_type and tier does a call with a computed method name get, with and without a receiver?
7. **`def` local bound to a typed field: 3.** `def mongoCodecSession = mongoSession`, where the field is `protected final MongoCodecSession mongoSession`. Calls on it stay low (`contains`, `addPendingInsert`, `addPendingUpdate`). Question: the 2026-11-16 ruling types a `def` local bound to a call. Does a `def` local bound to a typed variable or field take that type?
8. **Bare call in a plain (non-builder) closure to an inherited external member: 1.** `objects.collect() { getObjectIdentifier(it) }` emits `getObjectIdentifier` low direct. The same call outside the closure is `MongoCodecEntityPersister#getObjectIdentifier` medium. Question: does "honest low through a closure delegate" cover closures whose delegate defaults to the owner, where owner-first lookup reaches the enclosing class?

Spec-gap total: 133 edges, plus 1 missing call.
