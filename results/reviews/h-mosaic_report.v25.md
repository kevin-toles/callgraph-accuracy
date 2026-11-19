# h-mosaic (kotlin) blind call-graph review, round 25

precision 42/50; census ≈99.57% (62 wrong of 14267 in-scope); recall: 0 missed of 37 real calls; 0 non-calls

(The 50-edge sample has 2 wrong edges and 6 spec gaps. Spec gaps are not counted as wrong.)

## Scope
Tool output is `<scans>/kt45-A/h-mosaic.v2.json`, which has 15447 edges in total. I kept edges whose `source_file` is `.kt`/`.kts` and has no path segment named exactly test/tests/spec/examples/docs. Under the 2026-11-09 scope rule, `commonTest/`, `jvmTest/`, `samples/`, `tools/` and build-logic are in scope. I ignored the c (791), h (300), java (59) and zig (30) edges. **In-scope: 14267 edges from 230 files.**
- By confidence: high 7009, medium 5185, low 1641, unknown 432.
- By call_type: direct 7915, method 4342, constructor 1273, callback 432, implicit 305.

There is one coverage note: `samples/rrtop/.../RrtopViewModel.kt` is partial (syntax_error from line 92). That is unsupported by design, so it is a recall gap, not a set of wrong edges. I ignored `measured_accuracy`.

**Sample:** seed 2525. Stratified as high 23, medium 16, low 6, unknown 5, with at most 2 edges per file, over 36 files.

## Mismatch table (sample, recall and census findings)
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| mosaic-runtime/src/commonTest/.../layout/SizeTest.kt:827 | `assertThat(calculateSizeFor(parentModifier, Modifier.fillMaxSize().then(childModifier)))` | SizeTest#testFillModifier_correctSize → `.then`, low, method | `com.jakewharton.mosaic.modifier.Modifier#then`, high, method. `fun Modifier.fillMaxSize(fraction: Float = 1f): Modifier` is scanned, so "Typed call results" applies. | wrong callee / wrong confidence | declared return type of a scanned extension not used to type the call result |
| mosaic-tty/src/commonTest/.../tty/TtyTest.kt:27 | `tty.close()` | TtyTest#after → `tty.close`, low, method | `com.jakewharton.mosaic.tty.Tty#close`, high, method. `private val tty = testTerminal.tty`, where `testTerminal = TestTerminal.bind()` (declared `: TestTerminal`) and `public val tty: Tty`. This is the 2026-11-12 let-bound ruling plus the parameterless-member rule. | wrong callee / wrong confidence | a `val` bound to a typed property getter is not typed |
| mosaic-runtime/src/commonTest/.../stuff.kt:86 (recall) | `val childConstraints = containerConstraints.copy(minWidth = 0, minHeight = 0)` | com.jakewharton.mosaic.Container → `com.jakewharton.mosaic.copy`, high, direct | `containerConstraints` comes from the overloaded `constrain` (`Constraints.constrain(Constraints): Constraints` and `Constraints.constrain(IntSize): IntSize`). That is overload-ambiguous, so the edge should be the low guess `containerConstraints.copy` (method). `com.jakewharton.mosaic.copy` is `internal inline fun TerminalState.copy(`, an extension on a different type. | wrong callee | bare-name match to a same-package extension, regardless of receiver |
| mosaic-runtime/src/commonMain/.../layout/KeyModifier.kt:57 | `): Modifier = this then KeyModifierElement(null, onKeyEvent)` | onKeyEvent → `.then`, low, method | `Modifier#then`, high, method. `this` is the declared `Modifier` receiver, and `this.then(` in ComposedModifier.kt:81 resolves to `Modifier#then` high (C2). | wrong callee / wrong confidence | infix call on `this` left as a computed-receiver guess |
| mosaic-runtime/src/commonMain/.../text/AnnotatedString.kt:148 | `this.text.append(text)` | AnnotatedString.Builder#append → `String#append`, medium, method | `StringBuilder#append`, medium. The field is `private val text = StringBuilder(capacity)`; line 191 already gets StringBuilder. | wrong callee | `this.text` typed by the shadowing parameter `text: String` |
| mosaic-runtime/src/commonMain/.../ui/Arrangement.kt:232 | `SpacedAligned(space) { size -> Alignment.Start.align(0, size) }` | Arrangement#spacedBy → `com.jakewharton.mosaic.ui.Alignment.Start#align`, medium | `com.jakewharton.mosaic.ui.Alignment.Horizontal#align`, high. `public val Start: Horizontal` is a companion property, not a type. | wrong callee / wrong confidence (C2 invented ID) | companion property treated as a nested type |
| mosaic-animation/src/commonMain/.../InfiniteTransition.kt:225 | `TransitionAnimationState(initialValue, targetValue, typeConverter, animationSpec, label)` | animateValue → `com.jakewharton.mosaic.animation.TransitionAnimationState#<init>`, medium, constructor | `com.jakewharton.mosaic.animation.InfiniteTransition.TransitionAnimationState#<init>`, high. It is an inner class reached through the `InfiniteTransition.` extension receiver. | wrong callee / wrong confidence (C2 invented ID) | inner class not qualified by its outer type |
| mosaic-animation/src/commonMain/.../FloatAnimationSpec.kt:134 | `return spring.updateValues(initialValue, initialVelocity, playTimeMillis).value` | FloatSpringSpec#getValueFromNanos → `spring.updateValues`, low | `com.jakewharton.mosaic.animation.SpringSimulation#updateValues`, high. `spring` is bound to `SpringSimulation(...)` (decision A, `= T(...)`). | wrong callee / wrong confidence | property bound to a scanned constructor not typed |
| mosaic-runtime/src/commonMain/.../layout/Animatable.kt:448 (sample #12) | `private val positiveInfinityBounds1D = AnimationVector(Float.POSITIVE_INFINITY)` | `com.jakewharton.mosaic.animation.positiveInfinityBounds1D` → AnimationVector, high, direct | callee correct; caller undecided | spec gap (kotlin/17) | top-level property initializer |
| .../layout/Size.kt:488 (sample #30) | `maxHeight.coerceAtLeast(0)` | SizeModifier#targetConstraints → `Int#coerceAtLeast`, medium | undecided | spec gap (kotlin/16 q2) | stdlib extension on a typed receiver |
| .../text/AnnotatedStringBuilderTest.kt:100 (sample #33) | `val expectedSpanStyles = listOf(` | → `kotlin.collections.listOf`, medium | undecided | spec gap (kotlin/16 q1) | default-import stdlib function |
| .../text/AnnotatedStringBuilderTest.kt:442 (sample #39) | `with(AnnotatedString.Builder()) {` | → `kotlin.with`, medium | undecided | spec gap (kotlin/16 scope functions) | scope function |
| mosaic-testing/.../TestMosaic.kt:41 (sample #41) | `val result = block.invoke(tester)` | runMosaicTest → `block.invoke`, low, method | undecided | spec gap | explicit `.invoke` on a function-typed parameter |
| .../EventParserCsiCursorPositionEventTest.kt:27 (sample #43) | `UnknownEvent("1b5b3152".hexToByteArray()),` | → `.hexToByteArray`, low | undecided | spec gap (kotlin/16 q2, `"x".uppercase()`) | stdlib extension on a literal |

Sample edges judged correct include these notes:
- Explicitly imported third-party and stdlib extension functions (`assertk.assertions.isEqualTo`/`isTrue`, `kotlin.math.roundToInt` with `import kotlin.math.roundToInt`) are named through their explicit import: medium, direct.
- `BoxScope#matchParentSize` high is a body-less member of a scanned interface.
- `converter.convertToVector(...)` → `convertToVector`, callback, unknown, because it is the function-typed property `val convertToVector: (T) -> V`.
- The `testIntrinsics` lambda parameters (`maxIntrinsicWidth(0)`) are callback, unknown.
- `.toFloat` on `(a - b)` arithmetic is low, because typing reaches only scanned declarations.

## Systematic patterns (scripted; `h-mosaic_r25_census.py`; union 62)
1. **P2: a `val` bound to a typed property or a scanned constructor stays `recv.m` low (27).**
   - Covers TtyTest.kt (21, `private val tty = testTerminal.tty`), BaseEventParserTest.kt (1), FloatAnimationSpec.kt `spring` (2) and DataPipes.kt:125/175/217 (3).
   - DataPipes.kt:175 is `testTerminal.tty.enableRawMode()`, where `testTerminal: TestTerminal` is a parameter, so `Tty#enableRawMode` applies.
   - Hand-checked: TtyTest.kt:18-19, BaseEventParserTest.kt:10-11, FloatAnimationSpec.kt:134, DataPipes.kt:122-125.
   - I excluded script hits where the binding goes through an external generic (`asStableRef<Tty.Callback>().get()`, `.use { streams -> }`, `.apply {}`, the elvis `?: defaultEasing`).
2. **P3: infix `this then X` inside `fun Modifier.f(...)` is emitted as `.then` low (13).** It should be `Modifier#then` high. CAPABILITIES lists infix calls as an open defect (kotlin/15). Hand-checked DrawModifier.kt:30, Intrinsic.kt:18, LayoutId.kt:11.
3. **P1: a call result typed by a scanned function's declared return type stays `.m` low (12).** Examples are `Modifier.fillMaxWidth().then(...)` and `Modifier.height(size).then(...)`; the correct callee is `Modifier#then` high. Hand-checked SizeTest.kt:85, 823, 827 and RowColumnTest.kt:2341.
4. **P4: `this.text.append(...)` in AnnotatedString.Builder is typed by the shadowing parameter (5).** It gives String/CharSequence/AnnotatedString#append instead of `StringBuilder#append`. Lines 148, 162, 183, 202, 219.
5. **P5: a companion property used as a qualifier becomes an invented type ID (2).** `Alignment.Start#align` and `Alignment.Center#align` should be `Alignment.Horizontal#align` / `Alignment#align`, high.
6. **P6: inner-class constructor gets an invented top-level ID (2).** `TransitionAnimationState#<init>` appears in InfiniteTransition.kt:225 and Transition.kt:1758. The correct IDs are `InfiniteTransition.TransitionAnimationState#<init>` and `Transition.TransitionAnimationState#<init>`.
7. **P7: `x.copy(...)` resolved to the same-package `TerminalState.copy` extension (1)**, at stuff.kt:86. The three `state.value.copy(...)` edges in mosaic.kt really are `TerminalState.copy`, so I did not count them.

## Missed-call patterns (recall)
Recall functions:
- `com.jakewharton.mosaic.Container` (stuff.kt:67-115): 20 calls, all emitted. One is wrong (stuff.kt:86, above).
- `com.jakewharton.mosaic.animation.KeyframesSpec#vectorize` (AnimationSpec.kt:560-595): 12 calls, all emitted.
- `com.jakewharton.mosaic.testing.runMosaicTest` (TestMosaic.kt:31-44): 5 calls, including the default-argument `TestTerminal.Capabilities()`, all emitted.

Missed: 0 of 37. Non-calls: 0.

## Spec gaps (counted separately; total union 1379 edges, 1 of which overlaps a wrong edge)
- **G1, kotlin/16 (default imports): `kotlin.*` callee IDs (651, 649 medium).** Example: `listOf(`, `check(gotMpp) {`. SPEC leaves open whether a Kotlin default-import name is `kotlin.collections.listOf` medium or a bare `listOf` low, since the "implicitly imported names" ruling lists only Java/Scala/Groovy. My script's count also includes explicitly imported `kotlin.math.*`.
- **G1b, kotlin/16 q2: low guesses on stdlib scope or extension functions (181).** Examples: `.use`, `.let`, `.also`, `.apply`, `repeat`, `forEach` (`HttpClient.newHttpClient().use { client ->`). SPEC leaves open what ID a stdlib extension or scope function gets on a receiver: the extension's top-level ID, `T#m`, or a low guess.
- **G4: bare low calls on an implicit receiver (268).** These are lambda-with-receiver blocks (`with(Builder(this)) { append(...) }`, `buildAnnotatedString { append(...) }`, `buildString { append(...) }`), the `MeasureScope` receiver of `Layout { }` / `override fun MeasureScope.measure` (`layout(width, height) {}`), and `DisposableEffect { onDispose { } }`. SPEC defines `this.m()` and bare calls only for "a member of the enclosing type". It does not say whether the implicit receiver of a lambda with receiver, or of an extension function, types bare calls (`AnnotatedString.Builder#append`, `MeasureScope#layout`), or whether they stay bare low guesses. The tool does both: `AnnotatedString.Builder#append` high 39 times and `append` low 114 times.
- **G2, kotlin/17: callers that are top-level property initializers (251).** Example: `private val positiveInfinityBounds1D = AnimationVector(Float.POSITIVE_INFINITY)` → caller `com.jakewharton.mosaic.animation.positiveInfinityBounds1D`. SPEC leaves open whether the caller is `pkg.name`, the file facade `pkg.FileKt#name`, or a module ID, and whether there is an implicit `<clinit>` edge.
- **G5: member-extension calls on a Modifier chain inside a scope lambda (49).** Examples: `.weight`, `.align`, and `Modifier.weight` under `with(ColumnScopeInstance)`, as in `Box(Modifier.align(Alignment.BottomEnd).align(Alignment.TopStart))`. SPEC leaves open what ID a member extension (`fun Modifier.weight(...)` declared inside `interface RowScope`) gets when its extension receiver is a typed call result and its dispatch receiver is an implicit lambda receiver: `RowScope#weight`, `Modifier#weight`, or a `.weight` guess.
- **G3: `f.invoke(...)` / `f?.invoke(...)` on function-typed values (13).** Example: `block?.invoke(this@Animatable)`. SPEC leaves open whether an explicit `.invoke` on a parameter of function type is the callback rule's `block`, callback, unknown, or a method call `block.invoke`. This is the Kotlin analogue of java/18.

Helper scripts are in `<fanout>/`: `h-mosaic_r25_load.py`, `_sample.py`, `_opener.py`, `_types.py`, `_p1.py`, `_p2.py`, `_p8.py`, `_gaps.py`, `_census.py`.
