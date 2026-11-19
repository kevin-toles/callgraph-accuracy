# circe (scala) call-graph review, v3

Summary: precision 49/50; recall: 0 missed of 47 real calls; 0 non-calls

**Scope.** 3,919 of the 9,888 edges are in scope: `.scala` files not under test/tests/spec/examples/docs/vendor/third_party/generated. In-scope confidence counts are high 1,798, medium 1,202, low 782 and unknown 137. In-scope call types are method 2,692, constructor 577, implicit 345, direct 168 and callback 137.

**Sample.** I drew 50 edges with a fixed random seed. The draw was stratified roughly by tier count, with at least 5 edges per tier: high 22, medium 14, low 9, unknown 5. The sample covers 31 files, with at most 2 edges per file. Paths below are relative to `modules/`.

**Results.**
- The line number was correct on all 50 sampled edges and on every recall edge.
- One sampled edge is wrong (#31).
- Five sampled edges fall into spec gaps and are not counted as errors:
  - #9: the caller of a pattern `val`.
  - #28, #33, #34, #35: `new Trait {…}` for a scanned trait is rated medium.

**How precise is the whole output?**
- **From the sample:** 49/50 is 98%, but at n=50 that is consistent with anything from about 89% to 99.9%. The sample alone cannot separate 95% from 99%.
- **From the scripted counts:** the counts in "Systematic patterns" are more decisive. They find about 96 in-scope edges with a confirmed wrong pattern, which is 2.4% of 3,919. That puts precision at no more than about 97.5%.
- **Spec gaps:** they add about 200 edges that are open to dispute but not counted. 151 of them are trait instantiations rated medium.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| literal/src/main/scala-2/io/circe/literal/JsonLiteralMacros.scala:274 (sample #31) | `c.abort(c.enclosingPosition, s"Invalid JSON …")` (`import scala.reflect.macros.blackbox`, `class JsonLiteralMacros(val c: blackbox.Context)`) | JsonLiteralMacros#jsonStringContext → `blackbox.Context#abort`, medium, method | the type is qualified through its explicit import → `scala.reflect.macros.blackbox.Context#abort`, medium | wrong callee | an import of a package or object prefix is not applied to `prefix.Type` |
| benchmark/src/main/scala-2/io/circe/benchmark/PointerBenchmark.scala:45 (sample #9) | `val Right(pointer) = Pointer.parse("/foo/2/bar/baz/qux")` | PointerBenchmark#<init> → io.circe.pointer.Pointer#parse, high | callee and confidence are right. The spec says a field initializer's caller is `Type#field`, but it does not cover pattern definitions that may bind several names. The tool uses `#<init>` and emits no implicit edge. | spec gap | pattern-val initializer |
| core/shared/src/main/scala/io/circe/KeyDecoder.scala:121, Encoder.scala:214, Decoder.scala:553, shapes/…/SizedInstances.scala:36 (sample #28, #33, #34, #35) | `new KeyDecoder[A] {`, `new AsObject[Unit] {`, `new Decoder[A] {`, `new Decoder[Sized[C[A], L]] {` | → io.circe.KeyDecoder#<init> / io.circe.Encoder.AsObject#<init> / io.circe.Decoder#<init>, medium, constructor | The type is scanned, but it is a trait with no constructor. The spec does not say whether instantiating a scanned trait is high. The tool is consistent: all 151 in-scope `#<init>` edges for scanned traits are medium, and every scanned-class `#<init>` is high (331). | spec gap | instantiating a scanned trait |
| core/shared/src/main/scala/io/circe/Printer.scala:352 (recall, onString) | `if (esc != 1) writer.append(esc) else writeEscapedChar(writer, c)` | Printer.PrintingFolder#onString → `writeEscapedChar`, low, direct | `writeEscapedChar` is defined at Printer.scala:310 in the enclosing `object Printer`, and `PrintingFolder` is nested in it → io.circe.Printer#writeEscapedChar, high | wrong callee / wrong confidence | a member of the enclosing outer type, called from a nested class, is not resolved |
| core/shared/src/main/scala/io/circe/ACursor.scala:264, 268, 271, 276, 279, 286, 304, 306 (recall, pathToRoot.loop) | `loop(lastCursorParentOrLastCursor(cursor), PathElem.ObjectKey(field) +: acc)` (method-local `import PathToRoot._` at :238) | ACursor#pathToRoot.loop → `PathElem#ObjectKey` / `PathElem#ArrayIndex`, medium, method | io.circe.PathToRoot.PathElem.ObjectKey#<init> / io.circe.PathToRoot.PathElem.ArrayIndex#apply, high. The tool emits exactly these IDs for the same calls inside PathToRoot.scala:111-141. | wrong callee / wrong confidence | a method-local import is not followed for a nested scanned type |
| core/shared/src/main/scala/io/circe/Decoder.scala:1221, 1235 (recall, decodeEither) | `case _: HCursor => failure(c)`, where `failure` is a `private[this] def` of the same `new Decoder[...] { … }` (line 1211) | Decoder#decodeEither → `failure`, low, direct | Anonymous-class members fold into `decodeEither`. The spec gives the anonymous class's own helper defs no ID, so there is nothing to resolve the callee to. | spec gap | own member of an anonymous class |

Recall functions. I counted only calls written with parentheses. Operators, parameterless calls and case-pattern extractors are excluded as spec gaps, as in v2.
- **`io.circe.Printer.PrintingFolder#onString`** (Printer.scala:331-361): 9/9 found.
  - The four direct `writer.append(...)` calls → `Appendable#append`; the chained `.append('\\')` at :351 → `.append`; `value.charAt(i)` → `String#charAt`; `Character.isISOControl(c)` → `Character#isISOControl`.
  - The `writeEscapedChar` edge has the wrong callee (see table).
- **`io.circe.Decoder#decodeEither`** (Decoder.scala:1207-1239): 13/13 found, counting the `new Decoder` constructor edge, the 2 `failure` calls and `decodeA(lc)` / `decodeB(rc)` → Decoder#apply. `l.asInstanceOf[...]` is a cast, and the tool correctly emits no edge for it.
- **`io.circe.ACursor#pathToRoot`** and its local defs `loop` / `lastCursorParentOrLastCursor` (ACursor.scala:237-317): 25/25 found.
  - `loop` 13 and `lastCursorParentOrLastCursor` 5 are high, with callee IDs in the `pathToRoot.loop` form.
  - The 8 `PathElem.*` edges have the wrong callee (see table).
  - `CursorOp.Field(field)` etc. in `case` patterns are extractors, and the tool correctly emits no edge for them.

Sample edges I checked and found correct include these:
- **Anonymous-class folding:** ReprAsObjectCodec#codecForCNil → DecodingFailure#apply; KeyEncoder#keyEncoderContravariant → KeyEncoder#contramap; Decoder#decodeNonEmptyMap → `scala.collection.immutable.SortedMap#newBuilder`.
- **Member calls inside an anonymous class:** Printer#pieces → `Printer.MemoizedPieces#addIndentation`, high.
- **Nested types:** Json.JArray#foldWith → Json.Folder#onArray. CirceSupportParser.UnlimitedFacade#jnum → JsonNumber#fromIntegralStringUnsafe.
- **Local def:** CodecLaws#codecFromConsistency → `CodecLaws#codecFromConsistency.output`, high.
- **Array update:** `res(index) = value` → `Array#update`.
- **Explicit imports:** `org.typelevel.jawn.FContext#<init>`, `shapeless.Inl#apply`.
- **Receivers:**
  - Unknown receivers in the `recv.m` form: `value.apply`, `writer.append`, `format.format`, `toMap.mapValues`, `laws.decodingRoundTrip`.
  - Computed receivers in the `.m` form: `.map`.
- **Callbacks:** `pred`, `onNumber_`, `decode`, `f` and `f`, all unknown/callback.
- **Implicit initializer edges:** `#<init>` / `#<clinit>` → field, with the companion object flattened onto the class.

## Systematic patterns

The counts below are scripted over the in-scope edges, with the whole-output count (all 9,888 edges) in parentheses where it differs. Each pattern ends with the edges it covers and the root cause; patterns 1-10 total about 96 in-scope edges.

1. **Explicit imports not applied (32 + 23 edges).** The leading import-qualification gap.
   - **Prefix or renamed imports (32).**
     - 24 edges import a package or object prefix, so the callee keeps the short form: `blackbox.Context#abort/typecheck/Expr`, `whitebox.Context#Expr`, from `import scala.reflect.macros.blackbox`.
     - 2 edges have `util.LinkedHashMap#<init>/put` from `import java.util`.
     - 6 edges (7) use a renamed import: `import java.math.{ BigDecimal => JavaBigDecimal }` gives `JavaBigDecimal#<init>/valueOf/compareTo` instead of `java.math.BigDecimal#…`.
   - **Imported functions left as bare low direct names (23).**
     - 14 edges (19) are `field`, from `import shapeless.labelled.{ FieldType, field }`, which should be `shapeless.labelled.field`, medium.
     - 7 edges are `error` 3, `codeOf` 2 and `summonFrom` 2, from `import scala.compiletime.{ codeOf, …, error, summonFrom, … }`.
     - 1 edge is `tag`, from `import shapeless.tag`.
     - 1 edge is `convertJsToJson` in parser/js/…/package.scala:25. It comes from `import io.circe.scalajs.convertJsToJson`, a scanned package-object member, so it should be `io.circe.scalajs.convertJsToJson`, high.

   Root cause: an import that names a package prefix, renames a type, or names a function or val is not used for qualification. Plain `import pkg.Type` works.
2. **A method-local import is not followed (8 edges).** ACursor.scala's `import PathToRoot._` inside `pathToRoot` leaves `PathElem#ObjectKey` (3) and `PathElem#ArrayIndex` (5) medium. They should be `io.circe.PathToRoot.PathElem.*`, high.
3. **A nested type inherited from a scanned supertrait is not resolved (5 edges).** `new IterableAsArrayEncoder[A, Seq](encodeA)` at Encoder.scala:383/391/399/407/415, inside `object Encoder … with MidPriorityEncoders`, gives `IterableAsArrayEncoder#<init>`, medium. The same call inside `MidPriorityEncoders` (Encoder.scala:987) gives `io.circe.MidPriorityEncoders.IterableAsArrayEncoder#<init>`, high.
4. **Indexing a member collection is labeled as a bare call (7 edges).** `elemLabels(index)` / `elemEncoders(index)` / `elemDecoders(index)` (Derivation.scala:62/85/88, ConfiguredEncoder.scala:29/42, ConfiguredDecoder.scala:108) become bare `elemLabels` etc., low, direct. These names are `val`/`def` members of type `Array[...]`/`List[...]` declared in the scanned supertraits (Derivation.scala:44/59/82). This is indexing, which the tool elsewhere labels `Array#apply`/`#update`. Root cause: a member that is a value, not a method, applied to arguments.
5. **A member of an enclosing outer type or a scanned base, called from a nested or anonymous class, stays a bare low name (6 edges).**
   - `writeEscapedChar` 1: Printer.scala:352, object member called from the nested `PrintingFolder`.
   - `fail` 2: DerivationMacros.scala:177/179, called from the nested `Members`; `io.circe.generic.util.macros.DerivationMacros#fail` exists and is used high elsewhere.
   - `jstring` 2: CirceSupportParser.scala:56/64, `FContext` anonymous classes inside `BaseFacade`. `jstring` is declared on jawn's `Facade`, so it should be medium.
   - `apply` 1: Pointer.scala:33 `apply(input.hcursor)`, where `Pointer extends (ACursor => ACursor)`.
6. **Auxiliary-constructor calls are labeled `this`, low, direct (3 edges).** Error.scala:67/72 `this(Eval.now(reason))` and JawnParser.scala:77 `def this() = this(None, true)`. They should be the class's `#<init>`, high, constructor.
7. **Function values bound in a lambda or pattern are called as low direct instead of callbacks (3 edges).** Decoder.scala:1522 `case (f, a) => f(a)`, Decoder.scala:1526 and ArbitraryInstances.scala:140 `.map(f => Decoder.instance(c => f(c.value)))`. They should be `f`, unknown, callback.
8. **Calls to a local def written in Scala 3 indentation style are not resolved (3 edges).** `fromName` (ConfiguredDecoder.scala:60/77/94) stays bare low. The tool does define `io.circe.derivation.ConfiguredDecoder#decodeSumElement.fromName` and uses it as the caller at :60. All 48 other in-scope calls to local defs resolve high.
9. **A parameter type leaks across sibling methods of an anonymous class (at least 2 edges).**
   - extras.scala:88 `value.withArray(onArray)` and :92 `value.foldWith(self)` give `Vector#withArray` / `Vector#foldWith`, medium.
   - There, `value` is the lambda's `case (key, value)` binder, of type `Json`. `value: Vector[Json]` is the parameter of the sibling `onArray`.
   - I could only script a lower bound: medium edges on a std-collection type whose member name exists only on circe types.
10. **Other one-off callee errors (4 edges).**
    - parser/jvm-native/…/parser/package.scala:24 `parser.parse(input)`, where `private[this] val parser = new JawnParser`. The tool gives `io.circe.parser.parse`, high, which is the package-object method itself. The package name won over the shadowing val, and the correct callee is `io.circe.jawn.JawnParser#parse`.
    - 3 callees keep a `_root_.` prefix, e.g. `_root_.scodec.bits.ByteVector#fromBase64Descriptive`.

**Spec gaps (repeated, not counted as errors):**
- 151 edges (157): `new ScannedTrait {…}` → medium.
- 10 edges: own private helpers of an anonymous class (`failure`, `step`, `checkSize`).
- The Scala 3 anonymous `inline given Facade[…] with { … }` in literal/scala-3 JsonLiteralMacros:
  - Its members are named as local defs, `JsonLiteralMacros#jsonImpl.arrayContext` etc., on 27 caller edges.
  - Calls to its private helpers `toJsonString` / `toJsonKey` are bare low (6 edges).
- 8 edges: members reached through a self-type (`self: JawnParser =>`: `fromTry`, `finishDecode`, `finishDecodeAccumulating`).
- 9 edges: synthesized `copy`.
- 7 edges: `appliedType` from `import c.universe._`.
- 1 edge (66 whole output): pattern-val callers.
- 1 edge: `rhs(key)` on a `JsonObject` value.
- Operators and parameterless calls are still not emitted. Only 1 in-scope operator edge exists, `toMapAndVectorJsonObject.+:`.

## Previous findings

Mismatch-table rows of v2:

1. **`res(index) = value` labeled `Array#apply`: fixed.** All 10 assignments are now `Array#update`, and 0 `Array#apply` edges sit on assignment lines.
2. **scalajs package.scala:36 `Json.fromFields` unresolved: fixed.** It is now `io.circe.Json#fromFields`, high.
3. **`FnFromProduct.Aux#apply` not import-qualified: fixed.** It is now `shapeless.ops.function.FnFromProduct.Aux#apply`, medium.
4. **TopCursor.scala:37 `CursorOp.Field(k)` → `CursorOp#Field`: fixed.** It is now `io.circe.CursorOp.Field#<init>`, high.
5. **NumberParsingBenchmark.scala:83 `jawn.decode` low: fixed.** It is now `io.circe.Parser#decode`, high.
6. **`withDefault` caller is `Type#withDefault`: fixed.** Callers are now `ConfiguredDecoder#decodeProduct.withDefault` and `#decodeProductAccumulating.withDefault` (3 edges each).
7. **Spec gaps (operators, parameterless calls, applying a non-function value): unchanged.** Operators are still not emitted (1 edge), and neither are parameterless calls. Encoder/Decoder values applied → `#apply`, high, still holds.

Systematic patterns of v2:

1. **Explicit external imports not qualified: largely fixed.**
   - Before: 403 edges unqualified.
   - Now: 432 in-scope callees carry the full import path (org.scalacheck 69, cats.data 67, other cats 67, java.lang 62, shapeless 49, java.math 28, java.time 26).
   - Still present: 32 edges with prefix or renamed imports and 23 imported functions or vals (pattern 1 above).
2. **Nested scanned types medium and unqualified: mostly fixed.**
   - Qualification is fixed. 0 callees now start with a bare `Encoder.`/`Codec.`/`Json.`/`Printer.` outer name, down from 63. `io.circe.Printer.PrintingFolder#<init>` is high.
   - The remaining medium ones (`Encoder.AsArray` 12, `Encoder.AsObject` 10, `Codec.AsObject` 3, `Json.Folder` 2) are traits, which is the trait spec gap.
   - Nested case classes reached through their companion are fixed for CursorOp (DownField/Field/DownN, 10 high), `Json.JNumber#<init>` (12 high) and `Printer.Pieces#<init>` (2 high).
   - Still present: 8 `PathElem.*` edges via a method-local import (pattern 2) and 5 inherited nested-type edges (pattern 3). That is 13 edges, against 28 + 63 before.
3. **Package objects do not resolve their own package's types: fixed.** 0 of 78 in-scope package-object edges have an unqualified scanned-type callee, down from 23.
4. **Superclass members called inside anonymous classes are bare low names: mostly fixed.**
   - Low direct edges fell from 126 to 87.
   - `fail` dropped from 24 to 2: it now resolves as `Decoder.DecoderWithFailure#fail` 22, `HCursor#fail` 15 and `DerivationMacros#fail` 4, all high. The 2 left are from a nested class.
   - `addIndentation` dropped from 15 to 0; it now resolves as `Printer.MemoizedPieces#addIndentation`, high.
   - `self` dropped from 11 to 0; `self(c)` now resolves as `Decoder#apply`, high.
   - `writeEscapedChar` (1) is still present.
   - Of the 87 remaining:
     - about 45 are wrong (patterns 1, 4-8);
     - about 42 are spec gaps (copy, appliedType, anonymous-class or given helpers, self-type members, map2, rhs).
5. **`String`/`Any` resolved to HygieneTests shadow traits: fixed.** It was 31 edges and is now 0; JsonNumber/Printer `charAt` is now `String#charAt`, medium.
6. **Array element assignment labeled `Array#apply`: fixed.** All 10 are now `Array#update`.
7. **Calls through an imported scanned package object stay low: fixed for jawn, and the parser case is a new error.**
   - Of the old 19: `jawn.parse` 10 → `io.circe.jawn.JawnParser#parse`, high; `jawn.decode` 8 → `io.circe.Parser#decode`, high.
   - The 19th, `parser.parse` (parser/package.scala:24), was never a package-object call: `parser` is a local `val parser = new JawnParser`. It now resolves to the wrong callee, the package object's own `io.circe.parser.parse` (pattern 10).
8. **Local defs named as type members: fixed.**
   - In-scope IDs now use the `outer.f` form for 22 local defs, e.g. `ACursor#pathToRoot.loop`, `HCursor#find.go`, `JsonCodecMacros#codec.mkImplicitParams`, `CodecLaws#codecFromConsistency.output`.
   - 48 calls to them are high.
   - Residual: 3 `fromName` calls are unresolved (pattern 8).
   - The Scala 3 anonymous given's members are also given the local-def form (a spec gap).
