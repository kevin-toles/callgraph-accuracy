# h-pdepend (PHP): blind call-graph review, round 7

Summary: precision 50/50; census ≈99.3% (38 wrong of 5600 in-scope); recall: 1 missed of 55 real calls; 0 non-calls

The 50 sampled edges break down as 44 correct, 6 spec gaps (namespaced builtins, php/15) and 0 wrong.

## Scope
Tool output: `<scans>/final13-A/h-pdepend.v2.json`. It has 22,819 edges, all with a `.php` source_file. 17,219 of them are under `tests/` and are out of scope. That leaves **5,600 in-scope edges** in 146 files: `src/` 5,365, `resources/` 93, `scripts/` 81, `site/` 41, `.php-cs-fixer.php` 9, `phpstan-baseline.neon.php` 7, `bin/` 4.
- Confidence: high 3,905, low 1,397, medium 291, unknown 7.
- call_type: method 4,380, direct 901, constructor 312, callback 7.
- Joint split: high/method 3,748; low/direct 893; low/method 504; medium/constructor 163; high/constructor 149; medium/method 128; high/direct 8; unknown/callback 7.

The `measured_accuracy` field was ignored. I read no earlier report for this repo and no helper script with another prefix.

## Method
- **Sample.** Seed `20261113`. Quotas: high 28, low 12, medium 5, unknown 5 (every unknown edge sits in one file, TokenExchangeVisitor.php). The sample covers 27 files. Each edge was opened at its line and judged for call, caller, callee, tier, call_type and line.
- **Census.** I built a regex index of every class, interface, trait and enum in the scanned tree (1,462 types, with parents, interfaces, traits, methods, method return types and typed or promoted properties). Scripts check every in-scope edge against it:
  - callee defined on the named type or a scanned ancestor;
  - `$this`/`self`/`static` calls hit the nearest definition (2,231 ok);
  - typed-parameter and typed-property receivers resolve to the nearest definition (1,036 ok);
  - `Cls::m()` resolution (73 ok);
  - global class names are imported (192 ok);
  - caller equals the innermost enclosing named function (5,345 ok) or the file module (255 ok);
  - the callee name appears on the reported line (all but 7 callbacks, which are correct);
  - every high callee is in `nodes` (0 missing).
- **Recall.** I listed every call in 3 functions and compared them with the tool's edges.

Helper scripts are `fanout/h-pdepend_r7_*.py`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/Source/Language/PHP/PHPBuilder.php:462 | `->setCache($this->cache)` (receiver `buildAstNodeInstance(...)`, declared `: ASTNode`) | PHPBuilder#buildAnonymousClass → `PDepend.Source.AST.ASTNode#setCache`, medium, method | `ASTNode` (a scanned interface with no external base) declares no `setCache`, so this ID is invented (C2). A guess `.setCache`, low | wrong callee / wrong confidence | Member ID invented on a scanned type that lacks it |
| src/Source/Language/PHP/PHPBuilder.php:613 | `->setContext($this->context)` (receiver `$function->setCache(..)`, declared `: self` in AbstractASTCallable) | PHPBuilder#buildFunction → `PDepend.Source.AST.AbstractASTCallable#setContext`, medium, method | AbstractASTCallable defines no `setContext` (only ASTFunction does), so the ID is invented (C2) | wrong callee / wrong confidence | Same |
| src/Source/Language/PHP/AbstractPHPParser.php:636 | `switch ($this->tokenizer->peekAt($i++)) {` (`protected Tokenizer $tokenizer`) | AbstractPHPParser#isFollowedByStaticValueOrStaticArray → `PDepend.Source.Tokenizer.Tokenizer#peekAt`, medium, method | `Tokenizer` has no `peekAt`; only its sub-interface `FullTokenizer` does (narrowed by `instanceof` on line 630). Invented ID (C2) | wrong callee | Same |
| src/Source/AST/ASTArtifactList/PackageArtifactFilter.php:87 | `$namespace = $node->getNamespace()?->getImage();` (`ASTArtifact $node`, inside `instanceof AbstractASTClassOrInterface`) | PackageArtifactFilter#accept → `PDepend.Source.AST.ASTArtifact#getNamespace`, medium, method | `ASTArtifact` has no `getNamespace`, so the ID is invented (C2). The trailing `?->getImage()` has no edge | wrong callee + missed call | Same; nullsafe call dropped |
| src/Source/AST/ASTParameter.php:382 | `return $node instanceof ASTScalarType && $node->isNull();` | ASTParameter#isTypeAllowingNull → `PDepend.Source.AST.ASTNode#isNull`, medium, method | `ASTNode` has no `isNull`, so the ID is invented (C2) | wrong callee | Same |
| src/Source/Language/PHP/AbstractPHPParser.php:3687 | `$attribute = $this->builder->buildASTAttribute($start->image);` | AbstractPHPParser#parseAttributeExpression → `PDepend.Source.Language.PHP.PHPBuilder#buildASTAttribute`, medium, method | PHP method names are case-insensitive, so this calls the defined `PHPBuilder#buildAstAttribute`, high (C1: one definition, one ID) | wrong callee / wrong confidence | Method lookup is case-sensitive |
| src/Source/Builder/BuilderContext/GlobalBuilderContext.php:91 | `self::$builder->restoreFunction($function);` (`protected static Builder $builder;`) | GlobalBuilderContext#registerFunction → `.restoreFunction`, low, method | `PDepend.Source.Builder.Builder#restoreFunction`, high (decision A, typed field) | wrong callee / wrong confidence | Typed static property receiver not used |
| site/config.php:100 | `$parser->registerDirective(new ClassDirective());` (`$parser = new Parser($env);` at file scope) | site/config → `parser.registerDirective`, low, method | `Gregwar.RST.Parser#registerDirective`, medium (decision A, `= new T`) | wrong callee / wrong confidence | Open defect php/11 (top-level `new` binding) |
| scripts/build.php:13 | `$phar->buildFromDirectory($root, ...);` (`$phar = new Phar($archiveName);` at file scope) | scripts/build → `phar.buildFromDirectory`, low, method | `Phar#buildFromDirectory`, medium | wrong callee / wrong confidence | Open defect php/11 |
| site/config.php:52 | `parent::process($parser, $node, $variable, $data, $options);` (`class ClassDirective extends Directive`, Gregwar, outside scan) | ClassDirective#process → `parent.process`, low, method | Not `parent.process`: that output is open defect php/18 | wrong callee | Open defect php/18 |
| src/Util/ImageConvert.php:180 | `$fontSizes = array_map(intval(...), $fontSizes);` | ImageConvert#prepareSvg → `intval`, low, direct | No edge: first-class callable syntax passes a function reference and calls nothing | not a call | Open defect php/12 (first-class callable), function form |
| src/Report/Summary/Xml.php:213 (sample #29) | `if (count($this->fileSet) > 0) {` (inside `namespace PDepend\Report\Summary;`) | Xml#close → `count`, low, direct | Undecided (php/15) | spec gap | Namespaced unqualified builtin |
| src/Source/Language/PHP/PHPTokenizerInternal.php:202 (sample #30) | `if (!defined('T_MATCH')) {` (file scope, `namespace PDepend\Source\Language\PHP;`) | src/Source/Language/PHP/PHPTokenizerInternal → `defined`, low, direct | Undecided (php/15) | spec gap | Same |
| src/Source/Language/PHP/AbstractPHPParser.php:5316 (sample #31) | `if ($ellipsis && count($arguments->getChildren()) === 0) {` | AbstractPHPParser#parseArgumentList → `count`, low, direct | Undecided (php/15) | spec gap | Same |
| src/Source/Language/PHP/PHPTokenizerInternal.php:93 (sample #34) | `define('T_NAMESPACE', 42005);` | src/Source/Language/PHP/PHPTokenizerInternal → `define`, low, direct | Undecided (php/15) | spec gap | Same |
| src/Source/AST/ASTCompilationUnit.php:94 (sample #36) | `if ($fileName && str_starts_with($fileName, 'php://')) {` | ASTCompilationUnit#&lt;init&gt; → `str_starts_with`, low, direct | Undecided (php/15) | spec gap | Same |
| src/Input/ExcludePathFilter.php:150 (sample #39) | `$subPath = str_replace('\\', '/', $path);` | ExcludePathFilter#notRelative → `str_replace`, low, direct | Undecided (php/15) | spec gap | Same |
| src/Source/AST/AbstractASTType.php:363 (recall) | `$id = $method->getParent()?->getNamespacedName() . ':' . $method->getImage();` | (no edge for `getNamespacedName`) | `.getNamespacedName`, low, method (C4: an unresolved call is still emitted) | missed call | Nullsafe `?->` call dropped |

Every other sampled edge was verified correct:
- 28 high `$this->`/`Cls::`/typed-receiver edges, including inherited targets such as `AbstractASTVisitor#dispatch` and `AbstractASTNode#addChild` through `buildAstTryStatement(): ASTTryStatement`.
- Low guesses on DOM and Symfony library results and on foreach variables (`classXml.appendChild`, `.public`, `use2.hasExcludeFor`, `listener.endLogProcess`, `doc.createElement`).
- A non-namespaced `str_replace` in scripts/php-keywords.php.
- Medium external constructors and methods (`RuntimeException#<init>`, `RuntimeException#getPrevious` via `catch (RuntimeException $e)`, `DOMDocument#getElementById` via `new DOMDocument`).
- 5 `($this->callback)(...)` → `callback`, unknown, callback.

## Systematic patterns (scripted counts, by count)
1. **Invented member ID on a scanned type that does not define it (C2): 18 edges.** All are medium. The script (`h-pdepend_r7_defcheck.py`) flags a medium or high `T#m` where T is scanned, neither T nor any scanned ancestor declares `m`, and T has no ancestor outside the scan. By callee:
   - `ASTNode#addChild` ×3, `ASTNode#getType` ×2, `ASTArtifact#getNamespace` ×2, `ASTNode#isNull` ×2;
   - `ASTNode#isArray`, `#isScalar`, `#isFalse`, `#getImageWithoutNamespace`, `#setCache`;
   - `ASTType#getType`, `AbstractASTNode#acceptsMoreArguments`, `Tokenizer#peekAt`, `AbstractASTCallable#setContext`.

   Most sit beside an `instanceof` narrowing of the receiver. The tool names the declared, un-narrowed type and attaches a method that type lacks. I hand-checked PackageArtifactFilter:87, AbstractPHPParser:636, PHPBuilder:462/613, AbstractASTCallable:255 and ASTParameter:242.
2. **Top-level `$x = new T` receivers left as `x.m` low (open defect php/11): 10 edges.**
   - scripts/build.php `phar.*` ×5 (13, 14, 15, 28, 37);
   - site/config.php `parser.registerDirective` (100) and `env.getBaseHref` (104);
   - .php-cs-fixer.php `config.setRiskyAllowed` (11);
   - site/config.php `parser.getEnvironment` (113) and `parser.parseFile` (114). These two are in a closure that captures `$parser` with `use ($parser)`.
3. **Typed static property receiver not used: 5 edges.** In GlobalBuilderContext.php:91/102/113/124/133, `self::$builder->restoreX(...)` gives `.restoreX` low. The property is declared `protected static Builder $builder;`, so these should be `PDepend.Source.Builder.Builder#restoreX`, high. A grep finds no other `self::$`/`static::$` receivers in scope.
4. **`parent::m()` with the parent outside the scan becomes `parent.m` (open defect php/18): 3 edges.** All in site/config.php: lines 52, 70, 92.
5. **Method ID uses the call's spelling instead of the definition's (case-insensitive PHP lookup, C1): 1 edge.** AbstractPHPParser.php:3687 `PHPBuilder#buildASTAttribute`, medium. The definition is `PHPBuilder#buildAstAttribute`, high.
6. **First-class callable reported as a call (php/12 form): 1 edge.** ImageConvert.php:180 `intval(...)`.

These six patterns do not overlap: 38 wrong edges, so census precision = 1 − 38/5600 ≈ 99.32%.

## Missed-call patterns (recall)
| function | real calls | tool edges matched | missed |
|---|---|---|---|
| `PDepend.TextUI.Runner#run` (src/TextUI/Runner.php:255–329) | 29 | 29 | 0 |
| `PDepend.Source.AST.AbstractASTType#getTraitMethods` (src/Source/AST/AbstractASTType.php:345–398) | 14 | 13 | 1: `?->getNamespacedName()` at 363 |
| `PDepend.Engine#analyze` (src/Engine.php:340–372) | 12 | 12 | 0 |
| **Total** | **55** | **54** | **1** |

No reported edge in these functions is a non-call.

Repo-wide (`h-pdepend_r7_nullsafe.py`):
- **Nullsafe `?->` method calls get no edge: 17 calls**, 12 on call results and 5 on variables. In-scope `?->` calls total 18, and only 1 of them has a matching edge. Examples:
  - NodeCountAnalyzer.php:175/199/219/246/249 (×2);
  - DependencyAnalyzer.php:237, 295;
  - ASTNamespace.php:291, 292;
  - IdBuilder.php:100;
  - CloverReport.php:112;
  - Report/Summary/Xml.php:455;
  - Report/Dependencies/Xml.php:349.

  Plain `->` calls have no such miss: 3,466 found, 0 missed outside a commented-out block in CohesionAnalyzer.php:106–147, which correctly gets no edges.
- **`new $className(...)`: no edge, 2 sites** (StrategyFactory.php:110, PHPBuilder.php:2465). Listed under spec gaps because SPEC names no ID for a dynamic class.

## Spec gaps (counted separately, not wrong)
1. **Unqualified global builtins inside a namespace: 811 edges.** These are all low/direct edges in namespaced files: `count` 63, `sprintf` 41, `in_array` 35, `strtolower` 34, `define` 33, `defined` 32, and so on. None uses a leading `\` or `use function`. Example: `if (count($this->fileSet) > 0) {` in `namespace PDepend\Report\Summary;`. The open question (CAPABILITIES php/15, GOLDEN_AUTHOR_QUESTIONS): is the callee `count` or `PDepend.Report.Summary.count`, and is it low or medium? The other 82 low/direct builtin edges are in non-namespaced files (scripts/, site/, bin/, phpstan-baseline.neon.php). I judged those correct as low bare names.
2. **Receivers whose parameter has a union type of scanned classes: 19 edges.** Examples:
   - `private function calculateVarsi(ASTClass|ASTTrait $class): int` … `$class->getProperties()` → `class.getProperties`, low;
   - `ASTFieldDeclaration|ASTFormalParameter $declaration` → `declaration.isProtected`;
   - `Exception|Throwable $exception` → `exception.getMessage`.

   SPEC's decision A covers "a receiver whose type is given by a declaration" but does not say what a union declaration names: one edge per member, a common supertype, or a guess.
3. **Local bound to a typed property, not a call: 13 edges.** Example: `$engine = $this->engine;` (`Engine` typed property) then `$engine->setOptions(...)` → `engine.setOptions`, low. 12 edges are in Runner.php:258–321, plus `$useSymbolTable = $this->useSymbolTable;` at AbstractPHPParser.php:8768, used inside a `static fn`. The 2026-11-12 let-bound ruling types a local bound to a *call result*. Decision A types fields and locals with declarations. SPEC does not say whether an untyped local bound to a typed property read takes the property's type.
4. **Dynamic class instantiation: 2 sites, no edge.** `return new $className();` (StrategyFactory.php:110) and `return new $className($image);` (PHPBuilder.php:2465). SPEC's ID rules and C4 do not say what ID, if any, a constructor call on a class named by a variable gets.

The `instanceof`-narrowed receivers behind most of pattern 1 also raise an open question: should `$node instanceof ASTScalarType && $node->isNull()` name the narrowed type? The tool's output there is wrong either way under C2, so those edges are counted as wrong, not as gaps.
