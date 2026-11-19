# hadolint (haskell) call-graph review, v4

**Summary:** precision 48/50; census ≈99.5% (10 wrong of 2038 in-scope); recall: 1 missed of 63 real calls; 0 non-calls

## Scope and sample

- **Scope.** The output has 4591 edges in total. 2038 are in-scope: `.hs` files under `src/` and `app/`, with `test/` excluded.
  - By confidence: high 945, medium 979, low 102, unknown 12.
  - By call type: direct 2026, callback 12.
  - The tier and type counts are identical to v3.
- **Sample.** I used `random.seed(20261028)` and drew 20 high, 20 medium, 5 low and 5 unknown edges, with at most 2 per file per tier. The sample covers 31 files. Scripts are in the fanout folder:
  - `hadolint_v4_load.py`
  - `hadolint_v4_sample.py`
  - `hadolint_v4_edges.py`
  - `hadolint_v4_census.py`
  - `hadolint_v4_lowcheck.py`
  - `hadolint_v4_infix.py`
- **Recall functions.** I checked 3 functions:
  - `Hadolint.Rule.DL3026.rule` with its where/let bindings
  - `Hadolint.Rule.DL3042.dl3042`
  - `Hadolint.Process.run`

### Sampled edges (48 correct, 2 wrong)

- **High (20/20):** all correct. They include:
  - module-level functions such as `simpleRule`, `Shell.cmdHasArgs`, `Shell.noCommands`, `Hadolint.Rule.modify` and `replaceWith`
  - sibling where bindings, for example `dl3046.forgotFlagL → dl3046.isUseradd` and `scrule.check → scrule.getFailures`
  - the in-scan record field `partialFormats` (Configuration:69) and the recursion `Shell.simplify` (Shell:236)
- **Medium (20/20):** all correct:
  - qualified imports: `Set.null`, `Map.lookup`, `Megaparsec.takeWhile1P`, `ShellCheck.Interface.pcComment`
  - Prelude: `dropWhile`, `not`, `fmap`, `all`, `return`, `filter`, `putStrLn`, `mconcat`
  - listed imports: `Control.Monad.Writer.tell`, `Text.Megaparsec.Pos.sourceName`, `Data.Text.drop`
  - the one unlisted external import: DL3033:175 `Language.Docker.Syntax.imageName`
  - Commandline `strOption` / `long`, which is the two-open-imports spec gap
- **Low (3/5).**
  - Correct: Format:71 `typeMismatch`, Configuration:83 `nest` and Checkstyle:86 `toList`. These are bare names in files with 3 or more open, unlisted external imports (the spec gap below).
  - Wrong: Format:134 `reachOffset` and embedded:45 `js_document_getElementById` (see the table).
- **Unknown (5/5):** all correct. These are callbacks on parameters:
  - Shell:172 `extractor`
  - Rule:231 `applyRule`
  - Rule:177 `f`
  - Configuration:127 `prnt`
  - Format:70 `f`

### Recall

- **DL3026.rule:** 0 missed of 37.
  - Every call is present on the correct line with the correct where/let caller: `.check`, `.check.newState`, `.check.img`, `.checkMount`, `.checkMount.img`, `.doCheck`, `.isAllowed`, `.isRegistryAllowed`.
  - The 3 `fromString` edges are present but have the wrong callee (pattern 2).
  - The `CheckFailure {..}` constructions and the `Just . ImageAlias . imageName` composition are correctly not reported.
- **DL3042.dl3042:** 0 missed of 13. This covers `customRule`, `emptyState`, `modify` x2, `rememberStage`, `registerEnv`, `state`, `Map.lookup`, `foldArguments` x2, `Shell.noCommands`, `Utils.hasCacheOrTmpfsMountWith` and `addFail`.
- **Process.run:** 1 missed of 13. The backtick-infix `` `Set.member` `` on line 106 has no edge.
  - The where/let callers are correct: `run.shouldKeep`, `run.ignores`, `run.stageIgnores` and `run.stageIgnores.ls`.
  - The `globalIgnores` CAF reference is not reported. This is a spec gap.
- **Total:** 1 missed of 63.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/Hadolint/Formatter/Format.hs:134 (sample) | `let (_, posState) = reachOffset (errorOffset (NE.head e)) s` | `Hadolint.Formatter.Format.errorPosition → reachOffset`, low, direct | `→ Text.Megaparsec.reachOffset`, medium. It comes in through the import list `import Text.Megaparsec (TraversableStream (..), pstateSourcePos)` | wrong callee / wrong confidence | class methods brought in by `Class (..)` are not resolved through the import list |
| app/embedded.hs:45 (sample) | `lintInput <- js_document_getElementById (toJSString "lint")` | `embedded.setup → js_document_getElementById`, low, direct | `→ embedded.js_document_getElementById`, high. It is declared at embedded.hs:25-26: `foreign import javascript unsafe "document.getElementById($1)"` / `js_document_getElementById :: JSString -> IO JSVal` | wrong callee / wrong confidence | `foreign import` declarations are not indexed as module top-level functions |
| src/Hadolint/Rule/DL3026.hs:23, :34, :37 (recall) | `let img = fromString ( Data.Text.unpack src )` | `rule.check.img` / `rule.checkMount.img` → `Language.Docker.Syntax.fromString`, medium | `→ Data.String.fromString`, medium. It comes in through `import Data.String ( IsString(..) )`, and import lists take precedence over the unlisted external import | wrong callee | same root cause as Format.hs:134 |
| src/Hadolint/Process.hs:106 (recall) | ``code `Set.member` Set.unions [ ignores line, stageIgnores line, globalIgnores ]`` | (no edge) | `Hadolint.Process.run.shouldKeep → Set.member`, medium, direct | missed call | backtick-infix applications are never reported |
| src/Hadolint/Shell.hs:309 (sample line, outside the sampled edge) | ``&& ["-m", "pip", "install"] `isInfixOf` getArgs cmd`` | only `→ Hadolint.Shell.getArgs` | an extra `Hadolint.Shell.isPipInstall.isPythonPipInstall → Data.List.isInfixOf`, medium | missed call | same as the row above |
| src/Hadolint/Rule.hs:133 (sample) | `instance Yaml.FromYAML LabelType where` / `parseYAML = withLabelType pure` | caller `Hadolint.Rule.Yaml.FromYAML.LabelType.parseYAML` | The spec says `Module.Class.Type.m` but does not say whether a qualified class name (`Yaml.FromYAML`) keeps its qualifier. Unqualified instances drop it (`...Sarif.ToJSON.SarifFormat.toJSON`). | spec gap | not counted |
| src/Hadolint/Process.hs:122 (recall) | `globalIgnores = globalIgnored` / used on :106 | (no edge for `globalIgnores`) | A zero-arity where binding (CAF) used as a value. The spec does not say whether this is a call. | spec gap | not counted |
| src/Hadolint/Config/Commandline.hs:170 (sample) | `( strOption` | `→ Options.Applicative.strOption`, medium | The file has two open, unlisted external imports (`Control.Applicative`, `Options.Applicative`). The spec's "the one unlisted external import" rule does not cover two. | spec gap | not counted |

## Systematic patterns (by census count)

1. **Backtick-infix function applications are never reported (missed calls, not wrong edges).**
   - Script `hadolint_v4_infix.py` found 115 full infix uses (`` a `f` b ``) in `src/` and `app/`, after removing string literals, string continuation lines, comments, constructors and the `` a `compare` b = `` instance head.
   - None has an edge for that name on its line.
   - Top names: `Text.isInfixOf` 34, `Text.isPrefixOf` 24, `elem` 20, `notElem` 9, `Text.isSuffixOf` 9, `isInfixOf` 6, `Set.member` 3, `isPrefixOf` 3, `isSuffixOf` 2, `compare` 1, plus 5 others with 1 each.
   - The spec already treats `f $ x` and `x & f` as calls of f, so a two-argument infix application is a call. These misses do not enter the census numerator, because census counts wrong edges.
   - There are also 22 operator sections (`` (`f` x) ``). Those are a spec gap, see below.
2. **Bare names that should resolve as top-level functions declared by `foreign import`: 6 edges, all in app/embedded.hs.** All are bare, low and direct:
   - `js_document_getElementById` at :45 and :49
   - `asEventListener` at :46
   - `js_addEventListener` at :47
   - `js_setText` at :50
   - `js_document_getElementValue` at :55

   All five names are declared in the same file (lines 25-39). The census counted every edge whose callee is one of the 5 FFI names.
3. **Class methods imported through `Class (..)` are not resolved through the import list: 4 edges.**
   - Format.hs:134 `reachOffset` is bare and low.
   - DL3026.hs:23/34/37 `fromString` resolves to `Language.Docker.Syntax.fromString` when it should be `Data.String.fromString`.
   - The census covered every in-scope use of the class methods imported this way: `IsString (..)` in Rule.hs and DL3026, and `TraversableStream (..)` in Format.hs. Rule.hs:81 is the instance definition, not a call. Commandline.hs:215 passes `fromString` as a value.
   - Record fields imported through `T (..)` still resolve correctly.

Census: wrong edges = 6 + 4 = 10 of 2038. Census precision = 1 − 10/2038 ≈ 99.5%.

## Spec gaps (not counted as wrong)

- **Several open external imports give low (spec gap).** There are 102 low edges in total. 96 of them are bare names in files that have 2 or more open, unlisted external imports. The other 6 are the FFI edges above.
  - By name: `object` 33, `pretty` 10, `lookupEnv` 7, `encode` 6, `toJSString` 5, `nest` 5, `errorBundlePretty` 4, `toList` 4, `formatWith` 4, `parseErrorTextPretty` 3, and others.
  - Every file with low edges has 2 to 4 such imports (checked by `hadolint_v4_lowcheck.py`).
  - The same situation in Commandline.hs gives medium edges named after the real defining module instead: `Options.Applicative.*` 79 and `Control.Applicative.many` / `optional` 18. Main.hs has 4 `Options.Applicative.*` medium edges. The two behaviours differ, and the spec does not decide between them.
- **Callers of instances with a qualified class keep the qualifier.** 18 edges have callers such as `Hadolint.Config.Configuration.Yaml.FromYAML.PartialConfiguration.parseYAML` (8) and `....Yaml.FromYAML.OverrideConfig.parseYAML` (4). The spec's `Module.Class.Type.m` does not say whether the class is qualified as written.
- **Operator sections.** There are 22 sections such as `` (`varInText` package) `` and `` ( `renderResult` maybeFilepath ) ``. A partially applied infix passed as a value: the spec does not say whether this is a call.
- **CAF / zero-arity bindings used as values** (Process:106 `globalIgnores`, Shellcheck:78 `getList`). They are not reported, and the spec does not say whether they are calls.
- **Functions inside `.` compositions** are not reported, for example `not . checkMount st` (DL3026:28) and `(> 5) . Text.length` (DL3046:28). The spec does not cover composition. The tool is consistent about it.

## Previous findings

This output is unchanged from the v3 output: the same 4591 / 2038 totals and identical tier and call-type counts.

| v3 item | status | evidence (v4 counts) |
|---|---|---|
| Table rows Lint.hs:81 / :87: backtick `elem` / `notElem` missed. Pattern 1: backtick infix never reported (116 full + 22 sections) | **still present** | 115 full infix uses, 0 with an edge. The v3 figure of 116 included the `` a `compare` b = `` definition head. There are 22 sections (spec gap). A new instance turned up in recall: Process:106 `Set.member`. |
| Table rows Format.hs:134 `reachOffset` and DL3026.hs:23/34/37 `fromString`. Pattern 2: `Class (..)` methods not resolved (4 edges) | **still present** (4 of 4) | The same 4 edges with the same callees and confidences. Format:134 fell in this sample. DL3026 showed up in recall. |
| Table row JUnit.hs:95/96: operator sections. Spec gap | **still present** (spec gap) | Counted under the 22 sections. |
| Table row Shellcheck.hs:78 `getList`: CAF not reported. Spec gap | **still present** (spec gap) | Also seen at Process:106 `globalIgnores`. |
| Table row Commandline.hs:261 `long` medium with two open external imports. Spec gap | **still present** (spec gap) | 79 `Options.Applicative.*` and 18 `Control.Applicative.*` medium edges in Commandline. |
| Pattern 3: several open external imports give low (102 edges). Spec gap | **still present** (spec gap) | 102 low edges in total. 96 are this spec gap. The other 6 are the FFI edges, which v3 counted inside this bucket (`js_document_getElementById` 2, ...). They are reclassified here as wrong (pattern 2 above), because the names are declared in the scan. |
| v2 items reported as fixed in v3: instance callers without type arguments, `&` stage lines, no constructor edges, `\|>` as callback, module-qualified callers | **still fixed** | 0 callers contain `(`. 0 callees are capitalized constructors. Rule.hs:177/231 callbacks are correct. All sampled and recall callers are module-qualified, with where/let nesting. |
