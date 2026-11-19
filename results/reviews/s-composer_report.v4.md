# Blind call-graph review: s-composer (php), round 4

precision 48/50; census ≈98.86% (210 wrong of 18407 in-scope); recall: 0 missed of 39 real calls; 0 non-calls

## Scope
Tool output `<scans>/final12-A/s-composer.v2.json` has 38078 edges, all from `.php` files. Edges under a `tests/` segment are out of scope, which leaves **18407 in-scope edges** in 264 files (`src/` 18391, `.php-cs-fixer.php` 16). The JSON's `measured_accuracy` field was ignored.
- By confidence: low 8421, high 6936, medium 2999, unknown 51.
- By call_type: method 11310, direct 5093, constructor 1953, callback 51.
- By tier and type: high method 5817, high constructor 1063, high direct 56; medium method 1784, medium constructor 890, medium direct 325; low direct 4712, low method 3709; unknown callback 51.

The precision sample has 50 edges: low 21, high 17, medium 7, unknown 5. Seed 20261113 (`random.seed`, `random.sample` per tier), 37 files. Of the 48 not-wrong edges, 31 are correct and 17 are spec gaps (G1 ×14, G2 ×2, G3 ×1). The 2 wrong edges are #1 and #46.

Helper scripts are `fanout/s-composer_r4_*.py`. The type index (`s-composer_r4_index.py`) reads native PHP declarations only: return types, typed properties, parameters, `extends`/`implements`/`use` traits. PHPDoc is not read (see G2).

Checks that found no defect:
- Every high callee is in `nodes` and names the class that defines the method.
- Every constructor ID matches the `new X` class resolved through the file's `use` imports.
- No medium `T#m` names a method that the scan defines.
- Every edge's line holds `name(`, so multi-line chains report each call on its own line.
- No edges come from comment lines.
- No language constructs (`isset`, `empty`, `unset`, `exit`) are emitted.
- File-level callers use the file path (`src/bootstrap`, `.php-cs-fixer`).
- There is no `new class` and no first-class-callable `(...)` syntax in scope, so open defects php/12 and php/13 do not occur.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/Composer/DependencyResolver/PoolOptimizer.php:359 (sample #1) | `$versions[$groupPackage->getVersion()] = $groupPackage->getPrettyVersion();` with `$groupPackage = $pool->packageById($packageId);` (`packageById(int $id): BasePackage`, `Pool $pool`) | PoolOptimizer#getGroupVersions → `groupPackage.getVersion`, low, method | `Composer.Package.PackageInterface#getVersion`, high, method. The let-bound rule applies, and a later `$groupPackage = $groupPackage->getAliasOf();` does not untype it. | wrong callee | Local reassigned later loses its call-result type (W3) |
| src/Composer/Json/JsonManipulator.php:153 (sample #46) | `return strnatcmp($prefix($a), $prefix($b));` inside `uksort(..., static function ($a, $b) use ($prefix)`, with `$prefix = static function ($requirement): string {` at :128 | JsonManipulator#sortPackages → `prefix`, unknown, callback | `Composer.Json.JsonManipulator#sortPackages.prefix`, high, direct (named nested function) | wrong callee | A nested function called through a `use`-captured variable inside another closure is treated as a value (W1) |
| src/Composer/Command/InstallCommand.php:140 | `->setClassMapAuthoritative($authoritative)` (9th link of `$install->setDryRun(...)->...`; every setter is declared `: self`) | InstallCommand#execute → `.setClassMapAuthoritative`, low, method | `Composer.Installer#setClassMapAuthoritative`, high, method. Links 1–8 (:132–:139) are resolved high. | wrong callee | Typed fluent chain stops resolving after 8 links (W3) |
| src/Composer/Command/ShowCommand.php:964 | `$package->getReleaseDate()->format('Y-m-d')`, with `CompletePackageInterface $package` and `getReleaseDate(): ?\DateTimeInterface` | ShowCommand#printMeta → `.format`, low, method | `DateTimeInterface#format`, medium, method (typed call result; open defect php/06) | wrong callee | Parameterless call result with a declared return type stays `.m` (W3) |
| src/Composer/Command/AuditCommand.php:93 | `$policyConfig = $policyConfig->withIgnoreSeverity(array_values($ignoreSeverities));` (first binding `= $this->createPolicyConfig(...)`, which returns `PolicyConfig`) | AuditCommand#execute → `policyConfig.withIgnoreSeverity`, low | `Composer.Policy.PolicyConfig#withIgnoreSeverity`, high | wrong callee | Self-reassigned local is untyped (W3) |
| src/Composer/Util/HttpDownloader.php:282 | `$promise = $promise->then(function ($response) use (&$job) {` after `$promise = new Promise($resolver, $canceler);` | HttpDownloader#addJob → `promise.then`, low | `React.Promise.Promise#then`, medium (`= new T`) | wrong callee | Same as above (W3) |
| src/Composer/Advisory/Auditor.php:299 | `return $pkg instanceof CompletePackageInterface && $pkg->isAbandoned() && …` | Auditor#filterAbandonedPackages → `Composer.Package.PackageInterface#isAbandoned`, medium | Not this ID. `PackageInterface` (in scan, no external ancestor) declares no `isAbandoned`, so C2 forbids the ID. The runtime target is `CompletePackageInterface#isAbandoned`; SPEC does not decide `instanceof` narrowing. | wrong callee (C2) | Invented member ID on a closed scanned type (W2) |
| src/Composer/Compiler.php:158 | `$file->getFilename()` in `foreach ($finder as $file)`; earlier `$file = new JsonFile($localConfig);` at :73 | Compiler#compile → `Composer.Json.JsonFile#getFilename`, medium | Not this ID: `JsonFile` has no `getFilename` and no parent (C2) | wrong callee (C2) | Invented member ID (W2) |
| src/Composer/Command/InitCommand.php:59 | `new InputOption('require', …, $this->suggestAvailablePackageInclPlatform())` | InitCommand#configure → `Composer.Command.InitCommand#suggestAvailablePackageInclPlatform`, medium | `Composer.Command.CompletionTrait#suggestAvailablePackageInclPlatform`, high | wrong callee / confidence | Open defect php/17: trait methods are named on the using class at medium (W4) |
| src/Composer/Command/BaseCommand.php:103 | `$application = parent::getApplication();` (parent is Symfony `Command`, not in scan) | BaseCommand#requireComposer → `parent.getApplication`, low | Not `parent.m`. The spec gives `.getApplication` (computed `super`) or `Composer.Command.BaseCommand#getApplication` medium (inherited from an outside base). | wrong callee | Open defect php/18 (W5) |
| src/Composer/Downloader/FileDownloader.php:253 | `return $reject($e);` in `$accept = function (Response $response) use (…, &$reject, …)`, with `$reject = function ($e) use (…)` at :266 | FileDownloader#download.accept → `reject`, unknown, callback | `Composer.Downloader.FileDownloader#download.reject`, high, direct | wrong callee | W1 |
| src/Composer/Autoload/AutoloadGenerator.php:1415 (sample #2; also #4, 5, 7–10, 12, 14, 16, 18–21) | `return array_filter(` (file is in `namespace Composer\Autoload;`) | → `array_filter`, low, direct | undecided | spec gap G1 | Unqualified global builtin inside a namespace |
| src/Composer/Command/ShowCommand.php:190 (sample #13) | `$io->writeError(...)` with `$io = $this->getIO();`, where `getIO()` has only `@return IOInterface` | → `io.writeError`, low | undecided | spec gap G2 | PHPDoc-only type |
| src/Composer/Util/ProcessExecutor.php:158 (sample #17) | `$this->io->writeError(` with `/** @var ?IOInterface */ protected $io;` | → `io.writeError`, low | undecided | spec gap G2 | PHPDoc-only property type |
| src/Composer/Util/Forgejo.php:97 (sample #6) | `$authConfigSource->addConfigSetting(...)` with `$authConfigSource = $storeInLocalAuthConfig && $localAuthConfig !== null ? $localAuthConfig : $this->config->getAuthConfigSource();` | → `authConfigSource.addConfigSetting`, low | undecided | spec gap G3 | Conditional initializer |

The other sample edges are correct. High #22–#38: typed parameters, `= new T`, call results and chains typed by native return types, inherited methods named on their defining class, and `TransportException#<init>`. Medium #39–#45: `\React\Promise\resolve`, external `Table#render`, `\RuntimeException#<init>`, the leading-backslash `\count`/`\is_array`, and `ConstraintInterface#getLowerBound` through a local bound to a scanned `parseConstraints(): ConstraintInterface`. Unknown #47–#50: parameters or locals holding callables. Low #3, #11, #15: `$this->setName(...)->setAliases(...)` with an out-of-scan return type, a foreach over an array, and `getLowerBound()->getVersion()` with an out-of-scan `Bound`.

## Systematic patterns (scripted counts; union 210, no overlaps)
1. **W2: invented member IDs on closed scanned types (C2): 96 edges, all medium.** A `T#m` where `T` and all its ancestors are in the scan and none defines or declares `m`. Almost all sit under an `instanceof` guard that narrows to a subtype. The largest groups:
   - `BasePackage#getAliasOf` 16
   - `PackageInterface#isAbandoned`, `#getReplacementPackage`, `#getAliasOf` 4 each
   - `PlatformRequirementFilterInterface#filterConstraint` 4 (declared only on `IgnoreListPlatformRequirementFilter`)
   - `Event#isDevMode` 3 (`/** @var InstallerEvent $event */`)
   - `JsonFile#getFilename`/`#getRealPath` 3 (a `SplFileInfo` loop variable)

   Script: `s-composer_r4_invented.py`. Hand-checked: Auditor:299, Compiler:156/158, RuleSetGenerator:198, EventDispatcher:266, BasePackage:182.
2. **W3: typed receivers left as guesses: 49 low edges** (`s-composer_r4_chain3.py`, filtered in `s-composer_r4_union.py`):
   - 37: fluent `Installer` chains past the 8th link (InstallCommand 7, UpdateCommand 14, RequireCommand 9, RemoveCommand 5, CreateProjectCommand 2). All setters are declared `: self`.
   - 9: locals reassigned later lose their first binding's type. AutoloadGenerator:191 `$installedJson->read()` after `= new JsonFile`. ArchiveCommand:143. AuditCommand:93, :96. PoolOptimizer:359 ×2. ArchiveDownloader:195 (`extract(): PromiseInterface`). HttpDownloader:282 and ProcessExecutor:263 (`= new Promise`).
   - 3: call results with declared return types. ShowCommand:964 and :1167 `getReleaseDate()->format` (php/06). RequireCommand:241 `$this->getRepos()->findPackages` (`getRepos(): CompositeRepository` in a trait).
3. **W4: trait methods named on the using class at medium (open defect php/17): 31 edges.** Mostly `CompletionTrait#suggest*` called from command `configure()` methods.
4. **W1: a named nested function called through a `use`-captured variable is emitted as `name`, callback, unknown: 18 edges.** Files: AutoloadGenerator:1408; ArchiveDownloader:143, 152, 200; DownloadManager:221; FileDownloader:169, 171, 253, 298, 313; ZipDownloader:210; JsonManipulator:153 ×2; ComposerRepository:780, 839, 2045, 2050; PackageSorter:106. A direct call in the defining scope resolves correctly (`…#sortPackages.computeImportance` high at PackageSorter:120). Self-recursive closures (`use (&$add)`), sibling closures and inner anonymous closures all fail. Script: `s-composer_r4_cbcensus.py`, with every hit checked against its `$x = function` binding.
5. **W5: `parent::m()` with the parent outside the scan becomes `parent.m` (open defect php/18): 16 edges.** BaseCommand ×8, Application ×5, GlobalCommand, HtmlOutputFormatter, VersionParser.

## Missed-call patterns (recall)
The 3 recall functions are `PackageSorter::sortPackages` (src/Composer/Util/PackageSorter.php:74–139), `Pool::match` (src/Composer/DependencyResolver/Pool.php:271–309) and `Hg::runCommand` (src/Composer/Util/Hg.php:49–87).
- They make 39 real calls (10 + 15 + 14). All 39 have edges: 0 missed, 0 non-calls.
- One recall edge is wrong: PackageSorter:106 `$computeImportance($user)` → `computeImportance` callback, which is W1.
- The census found no missed-call pattern.

## Spec gaps (counted separately, not wrong)
- **G1: unqualified global builtins inside a namespace: 4712 edges (all low direct).** Example: `if (str_starts_with($vendorPath, $resolvedDir.'/')) {` in `namespace Composer\Autoload;` is emitted as `str_starts_with`, low, direct. SPEC leaves two questions open (CAPABILITIES `php/15-namespaced-builtin`): is the callee the runtime fallback `str_starts_with` or the namespaced `Composer.Autoload.str_starts_with`, and is it low (a bare name not in the scan) or medium (a statically named library function)?
- **G2: PHPDoc-only types: at least 1240 edges.** That many `$this->prop->m()` low edges have a same-file `/** @var Class */` property; `@return`-only methods such as `getIO()` add more. Example: `/** @var ProcessExecutor */ protected $process;` with `$this->process->execute(...)` gives `process.execute`, low. Question: does a PHPDoc `@var`/`@return` type count as a "declaration" for decision A and for typed call results? (For JS, SPEC says only that a JSDoc `@type` is not evidence of a function binding.)
- **G3: conditional and chained-assignment initializers: 53 edges by script, plus sample #6.**
  - Application.php ×31: `$io = $this->io = new ConsoleIO($input, $output, new HelperSet([`
  - Factory.php ×17: `$composer = $fullLoad ? new Composer() : new PartialComposer();`
  - ZipDownloader.php ×5: `$zipArchive = $this->zipArchiveObject ?: new ZipArchive();`
  - Forgejo.php:97: a ternary of two typed values

  Question: does a local bound to a ternary, `?:` or `??` whose branches have types, or to a chained assignment whose final value is `new T`, take a type?
- **G4: variables that are parameters, foreach variables or clones and are re-bound to a typed value: 52 edges.**
  - ShowCommand ×37: `$package = clone $this->requireComposer()->getPackage();`, then `foreach (… as $package)` in the same method
  - ConsoleIO ×6: untyped parameter `$question` re-bound by `$question = new Question(...)`
  - VersionSelector ×3, ArrayRepository ×2, InstalledRepository ×2: parameters re-bound from calls
  - BufferIO:31: `string $input` re-bound by `$input = new StringInput($input)`
  - Installer:946: a foreach variable

  Question: for a PHP variable, which binding is "the declaration" that fixes its type under the let-bound rule? Is it the parameter or foreach binding, or the first `= new T` / `= f()`? Does `clone expr` carry the type of `expr`?
- **G5: `$this->m()` inside a trait that does not declare `m`: 15 edges.** Example: `RepositoryFactory::defaultReposWithDefaultManager($this->getIO())` in `trait PackageDiscoveryTrait` gives `Composer.Command.PackageDiscoveryTrait#getIO`, medium. Question: what is the callee ID and tier for a `$this` call in a trait body, where the method comes from whichever class uses the trait?
- **Related to W2 (the 96 edges are counted wrong only under C2):** `$pkg instanceof CompletePackageInterface && $pkg->isAbandoned()`. Question: does an `instanceof` guard (or a `/** @var Sub $x */` cast) narrow the receiver's type, so that the callee is `CompletePackageInterface#isAbandoned`, or does the receiver keep its declared type? The emitted ID violates C2 either way.
