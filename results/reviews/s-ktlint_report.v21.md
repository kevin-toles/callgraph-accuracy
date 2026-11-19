# Blind call-graph review: s-ktlint (kotlin), round 21

precision 36/50; census ≈98.9% (93 wrong of 8719 in-scope); recall: 0 missed of 33 real calls; 0 non-calls

(The other 14 sample edges: 2 wrong, 12 spec gaps. Calls missed outside the three recall functions are listed under Missed-call patterns: 9 found.)

## Scope
Source root `<source-root>/company-oss/pinterest/ktlint`. Tool output `kr40-A/s-ktlint.v2.json`: 25,922 edges, every one from a `.kt` file. 17,203 come from paths with a `test/` segment (`src/test/kotlin`) and are out of scope. **In scope: 8,719 edges in 222 files.**
- By confidence: high 3,731, medium 2,026, low 2,593, unknown 369.
- By call_type: method 5,025, direct 1,732, implicit 809, constructor 784, callback 369.
- Module names that contain "test" (`ktlint-test-ruleset-provider-v3-deprecated`) and the `com/example` package (`ktlint-api-consumer`) are in scope.
- Coverage notes: two in-scope build-logic files are marked partial (`KtlintCliTask.kt` and `ShadowJarExecutableTask.kt`, syntax_error from line 48).
- I ignored the `measured_accuracy` field.

Sample: seed 21, stratified high 20 / low 14 / medium 11 / unknown 5, spread over 40 files. Helper scripts are `fanout/s-ktlint_r21_*.py` (and `s-ktlint_r21_ctx.sh`).

Sample verdicts:
- **Correct (36):** #2–8, 10–12, 14–21, 25–32, 34–36, 40, 43, 46–50.
- **Wrong (2):** #1, #37.
- **Spec gap (12):**
  - #9, #13, #24, #42: kotlin/17, caller is a top-level property.
  - #22, #23: kotlin/16, stdlib extension on a typed receiver, low form.
  - #38, #39, #45: kotlin/16, stdlib extension on a typed receiver, `ASTNode#let` / `#takeIf` form.
  - #41: kotlin/16, default-imported type `ArrayList`.
  - #44: kotlin/16, `kotlin.require`.
  - #33: class property with no written type.

Recall functions:
- `loadBaseline` (Baseline.kt:76–103): 7 calls.
- `KtlintCommandLine#lintStdin` (KtlintCommandLine.kt:414–433): 9 calls.
- `NoLineBreakBeforeAssignmentRule#visitEquals` (NoLineBreakBeforeAssignmentRule.kt:33–65): 17 calls.

All 33 calls have an edge. Five of those edges are wrong and are counted in the census: `load`/`delete` (W1) and three `parent.addChild` (W6). The `LOGGER.error` edges are spec gaps (G2b).

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| EditorConfigPropertyRegistry.kt:69 (sample #1) | `find { it.type.name == propertyName }` inside `private fun List<EditorConfigProperty<*>>.findProperty(...)` | `EditorConfigPropertyRegistry#findProperty → EditorConfigPropertyRegistry#find`, high, method | The innermost implicit receiver is the `List` extension receiver, so the call runs the stdlib `find(predicate)`. It is not the class member `find(propertyName: String)`. The exact stdlib ID is kotlin/16 | wrong callee | bare name bound to the dispatch class's same-named member |
| KtlintCommandLine.kt:709 (sample #37) | `String(System.`in`.readBytes()) … .split(delimiter.ifEmpty { "\u0000" })` | `#readPatternsFromStdin → com.github.ajalt.clikt.parameters.options.split`, medium, direct | The receiver is a `String` (in-place constructor, 2026-11-17), so this is the stdlib `split`. The clikt `split` (an option transformer) cannot apply | wrong callee | imported extension name applied without regard to the receiver |
| FunctionExpressionBodyRule.kt:116 | `with(block.parent!!) { addChild(LeafPsiElement(EQ, "="), block)` | `#visitFunctionBody → addChild`, low, direct | `org.jetbrains.kotlin.com.intellij.lang.ASTNode#addChild`, medium, method. `parent` is declared `ASTNode?` and `!!` unwraps it | wrong callee | implicit receiver of `with`/`apply`/`run` not typed (W1) |
| IfElseBracingRule.kt:162 | `KtBlockExpression(null).apply { addChild(LeafPsiElement(LBRACE, "{"))` | `IfElseBracingRule#autocorrect → addChild`, low, direct | `…KtBlockExpression#addChild`, medium, method: an in-place external constructor gives the receiver its type | wrong callee | W1 |
| StatementWrappingRule.kt:147 | `private inline val ASTNode.isBlockWithoutStatements … findChildByType(LBRACE)` | `→ findChildByType`, low, direct | `ASTNode#findChildByType`, medium, method (extension-property receiver) | wrong callee | W1: the receiver of an extension *property* getter is not used. Extension functions are handled (sample #40) |
| GitHookCliktCommand.kt:27 | `echo(e.message, err = true)` in `class GitHookCliktCommand … : CliktCommand(name = name)` | `#installGitHook → echo`, low, direct | `io.github.ktlint.core.cli.internal.GitHookCliktCommand#echo`, medium, method (inherited from a base outside the scan) | wrong callee | W1 |
| Baseline.kt:82 | `with(BaselineLoader(path)) { try { load()` | `loadBaseline → load`, low, direct | `io.github.ktlint.core.cli.reporter.baseline.BaselineLoader#load`, high, method | wrong callee | W1 (recall function) |
| KtlintSuppressionRule.kt:205 | `.applyIf(node.elementType == BLOCK_COMMENT && shouldBePromotedToParentDeclaration(ruleIdValidator))` in `fun KtLintDirective.visitKtlintDisableDirective` | `→ shouldBePromotedToParentDeclaration`, low, direct | `…rules.KtLintDirective#shouldBePromotedToParentDeclaration`, high, method | wrong callee | W1 |
| CodeFormatter.kt:129 | `val (line, col) = positionInTextLocator(offset)` (`val positionInTextLocator: (offset: Int) -> LineAndColumn` on `RuleExecutionContext`) | `→ positionInTextLocator`, low, direct | `positionInTextLocator`, unknown, callback. The same call in RuleExecutionContext.kt:154 is already callback/unknown | wrong confidence + call_type | W4 |
| NoLineBreakBeforeAssignmentRule.kt:51 | `parent.addChild(PsiWhiteSpaceImpl(" "), before)` with `val parent = assignmentNode.parent!!` | `#visitEquals → parent.addChild`, low, method | `ASTNode#addChild`, medium, method (a local bound to a typed property, 2026-11-12) | wrong callee | W6 |
| KdocDelimiterRule.kt:301 | `node.parent { it.elementType == KDOC }!!.findChildByType(KDOC_START)!!` | `→ .findChildByType`, low, method | `ASTNode#findChildByType`, medium. `parent(predicate)` is declared `: ASTNode?` | wrong callee | W6: a typed call result followed by `!!` is not typed |
| KtlintApiConsumer.kt:141 | `} catch (e: ServiceConfigurationError) { … e.printStackTrace()` | `→ e.printStackTrace`, low | `java.util.ServiceConfigurationError#printStackTrace`, medium, method (catch parameter, decision A) | wrong callee | W6 |
| ASTNodeExtension.kt:637 | `offsetToTheLeft += leaf.textLength - 1 - leaf.text.lastIndexOf('\n')` | `com.pinterest….column → leaf.text.lastIndexOf`, medium, direct | A receiver chain, not a qualified name: `text.lastIndexOf`, low, method (or typed) | wrong callee + confidence + call_type | W7: a dotted property chain is emitted as an invented module path (C2) |
| editorconfig/EditorConfig.kt:21 | `public constructor(vararg properties: Property) : this(properties.associateBy { … })` | `EditorConfig#<init> → org.ec4j.core.model.Property#associateBy`, medium, method | The receiver is an `Array<out Property>`, and a call on the array names no type (2026-11-17): `properties.associateBy`, low | wrong callee | W9: vararg parameter typed as its element |
| LoadReporterProviders.kt:10 | `val providerId: (ReporterProviderV2<*>) -> String = { it.id }` … `providerId(it)` | `loadReporters → providerId`, unknown, callback | `io.github.ktlint.core.cli.internal.loadReporters.providerId`, high, direct (named nested function) | wrong callee + confidence | open defect kotlin/06 |
| LoadReporterProviders.kt:9 | `ReporterProviderV2::class.java.loadFromKtlintCliJar(providerId)` | (no edge) | `loadReporters → io.github.ktlint.core.cli.internal.loadFromKtlintCliJar`, high, direct | missed call | M1: calls on a `T::class.java` receiver are dropped |
| editorconfig/EditorConfig.kt:20 | `public constructor(vararg properties: Property) : this(` | (no edge) | `EditorConfig#<init> → EditorConfig#<init>`, high, constructor | missed call | M2: open defect kotlin/01/04 (`: this(…)`) |
| SpacingAroundDotRule.kt:42 (sample #9) | `public val SPACING_AROUND_DOT_RULE_ID: RuleId = SpacingAroundDotRule().ruleId` | caller `…rules.SPACING_AROUND_DOT_RULE_ID` | caller of a top-level property initializer is undecided | spec gap | kotlin/17 |
| EditorConfigLoader.kt:34 (sample #13) | `private val LOGGER = KotlinLogging.logger {}.initKtLintKLogger()` | caller `…internal.LOGGER` → `initKtLintKLogger`, high | callee correct; caller undecided | spec gap | kotlin/17 |
| MaxLineLengthEditorConfigProperty.kt:42 (sample #24) | `.let {` in the initializer of top-level `MAX_LINE_LENGTH_PROPERTY` | caller `com.pinterest….MAX_LINE_LENGTH_PROPERTY → .let`, low | caller undecided (callee `.let` on an ec4j result is correct as low) | spec gap | kotlin/17 |
| KtlintApiConsumer.kt:137 (sample #42) | `URLClassLoader(emptyArray<URL?>()),` in top-level `private val runtimeLoadedRuleProviders = …` | caller `…consumer.runtimeLoadedRuleProviders → java.net.URLClassLoader#<init>`, medium | callee correct; caller undecided | spec gap | kotlin/17 |
| IndentationRule.kt:570 (sample #22) | `?.let { length -> " ".repeat(length) }` | `→ .repeat`, low | stdlib extension on a literal (the gap's own `"x".uppercase()` example) | spec gap | kotlin/16 |
| KtlintCommandLine.kt:421 (sample #23) | `stdinPath?.expandTildeToFullPath()?.let { path -> Paths.get(path) }` (declared `: String`) | `→ .let`, low | stdlib extension on a typed receiver: ID undecided | spec gap | kotlin/16 |
| FunctionSignatureRule.kt:157 (sample #38) | `currentNode.lastChildLeafOrSelf.nextLeaf.let {` | `→ org.jetbrains.kotlin.com.intellij.lang.ASTNode#let`, medium | ID of a stdlib extension on a typed receiver undecided | spec gap | kotlin/16 |
| TypeParameterListSpacingRule.kt:136 (sample #39) | `node.nextSibling?.takeIf { … }` | `→ ASTNode#takeIf`, medium | as above | spec gap | kotlin/16 |
| NoUnitReturnRule.kt:41 (sample #45) | `node.nextLeaf.takeIf { it.isWhiteSpace }` | `→ ASTNode#takeIf`, medium | as above | spec gap | kotlin/16 |
| SuppressionLocator.kt:60 (sample #41) | `val suppressionHints = ArrayList<SuppressionHint>()` | `→ ArrayList#<init>`, medium | qualification of a default-imported type undecided | spec gap | kotlin/16 |
| IndentationRule.kt:1435 (sample #44) | `require(node.elementType == STRING_TEMPLATE)` | `→ kotlin.require`, medium, direct | `kotlin.require` medium vs bare `require` low undecided | spec gap | kotlin/16 |
| ClassSignatureRule.kt:324 (sample #33) | `val expectedParameterIndent = indentConfig.childIndentOf(node)` with `private var indentConfig = DEFAULT_INDENT_CONFIG` | `→ indentConfig.childIndentOf`, low | see G3 | spec gap | property with no written type |

## Systematic patterns (wrong), by scripted count
Union of wrong edges: **93 of 8,719** (`s-ktlint_r21_census.py` → `s-ktlint_r21_wrong.json`).
1. **W1, bare call on a typed implicit receiver left as a bare low guess: 55.** All 105 bare-name low edges were listed with their enclosing block (`s-ktlint_r21_bare.py`) and classified by hand:
   - `addChild` inside `with(x.parent!!)`, `x.parent?.apply {}`, `?.run {}` and `KtBlockExpression(null).apply {}`: 33.
   - `findChildByType` inside `with(node)` and in extension-property getters: 7.
   - `textContains` in `val ASTNode?.isWhiteSpaceWithNewline` getters: 4.
   - CliktCommand-inherited `echo`: 3.
   - Gradle `Project#hasProperty` / `#property` (via `with(target: Project)` and a `fun Project.` receiver): 3.
   - `with(PrintWriter(…)) { write; flush }`: 2.
   - `with(BaselineLoader(path)) { load(); delete() }`: 2.
   - `KtLintDirective#shouldBePromotedToParentDeclaration`: 1.

   I left out bare calls inside library-typed lambdas (`buildString`, `sequence`, `contract`, Gradle `configure<…> {}`, `ProcessBuilder(…).start()`); low is correct for those. Hand-checked 12. The sample does show that extension-*function* receivers resolve (`textContains('\n')` in `fun ASTNode.isMultiline()` → `ASTNode#textContains`).
2. **W7, a receiver property chain emitted as a dotted qualified name, medium/direct: 15.** Script: no `#`, at least two dots, no package root. Examples: `layout.buildDirectory.dir`, `leaf.text.lastIndexOf`, `psi.containingFile.virtualFile.name.replace`, `LTOKEN_SET.types.zip`. All 15 checked by hand. This invents IDs (C2) and gives them the wrong tier.
3. **W6, receiver typed by a scanned declaration left as a low guess: 11.** Candidates came from a script (`s-ktlint_r21_w6.py`, `s-ktlint_r21_w6b.py`, `s-ktlint_r21_bang.py`), and each was confirmed by hand. Cases:
   - Locals bound to `x.parent!!`, `node.outerIf()`, or a chain of declared ASTNode extension properties, then `.addChild` / `.textContains`.
   - A catch parameter (`e: ServiceConfigurationError`).
   - `node.ktlintDirectiveOrNull(…)?.visitKtlintDirective(…)`: the declared return is `KtLintDirective?`, and the callee is the member extension `KtlintSuppressionRule#visitKtlintDirective`, high.
   - `node.parent { … }!!.findChildByType`.

   This count is a lower bound: the script has false negatives on multi-line chains. Typing through a declared return does work elsewhere (`KtlintKotlinCompiler.createASTNodeFromText(…)?.findChildByType` → `ASTNode#findChildByType`).
4. **W9, a vararg array receiver typed as its element type: 8.** `vararg properties: Property` gives `Property#associateBy`. `vararg properties: Pair<…>` gives `Pair#isNotEmpty` / `Pair#forEach`. `this in elementType` over `vararg elementType: IElementType` gives `IElementType#contains`. `ignoreElementTypes.isEmpty()` gives `IElementType#isEmpty`. All 8 checked.
5. **W4, a call through a function-typed property via the implicit receiver, reported low/direct instead of callback/unknown: 1** (CodeFormatter.kt:129).
6. **W3, an imported extension applied to a receiver of another type: 1** (clikt `split` on a `String`, KtlintCommandLine.kt:709).
7. **W8, a bare stdlib call in a member extension bound to the dispatch class's member: 1** (`find`, sample #1). Script `s-ktlint_r21_w8.py` checked all 110 bare high-method calls inside extension functions; the other 109 are correct.
8. **Open defect kotlin/06, a lambda-bound local `val` called as a callback: 1** (LoadReporterProviders.kt:10). The local-`val`-lambda form occurs once in scope.

Checked and clean:
- All 809 implicit edges have the field on the line, `<clinit>` for object/companion members and `<init>` for class members. None of them is on a `const val` or a `by` delegate (2026-11-16 ruling).
- No empty callers.
- Every high callee is in `nodes`.
- Infix calls (`to`, `until`) are emitted. Every "missing" infix candidate was text inside a string, so the kotlin/15 defect was not seen.
- `RuleV2Provider { … }` correctly gives `RuleV2Provider#invoke`: a companion `operator fun invoke` behind a private constructor.

## Missed-call patterns (recall)
- **M1, calls on a class-literal receiver (`T::class.java.f(…)`): 6 of 6 missed** (script `s-ktlint_r21_classjava.py`; one comment-line hit excluded):
  - `loadFromKtlintCliJar` ×2.
  - `loadFromJarFile` ×3 (scanned extensions on `Class<T>`).
  - `getDeclaredConstructor` ×1.
- **M2, secondary-constructor delegation `: this(…)`: 3 missed** (two `EditorConfig.kt` copies and `ThreadSafeEditorConfigCache.CacheValue`). This is open defect kotlin/01/04.
- Recall functions: 0 missed of 33.

## Spec gaps (counted separately, not wrong)
Counts come from `s-ktlint_r21_gaps.py`, with wrong edges excluded. Categories overlap; the union is 1,546.
- **G1, kotlin/16 (Kotlin default imports and stdlib extensions): 1,165.** The gap asks whether `println`/`listOf` are `kotlin.io.println` (medium) or a bare `println` (low). It also asks which ID a stdlib extension on a typed receiver gets: `kotlin.collections.forEach`, `List#forEach`, or a low guess. That covers `let`/`apply`/`takeIf`.
  - G1a, 436 edges, e.g. `kotlin.require`, `kotlin.collections.setOf`.
  - G1b, 552 edges, e.g. `ASTNode#takeIf`, `Sequence#filter`, `List#forEach`. This uses a name list and slightly over-counts members such as `contains`.
  - G1c, 167 edges, e.g. `ArrayList#<init>`, `Pair#<init>`, `String#replace`, `IllegalStateException#<init>`: unqualified default-imported types.
  - G1d, 10 edges: bare `compareValuesBy`, `setOfNotNull`, and `firstOrNull` / `joinToString` on an extension receiver.
  - Not counted: low `.let` / `.takeIf` / `.repeat` guesses whose receiver is typed (samples #22, #23). The script found at least 27.
- **G2, kotlin/17 (top-level property initializers): 335.**
  - G2a, 238 edges whose caller is a top-level property ID: `private val LOGGER = KotlinLogging.logger {}.initKtLintKLogger()` → caller `…internal.LOGGER`. The gap asks whether that caller is `pkg.LOGGER`, the facade `FileKt#LOGGER`, or a module ID, and whether a `<clinit>` implicit edge exists. The tool emits none.
  - G2b, 97 edges `LOGGER.trace/warn/debug/info/error`. The gap asks whether a top-level property is typed by its initializer (here a scanned function declared `: KLogger`).
- **G3, a class property with no written type, initialized from another property's name: 82** (`indentConfig.childIndentOf/siblingIndentOf/parentIndentOf/indentLevelFrom`). Construct: `private var indentConfig = DEFAULT_INDENT_CONFIG` (or `IndentConfig.DEFAULT_INDENT_CONFIG`), reassigned later with `indentConfig = IndentConfig(…)`. Decision A requires a declared type or `= new T(…)`, and the 2026-11-12 let-bound ruling covers locals bound to a call result. SPEC does not say whether a member property typed only by a name initializer is a typed receiver.
- **G4, an implicit receiver typed only by an `as` cast: 5.** Examples: `(kotlinExtension as KotlinJvmExtension).apply { explicitApi() }` and `with(item(i) as Element) { getAttribute("name") }`. SPEC's decision A list does not include a cast expression's target type as a typing source for Kotlin.
- **G5, an extension function or property declared in the scan, called on a receiver whose type the spec does not determine: 52.** Examples: `.colored()` on string templates, `.emptyOrTrue()`, `editorConfigProperty.getParsedValueOrDefault()`. Kotlin binds these statically to the only applicable extension in scope. SPEC does not say whether that name alone resolves the call (high) or whether the `recv.m` low guess stands.
- **G6, one simple name imported from two packages, on a library-typed receiver: 1.** `option(…).multiple()` with both `…clikt.parameters.arguments.multiple` and `…options.multiple` imported; the tool picks `arguments.multiple`. SPEC does not say which ID an ambiguous import gives when the receiver's type is knowable only from library signatures.
- **G7, an unimported simple name resolved to a scanned type in another package: 1.** In SomeRuleSetProvider.kt:9, `RuleSetProviderV3(` appears with no import, in package `com.pinterest.ruleset.provider.deprecated`. The tool resolves it to `com.pinterest.ktlint.cli.ruleset.core.api.RuleSetProviderV3#<init>`, high. SPEC does not say how a name the file cannot see (code that would not compile) is resolved.
