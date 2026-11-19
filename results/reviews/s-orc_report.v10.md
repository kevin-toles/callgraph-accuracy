# s-orc (java) blind call-graph review, round 10

precision 48/50; census ≈98.95% (156 wrong of 14925 in-scope); recall: 0 missed of 71 real calls; 0 non-calls

## Scope
Tool output: `<scans>/jvm39-A/s-orc.v2.json`. It has 42066 edges, all from `.java` files. After removing paths with a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment, **14925 edges are in scope**, from 226 files (core 9740, tools 2557, bench 1940, mapreduce 573, shims 115). The generated `OrcProto` is not in the scan.
- By confidence: high 7182, medium 6496, low 1247 (no unknown).
- By call_type: method 12322, constructor 2160, implicit 443 (no direct, callback or macro).
- By tier and type: high/method 5578, high/constructor 1161, high/implicit 443, medium/method 5497, medium/constructor 999, low/method 1247.

I ignored the `measured_accuracy` field. Helper scripts are `s-orc_r10_*.py` in the fanout folder. `s-orc_r10_index.py` builds a text-only index of the scanned types, methods and supertypes from the source.

**Sample:** seed `20261117`, stratified 24 high / 21 medium / 5 low, spread over 35 files.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| core/src/java/org/threeten/extra/chrono/HybridDate.java:225 (sample #31) | `JulianDate julian = JulianDate.of(prolepticYear, month, dayOfMonth);` | HybridDate#create → `JulianDate#of`, medium, method | `org.threeten.extra.chrono.JulianDate#of`, medium, method. The file has no import of JulianDate and no on-demand import, so the name can only be the file's own package (JLS 6.4.1). | wrong callee | same-package external type left unqualified (P1) |
| core/src/java/org/apache/orc/OrcUtils.java:382 (sample #33) | `if (type.getSubtypesCount() != 2) {` | OrcUtils#convertTypeFromProtobuf → `OrcProto.Type#getSubtypesCount`, medium, method | `org.apache.orc.OrcProto.Type#getSubtypesCount`, medium. Files that import OrcProto get this ID, e.g. sample #35 `org.apache.orc.OrcProto.BoundingBox#getMmin`. | wrong callee | P1 |
| bench/core/src/java/org/apache/hadoop/fs/TrackingLocalFileSystem.java:54 | `return new FSDataInputStream(new BufferedFSInputStream(` | TrackingLocalFileSystem#open → `FSDataInputStream#<init>`, medium, constructor | `org.apache.hadoop.fs.FSDataInputStream#<init>`, medium | wrong callee | P1 |
| core/src/java/org/apache/orc/impl/RecordReaderImpl.java:592 | `Long min = stats.getMinimum();` (after `} else if (index instanceof IntegerColumnStatistics stats) {`) | RecordReaderImpl#getValueRange → `stats.getMinimum`, low, method | `org.apache.orc.IntegerColumnStatistics#getMinimum`, high (pattern binding, decision A) | wrong callee / wrong confidence | the same name `stats` is bound with 8 different types in sibling `else if` branches (P2) |
| tools/src/java/org/apache/orc/tools/json/JsonSchemaFinder.java:347 | `result.addType(makeHiveType(child));` (after `UnionType result = new UnionType();`) | JsonSchemaFinder#makeHiveType → `org.apache.orc.tools.json.StructType#addType`, medium, method | `org.apache.orc.tools.json.UnionType#addType`, high | wrong callee | typed by `StructType result` from the sibling `case STRUCT:` block (P2). StructType defines no addType, so this ID is invented (C2). |
| tools/src/java/org/apache/orc/tools/json/JsonSchemaFinder.java:152 | `result.fields.put(fieldName, type);` (after `StructType result = new StructType();`) | JsonSchemaFinder#pickType → `fields.put`, low, method | `java.util.Map#put`, medium (`final Map<String, HiveType> fields`) | wrong callee / wrong confidence | the earlier sibling-branch `ListType result` is used (P2) |
| bench/hive/src/java/org/apache/orc/bench/hive/rowfilter/BooleanRowFilterBenchmark.java:84 | `RecordReader rows = state.reader.rows(state.readerOptions);` | readOrcNoFilter → `reader.rows`, low, method | `org.apache.orc.Reader#rows`, high (`Reader reader;` declared in the scanned superclass RowFilterInputState) | wrong callee / wrong confidence | field inherited from an in-scan superclass not typed (P3). The same chain in DecimalBench.java:247, where the field is declared directly, is high. |
| core/src/java/org/apache/orc/impl/ConvertTreeReaderFactory.java:108 | `... + fileType.getCategory().name());` | → `org.apache.orc.TypeDescription.Category#name`, high, method | same ID, **medium**: `name()` is `java.lang.Enum#name`, inherited from outside the scan. Category declares only the field `final String name;`. | wrong confidence | method call matched to a same-named field (P4) |
| bench/hive/src/java/org/apache/hadoop/hive/ql/io/orc/OrcBenchmarkUtilities.java:46 | `result = new OrcStruct(batch.cols.length);` | nextObject → `org.apache.orc.mapred.OrcStruct#<init>`, high, constructor | `org.apache.hadoop.hive.ql.io.orc.OrcStruct#<init>`, medium. The file is in package `org.apache.hadoop.hive.ql.io.orc` and has no import of OrcStruct. | wrong callee / wrong confidence | unimported simple name resolved to a scanned type in another package (P5) |
| bench/hive/src/java/org/apache/hadoop/hive/ql/io/orc/OrcBenchmarkUtilities.java:50 | `result.setFieldValue(c, RecordReaderImpl.nextValue(batch.cols[c], rowId,` | → `org.apache.orc.impl.RecordReaderImpl#nextValue`, medium | `org.apache.hadoop.hive.ql.io.orc.RecordReaderImpl#nextValue`, medium | wrong callee | P5. The ID is invented: the scanned RecordReaderImpl has no external base (C2). |
| core/src/java/org/apache/orc/impl/RecordReaderUtils.java:299 | `static final int MAX_VALUES_LENGTH = RunLengthIntegerWriterV2.MAX_SCOPE;` (`static final int MAX_SCOPE = 512;`) | RecordReaderUtils#<clinit> → RecordReaderUtils#MAX_VALUES_LENGTH, high, implicit | no edge: a constant variable (JLS 15.29 qualified name `TypeName.Identifier` of a constant) | not a call | compile-time constant with a qualified-name initializer keeps its implicit edge (P6) |
| core/src/java/org/apache/orc/impl/RecordReaderUtils.java:55 | `public static final int MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8;` | #<clinit> → #MAX_ARRAY_SIZE, high, implicit | no edge (constant expression) | not a call | P6 |
| bench/core/src/java/org/apache/orc/bench/core/SalesGenerator.java:58 | `.hasNulls(0.0004928293332019384);` (chained on `.addStringChoice(...)`, declared `public Field addStringChoice(String... choices)`) | SalesGenerator#<init> → `.hasNulls`, low, method | `org.apache.orc.bench.core.RandomGenerator.Field#hasNulls`, high (typed call result) | wrong callee / wrong confidence | the result of the varargs method addStringChoice is not typed, while chains after addStringPattern/addIntegerRange are (P7) |
| core/src/java/org/apache/orc/impl/ConvertTreeReaderFactory.java:71 | `super(columnId, context);` in `ConvertTreeReader extends TreeReader`, inside `ConvertTreeReaderFactory extends TreeReaderFactory` | ConvertTreeReader#<init> → `TreeReader#<init>`, medium, constructor | `org.apache.orc.impl.TreeReaderFactory.TreeReader#<init>`, high | wrong callee / wrong confidence | member type inherited from the enclosing class's superclass not resolved (P8) |

The other 48 sample edges are correct in caller, callee, tier, call_type and line. Examples:
- `super.until(...)` → `.until` low (superclass AbstractDate is outside the scan).
- `OrcList#set` medium (inherited from ArrayList).
- `OrcConf.BLOCK_SIZE.getInt` → `OrcConf#getInt` high (enum constant typed).
- the private 4-argument `FloatTreeReader#nextVector` overload.
- instance-field implicit edges for `= null` initializers.

## Systematic patterns (scripted counts; `s-orc_r10_census.py`)
Each pattern was checked by hand on the rows above and on further rows.

1. **P1: same-package external type left unqualified: 91 edges.** All are medium. A type outside the scan that the file names without an import is emitted with a bare top-level name, though the file has no on-demand import (so JLS 6.4.1 leaves only the file's package):
   - OrcUtils.java `OrcProto.*` (72): the generated class in package `org.apache.orc`.
   - HybridDate/HybridChronology `JulianDate`, `AbstractDate`, `JulianEra` (15): package `org.threeten.extra.chrono`.
   - TrackingLocalFileSystem `RawLocalFileSystem.LocalFSFileInputStream`, `Path`, `FSDataInputStream`, `BufferedFSInputStream` (4): package `org.apache.hadoop.fs`.

   The same external type gets two IDs across files: `OrcProto.X` here, `org.apache.orc.OrcProto.X` where it is imported.
2. **P2: local redeclared in sibling scopes with a different type: 30 edges.** A name bound again in a later sibling block is typed by the wrong binding, or left low:
   - RecordReaderImpl#getValueRange: 28 low `stats.*` edges. There are eight `instanceof X stats` pattern bindings, one per `else if`. Pattern bindings elsewhere, such as ColumnStatisticsImpl's `that`, are typed correctly.
   - JsonSchemaFinder: `fields.put` (low) and `StructType#addType` (invented, medium).
3. **P3: field inherited from a scanned superclass is not typed in an `obj.field.m()` chain: 15 edges.** This covers `state.reader.rows` (10) and `state.readerOptions.setRowFilter` (5) in the five `*RowFilterBenchmark` files, where `InputState extends RowFilterInputState`.
4. **P4: `Enum.name()` matched to an enum's own field `name`, tier raised to high: 8 edges.** These are `TypeDescription.Category#name` (6) and `TypeDescription.EdgeInterpolationAlgorithm#name` (2). Other inherited Enum methods (`ordinal`, `equals`) are medium, as the spec requires.
5. **P5: unimported simple name resolved to a scanned type in another package: 5 edges.** These are in OrcBenchmarkUtilities.java (package `org.apache.hadoop.hive.ql.io.orc`): `OrcStruct#createObjectInspector`, `OrcStruct#<init>`, `#setFieldValue`, `#getFieldValue` and `RecordReaderImpl#nextValue` are given ORC's `org.apache.orc.mapred`/`org.apache.orc.impl` IDs, instead of Hive's same-package classes at medium.
6. **P6: compile-time constant whose initializer uses a qualified constant name keeps an implicit `<clinit>` edge: 3 edges.** These are `MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8` (RecordReaderUtils:55, StringHashTableDictionary:66) and `MAX_VALUES_LENGTH = RunLengthIntegerWriterV2.MAX_SCOPE`. The 2026-11-16 ruling's paraphrase of JLS 15.29 lists "simple names of such fields". JLS 15.29, which the ruling cites, also includes `TypeName.Identifier`. Constants built from literals or simple names correctly have no edge.
7. **P7: result of a scanned varargs method not typed in a chain: 3 edges.** These are SalesGenerator `.hasNulls` at lines 58, 75 and 113 after `.addStringChoice(...)`.
8. **P8: inherited member type not resolved: 1 edge.** This is the ConvertTreeReaderFactory:71 `super(...)` call to `TreeReader#<init>`.

Union of wrong edges: 156 (no overlaps). Census precision = 1 − 156/14925 ≈ **98.95%**.

Checks that found **no** violations:
- No high callee is missing from `nodes`.
- No medium constructor names a scanned type, and every high constructor does.
- No medium `T#m` is defined in the scan, apart from the P2/P5 rows.
- Inherited in-scan methods are named by the declaring superclass.
- Method references (`x::m`) produce no edges.
- All 235 enum constants of the 30 in-scope enums have a `<clinit>` → `<init>` edge.
- Every edge's line carries the callee name (multi-line chains are on their own lines).
- The only anonymous subclass of a scanned interface (`new Dictionary.Visitor() {`) has no constructor edge.

## Missed-call patterns (recall)
I checked three functions:
- `org.apache.orc.tools.json.JsonSchemaFinder#pickType`: 49 calls, all emitted. One has a wrong callee (`fields.put`, P2).
- `org.apache.orc.impl.PhysicalFsWriter#writeFileMetadata`: 10 calls, all emitted.
- `org.apache.orc.mapred.OrcMapredRecordWriter#setMapValue`: 12 calls, all emitted. The low `keys.ensureSize`/`values.ensureSize` are correct: MapColumnVector is outside the scan.

Result: 0 missed of 71 real calls, and 0 non-call edges. No missed-call pattern was found.

## Spec gaps (counted separately, not wrong)
- **G1: enum compiler-generated `values()` / `valueOf()` on scanned enums: 22 edges (19 medium, 3 high).** Example: `for(Version version: values()) {` gives `org.apache.orc.OrcFile.Version#values`, medium. The 3 high edges are `OrcFile.WriterVersion#values` (OrcFile.java:220, 224; ReaderImpl.java:73, `OrcFile.WriterVersion.values()`); WriterVersion also declares a field `private static final WriterVersion[][] values`.
  - Open question: is a method the compiler declares implicitly for a scanned enum (JLS 8.9.3) "defined in the scanned source" (high), or "named statically but not defined in the scan" (medium)?
  - Open question: when such an enum also declares a field of the same name, do the field and the method share the one ID `Type#values`?
- **G2: anonymous subclass of an external interface: 2 edges.** These are `new PathFilter() {` (FileDump.java:68, giving `org.apache.hadoop.fs.PathFilter#<init>`, medium) and `new FilterContext() {` (TreeReaderFactory.java:2835).
  - Open question: the anonymous-subclass rule gives no constructor edge when the named type is an interface, and the 2026-11-09 rule limits typing to declarations in the scan. Does the interface-or-class test apply to types whose kind is only knowable from a library outside the scan?
- **G3: field chain rooted at a cast: 2 edges.** These are `return ((HiveType) other).kind.equals(kind);` (HiveType.java:63, giving `kind.equals`, low) and `((StructType) type).fields.entrySet()) {` (JsonSchemaFinder.java:186, giving `fields.entrySet`, low).
  - Open question: decision A and "Typed call results" list declarations, call results, indexes and literals. Does a parenthesized cast expression `((T) x)` type the receiver chain that follows it?
