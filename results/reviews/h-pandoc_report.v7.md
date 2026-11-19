# Blind call-graph review: h-pandoc (haskell), round 7

precision 50/50; census ≈99.86% (76 wrong of 52719 in-scope); recall: 0 missed of 88 real calls; 0 non-calls

## Scope
Tool output: `<scans>/final8-A/h-pandoc.v2.json` (63,888 edges in all). In scope: edges whose `source_file` is a `.hs` file with no `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment. Lua (2,145), JS (561) and Python (133) edges are out of scope. That leaves **52,719 in-scope edges in 278 files**: `src/` 49,889, `pandoc-lua-engine/` 2,185, `xml-light/` 244, `pandoc-server/` 202, `pandoc-cli/` 117, `benchmark/` 82.
- Confidence: high 21,562 · medium 27,196 · low 3,722 · unknown 239.
- call_type: direct 52,480 · callback 239. All unknown edges are callbacks, and every callback is unknown.
- I ignored the `measured_accuracy` field. Helper scripts are `h-pandoc_r7_*.py` in the fanout folder.

## Method
- **Precision sample:** seed `20261113`, stratified as medium 22, high 18, low 5, unknown 5, across 39 files (`h-pandoc_r7_sample.py`, `h-pandoc_r7_ctx.py`). For each edge I opened the source at its line and checked six things: is it a real application, the caller (including where/let nesting), the callee (resolved through the import list, re-exports of scanned modules, the Prelude, the one-unlisted-external-import rule and the known-exports index), the tier, the call_type and the line.
- **Recall:** I read three functions in full and compared every call with the tool's edges.
- **Census scripts:**
  - caller vs enclosing top-level span (`callerspan`);
  - same-file definitions missing from `nodes` (`missingdefs`);
  - low bare names vs import lists and unlisted-import counts (`lowbare`, `lowlocal`, `reexp`);
  - Prelude conflicts (`prelude`);
  - external-module evidence (`extmod`);
  - aliases of scanned modules (`qual`);
  - high-callee existence and nested scope (`highdef`, `nestscope`);
  - locally bound names resolved globally (`shadow`, `shadow2`);
  - callback binding (`unknown`);
  - reported line contains the callee (`line`);
  - non-call occurrences (`notcall`);
  - final union (`census`).

## Precision sample result
All 50 sampled edges are correct per SPEC. Some checks along the way:
- `isSpace` resolves through `import Data.Char (isSpace)`.
- `char` resolves through `Text.Pandoc.Parsing`'s `module Text.Pandoc.Sources` re-export to `Text.Pandoc.Sources.char`, high.
- `try` and `sourceColumn` go through that module's `Text.Parsec` import list to `Text.Parsec.try`, medium.
- `typeMismatchMessage` is the one unlisted external import, `HsLua`, medium.
- The low bare names (`modify`, `preEscapedString`, `parameter`, `toHtml`, `literal`) all sit in files with 2 or more unlisted external non-base imports. Low is correct there.
- Where/let bindings, including value lets such as `tex2pdf.extramsg` and `inlineToHtml.str'`, are named `outer.f`, as the Haskell note says.
- The 5 callbacks are all calls through parameters (`renderItems`, `cssvars`, `f`, `fallback`).

## Mismatch table (found by census; none in the sample)
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/Text/Pandoc/Readers/Markdown.hs:166 | `spnl' = try $ do` | `Text.Pandoc.Readers.Markdown.spnl` → `Text.Parsec.try`, medium, direct | caller `Text.Pandoc.Readers.Markdown.spnl'` | wrong caller | the 9 definitions after `spnl` (lines 165–249) are not recognised, and their bodies fold into `spnl` |
| src/Text/Pandoc/Readers/Markdown.hs:187 | `gobbleAtMostSpaces (tabStop - 1) <* notFollowedBy spaceChar` | `…Markdown.spnl` → `Text.Pandoc.Parsing.General.gobbleAtMostSpaces`, high, direct | caller `…Markdown.skipNonindentSpaces` | wrong caller | same |
| src/Text/Pandoc/Readers/Markdown.hs:208 | `pure $ case c of` | `…Markdown.spnl` → `Prelude.pure`, medium, direct | caller `…Markdown.litCharNoSpace.escapedChar''` | wrong caller | same (a where-binding of an absorbed definition) |
| src/Text/Pandoc/Readers/Markdown.hs:224 | `try $ char '[' >> withRaw (go 1) >>=` | `…Markdown.spnl` → `go`, low, direct | `…Markdown.inBalancedBrackets` → `…Markdown.inBalancedBrackets.go`, high | wrong caller + wrong callee/confidence | same |
| src/Text/Pandoc/Readers/Markdown.hs:382 | `(try (litBetween '<' '>') <\|> sourceURL)` | `…Markdown.referenceKey` → `litBetween`, low, direct | `…Markdown.litBetween`, high (defined at line 195 of the same module) | wrong callee / wrong confidence | the callee is one of the unrecognised definitions |
| src/Text/Pandoc/Readers/Markdown.hs:1863 | `withRaw $ trimInlinesF <$> inBalancedBrackets inlines` | `…Markdown.reference` → `inBalancedBrackets`, low, direct | `…Markdown.inBalancedBrackets`, high | wrong callee / wrong confidence | same |
| src/Text/Pandoc/SelfContained.hs:309 | `pCSSImport d = P.try $ do` (with `import qualified Text.Pandoc.Parsing as P`) | `…SelfContained.pCSSImport` → `P.try`, medium, direct | `Text.Parsec.try`, medium (the ID that `try` gets through the same module unqualified, e.g. Vimwiki.hs:319) | wrong callee | an alias of a scanned module names a function the module only re-exports from an external package; C2 says no invented `mod.f` |
| src/Text/Pandoc/Readers/Man.hs:199 | `msatisfy predic = P.tokenPrim show nextPos testTok` | `…Man.msatisfy` → `P.tokenPrim`, medium, direct | `Text.Parsec.tokenPrim`, medium | wrong callee | same |

Also, contract C1: the nine definitions `spnl'`, `indentSpaces`, `nonindentSpaces`, `skipNonindentSpaces`, `litChar`, `litBetween`, `litCharNoSpace`, `litBetweenNoSpace` and `inBalancedBrackets` (and `inBalancedBrackets.go`) are missing from `nodes`. The same pattern also leaves the calls to them as low bare names (pattern 2).

## Systematic patterns (scripted counts, ordered by count)
1. **Definitions absorbed into a preceding definition: 49 edges.** Markdown.hs lines 165–249 cover nine top-level definitions. Every edge in that range has caller `Text.Pandoc.Readers.Markdown.spnl`. The census script checks each edge's caller against the enclosing column-0 binding. Across all 278 files, this is the only real span mismatch. The other 10 hits are infix-form definitions (`` x `closes` "p" ``, `a <+?> b`), which are correct. Hand-checked: lines 166, 175, 187, 197, 208, 224 and 244.
2. **Alias of a scanned module naming an externally defined re-export: 20 edges**, in Man.hs, Mdoc.hs and SelfContained.hs:
   - `P.try` 6, `P.manyTill` 3, `P.tokenPrim` 2;
   - `P.many`, `P.many1`, `P.option`, `P.lookAhead`, `P.runParser`, `P.updatePosString`, `P.setSourceColumn`, `P.setSourceLine`, `P.sourceLine` 1 each.

   On the same lines, `P.char`, `P.string`, `P.noneOf` and `P.oneOf` do resolve through the re-export to `Text.Pandoc.Sources.*`, high. So only the external re-exports keep the alias spelling. Text.Pandoc.Parsing does not define these names, which makes the IDs invented under C2. Unqualified, the same names give `Text.Parsec.*`.
3. **Low bare calls to the absorbed definitions: 7 edges.** `litBetween` ×2, `litBetweenNoSpace` ×2, `inBalancedBrackets` ×3, all in Markdown.hs. Each should be `Text.Pandoc.Readers.Markdown.<name>`, high.

Union: 49 + 20 + 7 = **76** (the three sets are disjoint). Census precision = 1 − 76/52,719 = **99.86%**.

Patterns checked and found clean:
- **Lines:** in all 52,719 edges, the callee name appears on the reported line.
- **Not calls:** no data-constructor edges, no record-label or signature occurrences, no operator edges. Function references passed as arguments get no edge, as SPEC requires.
- **High tier:** every high callee is in `nodes` and names a real definition (21,562/21,562). Every nested high callee is in its caller's scope.
- **Prelude:** no `Prelude.x` edge conflicts with a `hiding`, a local top-level definition or a listed import. The 41 `Prelude.fail` edges are written `Prelude.fail` in the source.
- **Low bare names:** none is in a listed import, and none sits in a file with exactly one unlisted external import. Every one sits in a file with 2 or more unlisted external non-base imports, or is reached only through an external `T(..)` (`Walkable(..)`, `Reference(..)`, `HasMeta(..)`) or an external class's method inside an instance body (`toJSON`, `parseJSON`, `setMeta`). The only exceptions are the 7 in pattern 3.
- **Callbacks:** all 239 are bound as a parameter or lambda variable in scope.
- **Medium tier:** no medium callee names a scanned module.

## Recall
| function | file | real calls | tool edges matched | missed | non-calls |
|---|---|---|---|---|---|
| `Text.Pandoc.Readers.Markdown.referenceKey` (+ `.sourceURL`, `.attr'`, `.target`, `.oldkeys`, `.key`) | src/Text/Pandoc/Readers/Markdown.hs:363–404 | 49 | 49 | 0 | 0 |
| `Text.Pandoc.ImageSize.jpegSize` (+ `.scanSegments`, `.skipFill`, `.scanSegment`, `.scanSegment.n`) | src/Text/Pandoc/ImageSize.hs:447–492 | 28 | 28 | 0 | 0 |
| `Text.Pandoc.Data.defaultUserDataDir` | src/Text/Pandoc/Data.hs:246–256 | 11 | 11 | 0 | 0 |

Total: 0 missed of 88 real calls (applications), 0 non-calls.

Two edges in these functions have the wrong tier. They are already counted in the census: `litBetween` at Markdown.hs:382 is low, and should be high. Another 18 parameterless names are run, not applied, in these functions (spec gap 1). The tool emits no edge for them, and I did not count them as missed.

## Missed-call patterns (recall)
- None found among applications.
- Not counted as missed: bare parameterless monadic actions (spec gap 1).
- Not counted as missed: operator applications (`==`, `<|>`, `>>`, `<>`), which CAPABILITIES lists as undecided (`haskell/16-known-gap-operators`). The tool emits no operator edges at all.

## Spec gaps (counted separately, not wrong)
1. **Parameterless bindings run as monadic actions: no edge emitted.** In the recall functions: 18 occurrences (11 in referenceKey, 7 in jpegSize). No repo-wide count, because these emit nothing. Constructs: `pos <- getPosition` and `skipNonindentSpaces` (Markdown.hs:365–366), `ff <- getWord8` and `marker <- skipFill` (ImageSize.hs:455, 457), `skipSpaces >> optional newline >> skipSpaces` (Markdown.hs:370). Open question: is a bare reference to a parameterless binding that is a do-statement or a `>>` operand (a scanned CAF such as `skipNonindentSpaces`, a local such as `skipFill`) an invocation edge, or a reference without a call? The Haskell note only covers application (`f $ x`, `x & f`).
2. **Instance-method IDs with a compound instance type: 132 edges** (caller IDs). The constructs are:
   - multi-parameter class heads: `instance Walkable Inline Chunk` gives `Text.Pandoc.Chunks.Walkable.Inline Chunk.walk`; also `UpdateSourcePos.Sources Char`, `HasQuoteContext.ParserState m`;
   - list and tuple heads: `instance ToSources [(FilePath, Text)] where` (Sources.hs:80) gives `Text.Pandoc.Sources.ToSources.[(FilePath, Text)].toSources`; also `Node.([Attr],Content).node`;
   - function-type heads: `FromJSON (Opt -> StateT DefaultsState m Opt) where` (Opt.hs:357) gives `Text.Pandoc.App.Opt.FromJSON.Opt -> StateT DefaultsState m Opt.parseJSON`.

   Open question: SPEC says instance methods are `Module.Class.Type.m`, and that generic arguments are dropped. It does not say what `Type` is when the class has several type parameters, or when the instance type is a list, tuple or function type, nor how the remaining type variables (`m`) and spaces should appear in the ID.
3. **Operator definition IDs: 22 edges** (caller IDs). A prefix-form definition `(<>) = liftA2 (<>)` (Future.hs:30) gives `…Semigroup.Future.(<>)`, and `(!) f attrs n = …` (EPUB.hs:1246) gives `Text.Pandoc.Writers.EPUB.(!)`. An infix-form definition `ExtensionsDiff enA disA <> ExtensionsDiff enB disB =` (Format.hs:60) gives `…Semigroup.ExtensionsDiff.<>`, and `a <+?> b = …` (General.hs:710) gives `Text.Pandoc.Parsing.General.<+?>`. Open question: SPEC does not define the definition ID of a Haskell operator, with or without parentheses. CAPABILITIES `haskell/16-known-gap-operators` leaves operator callee IDs undecided too.
