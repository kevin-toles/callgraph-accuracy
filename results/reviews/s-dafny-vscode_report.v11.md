# Blind call-graph review: s-dafny-vscode (typescript), round 11

precision 47/50; census ≈97.8% (31 wrong of 1434 in-scope); recall: 0 missed of 35 real calls; 0 non-calls

(Sample: 47 correct, 2 wrong, 1 spec gap. Separately, 6 implicit field-initializer edges are missing outside the recall functions; see Missed-call patterns.)

## Scope
Tool output `<scans>/final12-A/s-dafny-vscode.v2.json` has 1498 edges, all in `.ts` files. 64 are under `client/test/` and are excluded (`client/test/extension.test.ts` 63, `client/test/index.ts` 1). `client/src/extension.test.ts` stays in scope because no path segment is `test`. That leaves **1434 in-scope edges in 63 files**.
- By confidence: high 700, medium 555, low 144, unknown 35.
- By call_type: method 700, direct 339, implicit 221, constructor 139, callback 35.
- By pair: high/method 348, medium/direct 276, high/implicit 221, medium/method 211, low/method 141, high/constructor 71, medium/constructor 68, high/direct 60, unknown/callback 35, low/direct 3.

I ignored the `measured_accuracy` field. The sample was drawn with seed 1111: high 22, medium 18, low 5, unknown 5, spread over 27 files.

Beyond the sample, I read every low (144) and unknown (35) edge by hand. I reviewed medium edges by their distinct callees. Every high callee is in `nodes`. Every in-scan `T#m` method callee was checked against a method declaration (0 failures). Implicit edges were checked against all class-field initializers.

## Mismatch table
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| server/src/server.ts:125 (sample #43) | `result.then((lenses: ReferencesCodeLens[]) => {` | waitForServer → `result.then`, low, method | `Promise#then`, medium, method. `const result = provider.referenceProvider.provideCodeLenses(...)`, which is declared `Promise<ReferencesCodeLens[]>` in baseCodeLensProvider.ts:10 (let-bound call result, 2026-11-12) | wrong callee / confidence | local bound to a call result not typed |
| server/src/vscodeFunctions/documentDecorator.ts:101 (sample #45) | `let positionOfInsertion =  this.documentLines[currentLine].substr(0, currentPosition)...` | findInsertPositionRange → `.substr`, low, method | `String#substr`, medium, method. Field `public documentLines: string[];` (line 12); an index receiver is typed from declarations ("Typed call results") | wrong callee / confidence | index receiver not typed |
| client/src/helpers/capabilities.ts:31 (sample #42) | `.exec(monoVersionOutput)!.slice(1)...` on the regex literal `/compiler version (\d+)\.(\d+)\.(\d+)/i` | `.exec`, low, method | undecided | spec gap | literal receiver (see Spec gaps) |
| server/src/backend/features/codeActions/guardCommandGenerator.ts:12 | `return this.server.symbolService.getAllSymbols(this.doc).then(...` | calculateCommands → `.then`, low, method | `Promise#then`, medium (`getAllSymbols(...): Promise<DafnySymbol[]>`, symbolService.ts:45) | wrong callee / confidence | in-place typed call result not typed on this receiver chain. The same shape `dafnyInstaller.latestVersionInstalled(v).then` (server.ts:59) is `Promise#then`, so this is also a C2 inconsistency |
| server/src/server.ts:123 | `}).then(() => {` (chain head `return new Promise(async (resolve, reject) => {`, line 112) | waitForServer → `.then`, low | `Promise#then`, medium | wrong callee / confidence | receiver `new Promise(...)` not typed |
| server/src/backend/features/baseCodeLensProvider.ts:17 | `const symbolTable = symbolTables.find(...)` with `const symbolTables = await this.server.symbolService.getSymbols(document);` | `symbolTables.find`, low | `Array#find`, medium (await of `Promise<SymbolTable[]>` is `SymbolTable[]`, final5 reading) | wrong callee / confidence | await-bound local not typed |
| client/src/dafnyProvider.ts:83 | `subscription.dispose();` in `for (const subscription of this.subscriptions)`, field `vscode.Disposable[]` | `subscription.dispose`, low | `vscode.Disposable#dispose`, medium (decision A, for-loop variable) | wrong callee / confidence | for-of variable not typed |
| server/src/backend/features/definitionProvider.ts:45 | `for (const symb of symbolTable.symbols.filter(...` (`symbolTable` iterates an `await getSymbols()` local; `SymbolTable.symbols: DafnySymbol[]`) | `symbols.filter`, low | `Array#filter`, medium | wrong callee / confidence | for-of variable not typed |
| client/src/counterModelProvider.ts:19 | `this.context.decorators[editor.document.uri.toString()].dispose();` (`decorators: { [k: string]: vscode.TextEditorDecorationType }`) | `.dispose`, low | `vscode.TextEditorDecorationType#dispose`, medium | wrong callee / confidence | index receiver not typed |
| server/src/backend/verificationResults.ts:64 | `const errors = Verification.LogParseRegex.exec(sourceLine);` (`public static LogParseRegex = new RegExp(...)`) | `server/src/strings/regexRessources.Verification.LogParseRegex.exec`, medium, direct | `RegExp#exec`, medium, method (decision A `= new T(...)`) | wrong callee | invented ID under a scanned class (C2); the static field is typed by `new RegExp` |
| client/src/dafnyProvider.ts:35 | `Context.unitTest.verificationComplete(verificationResult);` (`unitTest: UnitTestCallback`, whose `verificationComplete = (...) => {...}` is an arrow-valued field) | `client/src/context.Context.unitTest.verificationComplete`, medium, direct | `verificationComplete`, callback, unknown (stored property holding a function) | wrong callee / call_type / confidence | invented ID (C2) on a function-valued property |
| server/src/backend/dafnyServer.ts:132 | `this.context.activeRequest.callback(log);` (`public callback?: ((data: any) => any)`) | `VerificationRequest#callback`, medium, method | `callback`, callback, unknown | wrong callee / call_type / confidence | open defect typescript/03 (function-valued property reported as a method) |

## Systematic patterns (scripted counts; `s-dafny-vscode_r11_census.py`)
Each pattern was hand-checked on every hit, because the counts are small. The script found 3 false positives, which I removed (`process.on` at dafnyCompiler.ts:29, where `process` comes from external `cp.spawn`; `asset.name.indexOf`, where `assets: any[]`; `word.match`, moved to spec gaps).

| # | pattern | count |
|---|---|---|
| A | Receiver is an index into a declared container (`this.documentLines[i]` with `string[]`; `this.changeSet[uri]` with `{[uri]: TextEdit[]}`; `this.context.decorators[k]` with `{[k]: TextEditorDecorationType}`). Emitted as `.m` low instead of `T#m` medium. Only the first call in each chain is wrong; later calls on lib-typed results stay correct low guesses. | 9 |
| B | In-place `.then` on a scanned method declared `Promise<...>` (`this.server.symbolService.getAllSymbols(x).then`) emitted as `.then` low (guard 12, null 14, definition 58, referenceCodeLens 63, rename 30). The same construct on other receivers gives `Promise#then` medium (server.ts:59, 196, 198; symbolService.ts:21), which also breaks C2. | 5 |
| E | Invented dotted IDs under a scanned class, added to `nodes` but with no definition: `regexRessources.Verification.{LogParseRegex,NumberOfProofObligations,RelatedLocationRegex}.exec` (3) and `client/src/context.Context.unitTest.{verificationComplete,activated,backendStarted}` (3). | 6 |
| C | `const x = <scanned call with declared return type>` (or `await` of one returning `Promise<T>`), then `x.m()` left as `x.m` low: server.ts 125 and 146 (`result.then`), baseCodeLensProvider.ts:17, completionProvider.ts:15. | 4 |
| D | A for-of variable over a declared array, left as `v.m` low: client/src/dafnyProvider.ts:83 and server/src/frontend/dafnyProvider.ts:46 (`Disposable[]`), definitionProvider.ts 45 and 46 (`SymbolTable.symbols`). | 4 |
| F | Function-valued property called as a method (open defect typescript/03): `VerificationRequest#callback` and `#error`, at medium even though the type is in the scan. | 2 |
| B' | In-place `.then` on `new Promise(...)` (server.ts:123). | 1 |

Union: 31 distinct wrong edges of 1434, so census precision = 1 − 31/1434 ≈ **97.84%**.

## Recall (3 functions)
| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| `server/src/backend/dafnyServer.DafnyServer#handleProcessData` (dafnyServer.ts:121–145) | 14 | 14 | 0 | 0 (the `callback(log)` edge is present but misclassified: pattern F) |
| `server/src/vscodeFunctions/documentDecorator.DocumentDecorator#getText` (documentDecorator.ts:19–39) | 13 | 13 | 0 | 0 (5 of them are pattern A) |
| `client/src/ui/commands.Commands#compile` (commands.ts:129–148) | 8 | 8 | 0 | 0 |

## Missed-call patterns
- **Arrow-function field initializers get no `implicit` edge.** The 6 fields of `UnitTestCallback` in client/src/extension.test.ts (lines 17–22, e.g. `public backendStarted = () => { };`) have no `UnitTestCallback#<init> → UnitTestCallback#field` edge. The other 221 field initializers in scope all have one. Count: 6.
- No other missed calls were found in the recall functions or while reading the low and unknown edges.

## Spec gaps (17 edges, not counted as wrong)
1. **Literal receivers (7).** Examples: `"⚫".repeat(completed)` (dafnyStatusbar.ts:71, ×2), `":".indexOf(iterator.currentChar)` (documentDecorator.ts:254), `" \t\n\r\v".indexOf(this.currentChar)` (documentIterator.ts:59), `/[^a-zA-Z0-9]/.test(this.currentChar)` (documentIterator.ts 64 and 70), and `/compiler version .../i .exec(...)` (capabilities.ts:31). The tool emits `.m` low. "Typed call results" says a literal receiver is typed "when its static type can be determined from declarations". A string or regex literal's type is fixed by the language, not by a declaration in the scan. SPEC does not say whether such a literal is typed (`String#repeat`, `RegExp#test`) or stays `.m`.
2. **Locals bound to a literal (2).** Examples: `const identifiersRegex = /(\w+)/g; ... identifiersRegex.exec(expression)` (stringUtils.ts:38) and `const parsedLocations = []; ... parsedLocations.push(...)` (commands.ts:31). SPEC types bindings from `= new T(...)` and from call results, but does not say whether a local initialised with a regex or array literal is typed.
3. **`.apply` on a receiver outside the evidence list (3).** Examples: `Math.max.apply(null, possibleStarts)` and `Math.min.apply(...)` (wordHelper.ts 110 and 112), emitted as `Function#apply` plus `Math.max`; and `([] as DafnySymbol[]).concat.apply([], ...)` (symbolService.ts:47), emitted as `concat.apply` low. The 2026-11-12 `.call/.apply/.bind` ruling's evidence list covers scanned functions and bindings. It does not say whether an external global function (`Math.max`) or a method of a cast array literal is a `Function.prototype` receiver.
4. **Local bound to a typed property, not a call (3).** Example: `const args = dafnyCommand.args; args.push(...)` (dafnyCompiler.ts 24–26), where `dafnyCommand: Command` and `args: string[]`. The let-bound ruling covers call results, and decision A covers declared locals and property chains. SPEC does not say whether an unannotated local takes the declared type of the property it is initialised from.
5. **Local bound to a conditional (1).** Example: `const word = wordRange ? this.getText(wordRange) : ""; ... word.match(...)` (documentDecorator.ts:211). SPEC does not say whether a conditional whose branches are a typed call result and a literal types the local.
6. **`await` of a typed parameter (1).** Example: `const commands = await collection;` with `collection: Promise<Command[]>`, then `commands.concat(newCommands)` (codeActionProvider.ts:42). The final5 reading types `await` of a *call* declared `Promise<T>`. SPEC does not say whether `await` of a parameter or local declared `Promise<T>` gives `T`.

## Files
- Report: `<fanout>/s-dafny-vscode_report.v11.md`
- Helper scripts: `<fanout>/s-dafny-vscode_r11_load.py`, `s-dafny-vscode_r11_sample.py`, `s-dafny-vscode_r11_at.py`, `s-dafny-vscode_r11_high.py`, `s-dafny-vscode_r11_fields.py`, `s-dafny-vscode_r11_census.py` (same folder)
