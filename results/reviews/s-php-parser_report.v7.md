# s-php-parser (php) — blind call-graph review, round 7

precision 50/50; census ≈99.29% (25 wrong of 3516 in-scope); recall: 0 missed of 43 real calls; 0 non-calls

## Scope
Tool output: `final13-A/s-php-parser.v2.json`, 7119 edges, all `.php`. In scope (not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment): **3516 edges** in 109 files (`lib/` 3346, `test_old/` 60, `tools/` 53, `grammar/` 48, `.php-cs-fixer.dist.php` 9). `test_old/` is in scope because its segment is not named exactly `test`. 3603 edges under `test/` are out of scope.
- Confidence: high 1915, low 1313, medium 279, unknown 9.
- call_type: method 1934, constructor 928, direct 645, callback 9.
- Low edges: 705 are `self.m` guesses. They come from the generated parsers' reduce closures `static function ($self, $stackPos)`, where `$self` is an untyped parameter, so a low guess is correct. 441 are bare builtins.

Sample: seed `20261113`, `random.sample` per tier: high 24, low 16, medium 5, unknown 5. That covers 25 files. All 50 edges are correct on call, caller, callee, tier, call_type and line, or depend on a spec gap: 0 are wrong. Four of them (sample #31 `assert`, #36 `class_alias`, #38 `array_splice`, #47 `$fileFilter(...)`) fall under the spec gaps below, so they are not counted as wrong.

Recall functions: `resolveMacros` (grammar/phpyLang.php:54–131, 13 calls), `PhpParser.Lexer.Emulative#tokenize` (lib/PhpParser/Lexer/Emulative.php:70–107, 13 calls), `PhpParser.NodeTraverser#traverseArray` (lib/PhpParser/NodeTraverser.php:181–268, 17 calls). The tool reports all 43 calls with the right callee, tier and line. Closure bodies inside `preg_replace_callback` and `array_filter` fold correctly into the enclosing function, and `empty(...)` is correctly given no edge.

Helper scripts: `fanout/s-php-parser_r7_load.py`, `_sample.py`, `_index.py`, `_census_typeid.py`, `_census_toplevel.py`, `_census_line.py`, `_census_misc.py`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| test_old/run.php:151 | `$cloningTraverser->addVisitor(new PhpParser\NodeVisitor\CloningVisitor);` | test_old/run → cloningTraverser.addVisitor, low, method | → PhpParser.NodeTraverser#addVisitor, high, method (`$cloningTraverser = new PhpParser\NodeTraverser;` at file top level, l.150) | wrong callee | top-level `$x = new T` receiver not typed (open defect php/11-top-level-code) |
| tools/fuzzing/target.php:112 | `$stmts = $parser->parse($input);` | tools/fuzzing/target → parser.parse, low, method | → PhpParser.Parser.Php7#parse (inherited: PhpParser.ParserAbstract#parse), high | wrong callee | same; `$parser = new PhpParser\Parser\Php7($lexer);` l.26 |
| tools/fuzzing/generateCorpus.php:24 | `list($_name, $tests) = $testParser->parseTest($code, 2);` | → testParser.parseTest, low | → PhpParser.CodeTestParser#parseTest, high (class scanned in test/) | wrong callee | same |
| .php-cs-fixer.dist.php:11 | `return $config->setRiskyAllowed(true)` | .php-cs-fixer.dist → config.setRiskyAllowed, low | → PhpCsFixer.Config#setRiskyAllowed, medium (`$config = new PhpCsFixer\Config();`) | wrong callee | same |
| test_old/run.php:185 | `$origStmts = $parser->parse($origCode);` | test_old/run → parser.parse, low | → PhpParser.Parser#parse, high (`$parser = (new PhpParser\ParserFactory())->createForVersion(...)`, declared `: Parser`) | wrong callee | top-level local bound to a typed call result not typed. The tool types such locals inside functions (JsonDecoder.php:51, ParserAbstract.php:962), so this breaks C2 consistency |
| lib/PhpParser/NameContext.php:134 | `return FullyQualified::concat($this->namespace, $name, $name->getAttributes());` | PhpParser.NameContext#getResolvedName → PhpParser.Node.Name.FullyQualified#concat, medium, method | → PhpParser.Node.Name#concat, high | wrong callee + wrong confidence | static call of a member inherited from a scanned superclass (`class FullyQualified extends \PhpParser\Node\Name`; `concat` defined only in Name.php:226) is named on the subclass. The ID is invented (C2) and listed in `nodes`. `Name::concat` at NameResolver.php:218/302 is correctly `PhpParser.Node.Name#concat` high |
| lib/PhpParser/Internal/PrintableNewAnonClassNode.php:55 (sample #31) | `assert($class instanceof Node\Stmt\Class_);` | → assert, low, direct | undecided (php/15) | spec gap | unqualified builtin inside `namespace PhpParser\Internal;` |
| lib/PhpParser/Node/UseItem.php:55 (sample #36) | `class_alias(UseItem::class, Stmt\UseUse::class);` | lib/PhpParser/Node/UseItem → class_alias, low, direct | caller correct; callee undecided (php/15) | spec gap | same |
| lib/PhpParser/Lexer/TokenEmulator/AsymmetricVisibilityTokenEmulator.php:57 (sample #38) | `array_splice($tokens, $i, 1, [` | → array_splice, low, direct | undecided (php/15) | spec gap | same |
| test_old/run.php:163 (sample #47) | `if (!$fileFilter($file)) {` | test_old/run → fileFilter, unknown, callback | undecided | spec gap | file-level variable bound to a closure in two `switch` branches |
| lib/PhpParser/Builder/Class_.php:118 | `throw new \LogicException(sprintf('Unexpected node of type "%s"', $stmt->getType()));` | → stmt.getType, low, method | undecided | spec gap | untyped parameter reassigned from a call declared `: Node` |
| lib/PhpParser/Lexer.php:31 | `$tokens = @Token::tokenize($code);` | → PhpParser.Token#tokenize, medium, method | undecided | spec gap | conditionally declared superclass `TokenPolyfill` |
| tools/fuzzing/target.php:29 | `$visitor = new class extends PhpParser\NodeVisitorAbstract {` | (no edge) | PhpParser.NodeVisitorAbstract#<init>, high, constructor | missed call | anonymous subclass of a class gets no constructor edge (open defect php/13-anonymous-class) |

## Systematic patterns (wrong), by scripted count
1. **Top-level receivers typed by `$x = new T` (or `$x = (new T)->f()`) stay `x.m` low: 21 edges.** Script: `s-php-parser_r7_census_toplevel.py`. It selects edges whose caller is the file's module ID, whose callee is a low `v.m`, and where the file binds `$v` at column 0 to `new <Name>` or `(new <Name>)->…`.
   - Files: test_old/run.php 9 (cloningTraverser ×2, prettyPrinter ×2, nodeDumper ×2, parser ×3); tools/fuzzing/target.php 10 (traverser ×3, parser ×4, prettyPrinter ×1, nodeDumper ×2; the uses inside the `$fuzzer->setTarget(function … use($parser, …))` closure fold into the file); tools/fuzzing/generateCorpus.php 1; .php-cs-fixer.dist.php 1.
   - 18 of these match open defect php/11-top-level-code. 3 (`$parser` in test_old/run.php) are bound to a call result with declared return type `Parser`.
   - Hand-checked: test_old/run.php:151, :185, :217; target.php:112, :129; generateCorpus.php:24; .php-cs-fixer.dist.php:11.
2. **Static call of a method inherited from a scanned superclass named on the subclass: 4 edges.** `FullyQualified::concat` at NameContext.php:134, :237 and NameResolver.php:272, :292. Each gives `PhpParser.Node.Name.FullyQualified#concat` medium where `PhpParser.Node.Name#concat` high is correct.
   - Script: `s-php-parser_r7_census_typeid.py`. It builds a class/parent/method index of the scan and flags every `T#m` callee whose defining scanned class differs from T. The only other hit is `Token#tokenize`, a spec gap (see below).
   - The same script found 0 invented IDs elsewhere, 0 high edges to unscanned types, 0 constructors with the wrong tier, and 0 high callees missing from `nodes`.

Wrong union: 25 edges. Census precision = 1 − 25/3516 ≈ **99.29%**.

Other checks found nothing wrong:
- Line: 14 edges lack the callee name on their line. All of them are `new self` / `new static` → `Type#<init>` on the right line.
- Language constructs reported as calls: 0.
- Medium versus low for builtins is consistent: `\fn(` and `use function fn;` give medium (177), and a bare `fn(` gives low (441).
- `parent::m()` and `parent::__construct()` resolve correctly (7 edges).
- The 78 high/medium `$this->prop->m()` edges follow the declared property types (10 spot-checked).

## Missed-call patterns (recall)
- No call was missed in the 3 recall functions (0 of 43).
- Found by looking:
  - Anonymous subclass `new class extends PhpParser\NodeVisitorAbstract { … }` gets no `PhpParser.NodeVisitorAbstract#<init>` constructor edge: 1 site (tools/fuzzing/target.php:29). This is open defect php/13.
  - Dynamic method or class names get no edge at all: 4 sites. These are `$this->{'p' . $node->getType()}(...)` at PrettyPrinterAbstract.php:589 and :610, `$this->$printFn($subNode)` at :684, and `new $className(` at JsonDecoder.php:78. The spec gap is listed below.

## Spec gaps (counted separately, not wrong)
1. **Unqualified builtin inside a namespace: 369 edges.** Example: `assert($class instanceof Node\Stmt\Class_);` in `namespace PhpParser\Internal;`. All are in `lib/`, low, direct, bare name. Open question (CAPABILITIES php/15-namespaced-builtin): is the callee the global fallback `assert` or the namespace-qualified `PhpParser.Internal.assert`, and is it low or medium? The 72 bare builtins in files without a namespace are low per the tiers and are not counted here.
2. **Untyped parameter reassigned from a call with a declared return type: 5 edges.** Example: `public function addStmt($stmt) { $stmt = BuilderHelpers::normalizeNode($stmt); … $stmt->getType()` with `normalizeNode($node): Node`. Edges: Builder/Class_.php:118, Enum_.php:84, FunctionLike.php:38, Interface_.php:63, Trait_.php:51, all `stmt.getType` / `param.getType` low. Open question: PHP has no local declarations. Does the let-bound call-result rule (2026-11-12) type a variable whose first binding is an untyped parameter, given "a local's static type is fixed at its declaration"?
3. **File-level variable bound to a closure, in two branches: 2 edges.** In test_old/run.php, `$fileFilter = function($path) {…}` (l.68 and l.91, in separate `switch` cases), then `$fileFilter($file)` (l.163), and the same for `$codeExtractor` (l.171). Tool: `fileFilter` / `codeExtractor`, unknown, callback. Open question: the named-nested-function rule covers "a local bound directly to a function literal (a PHP `$f = function`)". Does it cover a file-scope PHP variable, which is a global, and does that hold when it is bound to two different literals?
4. **Receiver typed by an anonymous class: 2 edges.** tools/fuzzing/target.php:115 and :127, `$visitor->setTokens(...)` with `$visitor = new class extends PhpParser\NodeVisitorAbstract { … public function setTokens(...) … }`. Tool: `visitor.setTokens` low. Open question: anonymous-class members fold into the enclosing function, so they have no ID of their own. What is the callee of a call on an instance of an anonymous class: a low guess, the folded caller, or the named base class?
5. **Conditionally declared superclass: 1 edge.** lib/PhpParser/Lexer.php:31, `$tokens = @Token::tokenize($code);`. `class Token extends Internal\TokenPolyfill`, and TokenPolyfill.php declares `class TokenPolyfill extends \PhpToken {}` under `if (\PHP_VERSION_ID >= 80000) { … return; }`, otherwise a polyfill class defining `tokenize`. Tool: `PhpParser.Token#tokenize` medium. Open question: when a scanned class has two conditional declarations, one of which defines `m` and one inheriting it from an external base, is the callee `PhpParser.Internal.TokenPolyfill#tokenize` (high) or `PhpParser.Token#tokenize` (medium, external base)?
6. **Dynamic member and class names: 4 sites, no edge emitted (recall side).** The sites are `$this->{'p' . $node->getType()}($node, …)`, `$this->$printFn($subNode)` and `new $className(`. Open question: C4 requires unresolved calls to be kept as low guesses, but SPEC gives no ID form for a call whose member or class name is an expression or variable. Is that form `.member`, the variable name as a callback, or no edge?
