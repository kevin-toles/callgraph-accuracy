# Blind call-graph review: s-haskell (haskell)

precision 50/50; census ≈100% (0 wrong of 878 in-scope); recall: 0 missed of 36 real calls; 0 non-calls

## Scope
Source root `<source-root>/algorithms/nayuki-Project-Euler-solutions/haskell` (96 `.hs` files: `EulerLib.hs` plus 95 `pNNN.hs` solutions, 6,125 lines). The tool output `s-haskell.v2.json` has 878 edges, all with `.hs` source files and none under test/tests/spec/examples/docs, so all 878 are in scope. Confidence: high 257, medium 615, unknown 6, low 0. call_type: direct 872, callback 6. Only `EulerLib.hs` has a `module` header. Every other file's module is its file name (`p026`), which the tool uses.

## Method
- **Precision sample:** seed 20261109, stratified 33 medium / 12 high / 5 unknown, spread over 35 files (`s-haskell_r6_sample.py`). I opened every edge at its line and judged it.
- **Recall:** I listed every call by hand in `p287.compressedLength` (lines 50–66), `p024.nextPerm` (lines 25–39, including its `where findPrefix`) and `p045.compute` (lines 14–23), counting their let/where bindings (`outer.f`), and compared them with the tool's edges.
- **Census scripts:**
  - `s-haskell_r6_ids.py`: every caller's module prefix and nested binding names are defined in the file; every high callee is defined in the scan; the callee's name appears on the reported line.
  - `s-haskell_r6_dups.py`: the edge count per (line, callee) is never above the callee's occurrences on that line.
  - `s-haskell_r6_shadow.py`: no medium `Prelude.`/library callee is shadowed by a local definition.
  - `s-haskell_r6_diff.py`: a heuristic re-extraction of applications per line, compared with the tool.
  - I checked every discrepancy from these scripts by hand. All were heuristic noise: definition heads with guards, functions passed as arguments such as `foldl1 max`, `map show`, `filter EulerLib.isPrime`, and same-line `let x =` bindings.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| (none) | | | | | |

The checks I made by hand on tricky constructs all confirmed the tool:
- **Shadowing:** the local `sqrt = EulerLib.sqrt (...)` in p100:54, then `mod sqrt 2`, produces no `Prelude.sqrt` edge. The where-bound `sqrt = length upToSqrt` in p023:20 is handled the same way.
- **Calls through parameters:** `argMax f = foldl1' (\x y -> if (f y) > (f x) ...)` (p026:31, p039:21, p085:27) gives `f`, unknown, callback, twice per line.
- **Pattern bindings fold into the enclosing function:** `newPivot : suffixTail = drop (length suffixHead) revSuffix` (p024:33) → `p024.nextPerm`, and `let (n, d) = func (i+1) end` (p065:17) → `p065.ans.func`.
- **Nested where/let IDs:** `p060.findSetSum.findCandidate.s`, `p112.ans.func.c`, `EulerLib.sqrt.sqrtAlpha`.
- **Import-list resolution:** `isPrime` in p060:39 resolves to `Data.Numbers.Primes.isPrime` (medium), while `EulerLib.isPrime` elsewhere is high. `stripPrefix` resolves to `Data.List.stripPrefix` and `ord` to `Data.Char.ord`.
- **Calling a point-free top-level binding:** `main = putStrLn (ans "")` (p205:13) → `p205.ans`, high.
- **Multi-line application:** `else compute` followed by argument lines (p045:20–23) is reported on the line of `compute`.
- **Functions passed, not applied, get no edge:** `map toUpper` (p162:48), `iterate (>>= nextPerm)` (p024:20).

## Systematic patterns
None found. Every scripted check returned zero wrong in-scope edges, so the census union is 0 of 878.

## Missed-call patterns (recall)
| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| p287.compressedLength (+ minAbsX/minAbsY/maxAbsX/maxAbsY/xMid/yMid) | 18 (min×2, max×2, abs×8, div×2, compressedLength×4) | 18 | 0 | 0 |
| p024.nextPerm (+ len/revSuffix/suffixLen/prefixMinusPivot/suffixHead, where findPrefix) | 11 (length×3, findPrefix×2, reverse, take, takeWhile, drop, head) | 11 | 0 | 0 |
| p045.compute (+ triangle/pentagon/minim) | 7 (div×2, minimum, compute, condInc×3) | 7 | 0 | 0 |

The tool emits no edges for operators, composition or bare top-level value references. Those cases are listed under spec gaps and are not counted as misses.

## Spec gaps (not counted as wrong)
1. **Library operators get no edge.** These are `!!` (65), `^` (67), `++` (15), `%` (7), `.&.` (1), `.|.` (1) and `>>=` (1): 157 occurrences counted by `s-haskell_r6_gaps.py`. Arithmetic and comparison operators are uncounted. The spec says only that `$`/`&` call their operand, not whether operators are calls.
2. **Function composition `f . g` gets no edges for the composed functions.** There are 4 lines and 6 references: `not . isSumOfTwoAbundants` (p023:12), `not . satisfiesConjecture` (p046:13), `sum . (map ...)` (p022:21, p042:20). Only `map`, which is itself applied, gets an edge.
3. **Partial applications passed as arguments are reported as calls (high).** Examples: `iterate (convolve cubicDiePdf) [1]` (p205:20,23), `all (isConcatPrime p) foundSet` (p060:33), `map (func 0 1) sRange` (p139:18). The spec does not say whether an unsaturated application is a call. I did not count these exhaustively.
4. **A reference to a nullary top-level binding (a constant applicative form, CAF) gets no edge.** Examples are `ans` in `putStrLn (show ans)` (about 95 files) and `primes`/`partitionsMemo` in expressions. The spec does not say whether evaluating a CAF is a call.
5. **An alias where-binding gets no edge to its target.** `where readInt = read :: String -> Int` (p060:40) has no edge to `Prelude.read`, while calls to `readInt` go to `p060.isConcatPrime.readInt` (high). The spec has an alias-resolution rule for Lua and Zig only, not for Haskell. 1 instance.
