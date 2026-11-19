# s-grails-gradle (groovy): blind call-graph review, round 16

precision 49/50; census ≈99.49% (17 wrong of 3341 in-scope); recall: 0 missed of 61 real calls; 0 non-calls

## Scope
Tool output `<scans>/gk43-A/s-grails-gradle.v2.json` has 6543 edges: 5579 from `.groovy` files and 964 from `.java` files. In scope are the `.groovy` edges not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment: **3341 edges in 68 files**.
- By confidence: 1568 medium, 1096 low, 677 high, 0 unknown.
- By call_type: 2861 method, 262 constructor, 207 implicit, 11 direct, 0 callback.

I ignored `measured_accuracy`. Helper scripts are in the fanout folder with the prefix `s-grails-gradle_r16_` (load, sample, ctx, survey, selfmed, outer, lowtyped, deflocal, fieldchain, meddef, implicit, fieldcaller, newinplace, callres, callres2, chain, inherit, high, defreassign, literal, cast, recall, census).

**Precision sample:** 50 edges, seed 16: 24 medium, 16 low, 10 high, from 27 files. Results:
- 44 are correct.
- 5 are spec gaps: implicit edges on constant fields (#42, #43, #44, #48, #49).
- 1 is wrong (#10).

The summary's 49/50 counts the edges that are not wrong. Spec gaps are not counted as wrong.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| views/AbstractGroovyTemplateCompileTask.groovy:126 (sample #10) | `new Action<JavaExecSpec>() {` | `AbstractGroovyTemplateCompileTask#execute → org.gradle.api.Action#<init>`, medium, constructor | no edge: `org.gradle.api.Action` is an interface, and the anonymous-subclass rule gives no constructor edge for an interface | not a call | anonymous implementation of an external interface treated as a class instantiation |
| core/GrailsGradlePlugin.groovy:937 (+7 more lines, 941–967) | `task.systemProperty(sysPropName, value.toString())` with `<T extends JavaForkOptions & DefaultTask>` and closure param `T task` | `…#configureForkSettings.systemPropertyConfigurer → T#systemProperty`, medium, method | `org.gradle.process.JavaForkOptions#systemProperty` (`#jvmArgs` at line 967), medium: a type variable resolves to its declared bound (JavaForkOptions declares both methods) | wrong callee | bounded type parameter used as a type name (CAPABILITIES open defect groovy/05) |
| aot/TraceNativeMetadataTask.groovy:399 | `markups.max { String markup -> fieldsOf(markup).size() }` | `…TraceNativeMetadataTask#chooseForm → .size`, low, method | `java.util.Map#size`, medium: `private static Map<String, String> fieldsOf(String)` is declared in the scan (Typed call results) | wrong callee / confidence | receiver typed by a scanned method's declared return type left untyped |
| core/GrailsGradlePlugin.groovy:679 | `Environment.getCurrent().getName()` | `…GrailsGradlePlugin#createBuildPropertiesTask → .getName`, low, method | `grails.util.Environment#getName`, high: `static Environment getCurrent()` and `String getName()` are both in the scan | wrong callee / confidence | same as above |
| io/IOUtils.groovy:130 (×2 edges) | `def absolutePath = resource?.getFilename()` … `absolutePath.substring('file:'.length(), absolutePath.lastIndexOf('!'))` | `grails.io.IOUtils#findJarFile → absolutePath.substring` / `absolutePath.lastIndexOf`, low, method | `java.lang.String#substring` / `#lastIndexOf`, medium: `Resource.getFilename()` is declared `String` in scanned Resource.java, the local is not reassigned, and `?.` does not untype it (Decisions 2026-11-16 and 2026-11-12) | wrong callee / confidence | `def` local bound to a typed scanned call not typed |
| cli/profile/commands/script/GroovyScriptCommandTransform.groovy:77 | `def defaultConstructor = getDefaultConstructor(classNode)` (inside `static class CommandScriptTransformer extends ClassCodeVisitorSupport`; `static ConstructorNode getDefaultConstructor` is defined at line 143 on the outer class) | `…CommandScriptTransformer#visitMethodCallExpression → …GroovyScriptCommandTransform.CommandScriptTransformer#getDefaultConstructor`, medium, method | `org.grails.cli.profile.commands.script.GroovyScriptCommandTransform#getDefaultConstructor`, high | wrong callee / confidence | bare call from a static nested class to an outer-class static method named on the nested class as if inherited (C2: invented ID) |
| io/support/MainClassFinder.groovy:42 | `private static final Type STRING_ARRAY_TYPE = Type.getType(String[].class)` | `org.grails.io.support.MainClassFinder#<init> → groovyjarjarasm.asm.Type#getType`, medium, method | caller `org.grails.io.support.MainClassFinder#STRING_ARRAY_TYPE`, plus implicit `MainClassFinder#<clinit> → MainClassFinder#STRING_ARRAY_TYPE` (missing) | wrong caller (+ missed implicit) | static field whose initializer contains `String[].class` is not recognised as a field initializer; the neighbouring fields (lines 44–50) are handled correctly |
| aot/CliPublishingSupport.groovy:89, views/gsp/GroovyPageForkCompileTask.groovy:188 | `task.doLast(new Action<Task>() {` / `new Action<JavaExecSpec>() {` | `… → org.gradle.api.Action#<init>`, medium, constructor | no edge | not a call | same as sample #10 |

## Systematic patterns (scripted counts, union 17)
1. **Bounded type parameter named `T#m`: 8 edges.** This matches CAPABILITIES open defect groovy/05. All 8 are in `configureForkSettings.systemPropertyConfigurer`, on lines 937, 941, 942, 943, 951, 952, 953 and 967. Script: a callee type that is a single capital letter. All 8 checked by hand.
2. **Anonymous implementation of an external interface gets a constructor edge: 3 edges.** All are `new Action<…>() {`. The same script found anonymous subclasses of the ASM abstract classes `ClassVisitor` and `AnnotationVisitor` (GenerateScaffoldedViewsTask:259 and :266). Those constructor edges are correct. Script: a constructor edge whose line matches `new Action<…>() {`. All 3 checked by hand.
3. **Scanned call result left `.m` low (Typed call results): 2 edges** (TraceNativeMetadataTask:399, GrailsGradlePlugin:679). Script: a balanced-paren backward scan from every low `.m` edge to the call that produces its receiver, flagged when that call is a high edge on the same line. Multi-line chain continuations were checked separately; their heads (`requestTo(target).header`, `new ProcessBuilder(..).directory`, `new GStringTemplateEngine().createTemplate`) are all resolved.
4. **`def` local bound to a typed scanned call left low: 2 edges** (IOUtils:130). Script: low `x.m` edges whose nearest `def x =` declaration line carries a high edge, or whose initializer is `new`. The four other hits are correctly low because the `def` local is reassigned:
   - GroovyScriptCommandTransform:79, the reassignment of `defaultConstructor`;
   - MainClassFinder:93, the reassignment of `rootClassesDir`.
5. **Static nested class calling an outer static method bare: 1 edge** (GroovyScriptCommandTransform:77). Script: a nested caller type whose callee is on that same nested type, and the method is declared elsewhere in the file. This was the only hit.
6. **Static field initializer attributed to `#<init>`: 1 edge** (MainClassFinder:42). Script: a field-declaration line at class-body indent whose edge caller is not `Type#field`. This was the only hit.

Census precision = 1 − 17/3341 = 99.49%.

I also checked these, and found no wrong edges:
- High edges whose callee has no definition in the scan: 0.
- Medium edges on scanned types where the method is defined in the scan: 0. The only regex hit, `Environment#valueOf`, is the synthetic enum method, which is not written.
- Calls to a member inherited from a scanned superclass that are not named by the superclass: 0.
- In-place `new T(..).m()` left low: 0.
- Typed field or getter chains left low: 0. Every candidate's chain passes through a library signature or a generic `Map#get`.
- Super and this constructor-call lines: all correct.

## Missed-call patterns (recall)
I checked every call in three functions against the tool's edges:

| Function | Real calls | Missed | Non-calls |
|---|---|---|---|
| `grails.util.Metadata#loadFromDefault` (Metadata.groovy:129–166) | 25 | 0 | 0 |
| `org.apache.grails.gradle.plugin.aot.TraceNativeMetadataTask#awaitStarted` (TraceNativeMetadataTask.groovy:449–467) | 13 | 0 | 0 |
| `org.grails.gradle.plugin.scaffolding.GenerateScaffoldedViewsTask#loadTemplates` (GenerateScaffoldedViewsTask.groovy:164–190) | 23 | 0 | 0 |

These misses were found by looking, outside the recall functions. They are not in the precision census:
- **Enum constant constructor edges: 5 missed.** `Environment` declares DEVELOPMENT, PRODUCTION, TEST, APPLICATION and CUSTOM (Environment.groovy:46–61) and has a written constructor at line 222. No `grails.util.Environment#<clinit> → grails.util.Environment#<init>` edge exists. This matches CAPABILITIES open defect groovy/09.
- **Implicit edge: 1 missed.** `MainClassFinder#<clinit> → MainClassFinder#STRING_ARRAY_TYPE` (MainClassFinder.groovy:42) is absent. This goes with pattern 6.

## Spec gaps (not counted as wrong)
1. **Implicit edges on Groovy constant fields: 143 edges, 5 of them in the sample.**
   - Construct: `private static final String SPRING_BOOT_PLUGIN = 'org.springframework.boot'` (GrailsGradlePlugin.groovy:103) and `private static final long serialVersionUID = 1L` (GrailsI18nOptions.groovy:40). The count also includes `1 << 20` (StartupLog:49) and a two-line string literal (I18nBundleIndex:79).
   - Open question: the 2026-11-16 ruling says a compile-time constant runs no initializer and gets no implicit edge, but it names Java, Kotlin and C# `const` only. Does it also apply to Groovy `static final` primitive or `String` fields with constant initializers, or do these keep their `<clinit>` implicit edge?
2. **Receivers typed only by a cast: 7 edges.**
   - Construct: `((Provider) unqualified).getOrElse(false) as Boolean` (GroovyPagePlugin.groovy:113, 128, 142, 156) and `((ArgumentListExpression) methodCallArgs).getExpression(0)` (GroovyScriptCommandTransform.groovy:113). All five are emitted as `.getOrElse` / `.getExpression`, low.
   - Construct: `def testPhases = project.extensions.getByName(TestPhasesGradlePlugin.EXTENSION_NAME) as NamedDomainObjectContainer<TestPhase>`, then `testPhases.create(...)` (IntegrationTestGradlePlugin.groovy:52) and `testPhases.configureEach` (AbstractGroovyTemplatePlugin.groovy:101). Both are emitted as low guesses.
   - Open question: decision A lists declarations and `= new T(...)` as the sources of a receiver's type, and "Not calls" lists casts. Does a parenthesized cast `((T) x).m()`, or a `def` local bound to an `… as T` coercion, type the receiver as `T`?
3. **Method call on a named nested function's closure value: 2 edges.**
   - Construct: `def systemPropertyConfigurer = { String defaultGrailsEnv, T task -> … }`, then `systemPropertyConfigurer.curry(grailsEnvSystemProperty ?: …)` (GrailsGradlePlugin.groovy:974, 975). Both are emitted as `systemPropertyConfigurer.curry`, low, method.
   - Open question: SPEC makes such a local a named nested function (`…#configureForkSettings.systemPropertyConfigurer`), but it does not say what a method invoked on that binding's value is. It could be `groovy.lang.Closure#curry` (the value's runtime type), a receiver guess, or something else.
4. **Anonymous classes of external types:** this affects the 3 `Action` edges counted as wrong above.
   - Construct: `new Action<JavaExecSpec>() {`.
   - Question raised: the anonymous-subclass rule depends on whether the named type is an interface or a class. SPEC does not say how that is decided for a type outside the scan, whose declaration the tool cannot read. I counted these edges as wrong because the rule is stated without that condition and `Action` is an interface at runtime.
