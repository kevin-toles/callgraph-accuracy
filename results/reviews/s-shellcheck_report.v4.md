# s-shellcheck (Haskell) call-graph review, v4 (blind)

precision 50/50; census ≈99.98% (2 wrong of 12181 in-scope); recall: 5 missed of 105 real calls; 0 non-calls

## Scope
The tool output has 12,187 edges, all from `.hs` files. 6 edges come from `test/shellcheck.hs` and are excluded under the `test/` rule. That leaves **12,181 in-scope edges in 30 files**, judged against SPEC.md including both Decisions sections (2026-10-29 and 2026-11-09).
- Confidence: high 7,254, medium 4,078, low 752, unknown 97.
- call_type: direct 12,084, callback 97. Every unknown edge is a callback and every callback is unknown.

No vendored, generated or fixture paths exist in this repo, and no gtest code. The 2026-11-09 body-less-declaration rule applies to the one scanned class, `Fixer.Ranged`: calls to its methods `start`, `end` and `setRange` (7 edges) are high, which is correct.

## Method
- **Sample:** seed 20261109. Stratified as high 25, medium 15, low 5, unknown 5, over 17 files. While fewer than 15 files were covered, an edge from an already-used file was skipped. All 50 were judged correct: real call, caller, callee, tier, call_type and line.
- **Recall:** three functions were read in full (bodies plus their where/let bindings) and compared with the tool's edges:
  - `ShellCheck.Parser.readCondition` (Parser.hs 951–980): 30 real calls, 28 found.
  - `ShellCheck.Formatter.TTY.outputForFile` (TTY.hs 123–142): 29 real calls, 29 found.
  - `ShellCheck.Checker.checkScript` with its where bindings (Checker.hs 67–122): 46 real calls, 43 found.
- **Census:** helper scripts are in the fanout folder with the prefix `s-shellcheck_r3_`. Each checked one thing across all in-scope edges:
  - Every callee name appears and is applied on its line: 12,160 fine. The 21 flagged were artifacts of my own comment-stripping on `"--"` string literals.
  - Every high callee resolves to a definition in the named module, and the source file imports that module: 0 exceptions.
  - Every nested callee is in the caller's scope: 0 exceptions.
  - Every nested caller is defined above its call line: 0 exceptions.
  - No external callee is shadowed by a visible scanned definition: 0.
  - No call through a parameter is resolved as a module function: 0. Lambda- and bind-shadowed names were checked too; the 8 flagged were checked by hand and were false alarms.
  - Every low edge sits in a file with more than one unlisted external import, so low is what the spec gives: true for all of them.
  - The unknown edges were checked by hand.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/ShellCheck/CFGAnalysis.hs:302 | `alreadyExists = isJust $ vmLookup name $ mapToCheck state` | `ShellCheck.CFGAnalysis.depsToState.insertIn.alreadyExists` → `mapToCheck`, low, direct | → `mapToCheck`, unknown, callback | wrong confidence / call_type | `mapToCheck` is a local holding a function, bound by the tuple pattern `(mapToCheck, inserter) = case scope of …` (line 296). It was treated as an unresolved bare name. |
| src/ShellCheck/CFGAnalysis.hs:305 | `then inserter name val state` | `ShellCheck.CFGAnalysis.depsToState.insertIn` → `inserter`, low, direct | → `inserter`, unknown, callback | wrong confidence / call_type | Same tuple-pattern-bound function local. |
| src/ShellCheck/Parser.hs:969 | `guard . not . null $ space` | only `Prelude.null` emitted | also `Control.Monad.guard`, `Prelude.not` (medium) | missed call | In an `f . g $ x` chain, only the function next to `$` gets an edge. |
| src/ShellCheck/Checker.hs:100 | `return . nub . sortMessages . filter shouldInclude $` | only `Prelude.filter` emitted | also `Prelude.return`, `Data.List.nub` (medium), `ShellCheck.Checker.checkScript.sortMessages` (high) | missed call | Same composition-chain pattern. |

None of the 50 sampled edges was wrong.

## Systematic patterns (precision), by scripted count
1. **Function values bound by a tuple pattern are called as low/direct instead of callback/unknown: 2 edges.** Found by `s-shellcheck_r3_localbind.py`; both checked by hand. By contrast, function values bound by `<-` (`(check, fix, flag) <- Map.lookup …`, Analytics.hs 2718/2726), lambda parameters and function parameters are all correctly unknown/callback.

No other wrong pattern was found. Union of wrong edges = 2, so census precision = 1 − 2/12,181 ≈ 99.98%.

## Missed-call patterns (recall)
1. **Composition chains `f . g . h $ x`:** only the last function before `$` gets an edge; the earlier ones are missed. A heuristic scan (`s-shellcheck_r3_compose.py`) finds about 122 missing callee occurrences. The most common are `guard` 27, `try` 22, `return` 15, `not` 9 and `lookAhead` 6. This is an approximate count and includes a few false positives. The spec only says that `f $ x` and `x & f` call `f`; it is silent on composition, so this is reported as recall, partly a spec gap.
2. In the three recall functions there were no other misses and no non-calls. Function references passed as arguments (`mapM_ warnFor`, `mapM normalize`, `maybe [] (arComments . analyzeScript . analysisSpec)`) correctly get no edge.

## Spec gaps (counted separately, not wrong)
1. **833 edges: bare base-library names resolved to their exporting module (medium) when a file has several unlisted external imports.** Examples: `Data.Maybe.isJust`, `Control.Monad.when`, `Data.List.isPrefixOf`. The Haskell note lists only the Prelude, import lists and "the one unlisted external import". It does not say whether a name that is not one of those, but is known to be exported by one of several unlisted imports, may be resolved. The names are correct for runtime. Non-base names in the same situation (Parsec `char`/`try`, `readSTRef`, fgl, aeson; 752 edges) are left low.
2. **75 edges: calls inside tuple pattern bindings fold into the enclosing binding.** For example, the `(minLine, maxLine) = foldl …` binding in TTY.hs (lines 149–152) is credited to `sliceFile`. The Haskell note gives `outer.f` for where/let bindings but says nothing about pattern bindings, which have no single name.
3. **295 do-statements run a nullary top-level action with no edge.** Examples: `getPosition`, `startSpan`, `allspacing`, `spacing` in `readCondition`. The spec does not say whether running an unapplied nullary value in a `do` block counts as a call.
4. **17 edges: record fields of function type that are applied.** Examples: `siReadFile sys (Just True) file`, `perToken checker`. These are emitted as high direct edges to the field selector. The spec does not say whether the applied function should be a callback.
5. **12 edges: naming of operator instance methods is inconsistent.** The tool writes `ShellCheck.AnalyzerLib.Semigroup.Checker.(<>)` (6 edges) but `ShellCheck.Fixer.Semigroup.Fix.<>` (6 edges). The spec does not fix a form for operator IDs.
6. **No edges for operator applications.** This includes the scanned operator `ShellCheck.Prelude.!!!` (7 uses). The spec is silent on operators.
7. **No edges for Template Haskell splices** (`$(forAllProperties)`, `$quickCheckAll`; 14 occurrences). These run at compile time, and the spec does not cover them. The 14 top-level `return []` declaration splices do get module-caller `Prelude.return` edges, which follows the top-level-code rule.
