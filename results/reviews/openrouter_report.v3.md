# openrouter (typescript) call-graph review, v3

**Summary:** precision 47/50; census ≈95.7% (39 wrong of 909 in-scope); recall: 0 missed of 28 real calls; 0 non-calls

Scope: the graph has 6588 edges. 909 are in scope: `src/**` without `*.test.ts` (887), plus the root build and test configs `tsup.config.ts` and `vitest.*.config.ts` (22). The spec's exclusion list does not cover those root configs, so this time they are in scope. The v2 review left them out. `e2e/` is excluded. The tiers are 119 high, 481 medium, 308 low and 1 unknown. Without the 22 root-config edges, the tier counts are exactly the ones the v2 review reported (119/459/308/1). The edge set looks unchanged since v2.

Sample: seed `20261028`. It is stratified by tier and picks unseen files first: 7 high, 25 medium, 17 low and 1 unknown (the only unknown edge). It covers 27 files. Scripts are `openrouter_v3_*.py` in the fanout folder.

## Precision sample (50)
| # | file:line | edge (caller → callee, conf, type) | verdict |
|---|---|---|---|
| 1 | utils/with-stream-error-handling.ts:16 | withStreamErrorHandling → onError, unknown, callback | OK (`onError` is a parameter) |
| 2 | chat/convert-to-openrouter-chat-messages.ts:343 | convertToOpenRouterChatMessages → ReasoningDetailsDuplicateTracker#upsert, high | OK (`= new ReasoningDetailsDuplicateTracker()` at :54) |
| 3 | provider.ts:263 | createOpenRouter.createImageModel → src/image.OpenRouterImageModel#<init>, high | OK (named nested arrow) |
| 4 | image/index.ts:40 | OpenRouterImageModel#<init> → #maxImagesPerCall, high, implicit | OK |
| 5 | completion/index.ts:263 | #doStream → #getArgs, high | OK |
| 6 | chat/index.ts:300 | #doGenerate → src/utils/compute-token-usage.emptyUsage, high | OK |
| 7 | video/index.ts:45 | OpenRouterVideoModel#<init> → #maxVideosPerCall, high, implicit | OK |
| 8 | utils/reasoning-details-duplicate-tracker.ts:28 | #upsert → #getCanonicalKey, high | OK |
| 9 | chat/schemas.ts:29 | src/chat/schemas → zod/v4.z.number, medium | OK |
| 10 | completion/schemas.ts:48 | src/completion/schemas → zod/v4.z.object, medium | OK (on the `.object(` line) |
| 11 | chat/index.ts:254 | #doGenerate → `OpenRouterChatConfig#url`, medium | **wrong callee** (see table) |
| 12 | chat/convert-to-openrouter-chat-messages.ts:179 | → Set#<init>, medium, constructor | OK |
| 13 | image/index.ts:140 | #doGenerate → @ai-sdk/provider-utils.postJsonToApi, medium | OK |
| 14 | image/schemas.ts:36 | → zod/v4.z.object, medium | OK |
| 15 | embedding/index.ts:81 | #doEmbed → @ai-sdk/provider-utils.createJsonResponseHandler, medium | OK |
| 16 | video/index.ts:204 | #pollUntilComplete → createJsonResponseHandler, medium | OK |
| 17 | schemas/reasoning-details.ts:70 | → zod/v4.z.object, medium | OK |
| 18 | completion/index.ts:170 | #doGenerate → createJsonResponseHandler, medium | OK |
| 19 | schemas/provider-metadata.ts:56 | → zod/v4.z.any, medium | OK |
| 20 | embedding/schemas.ts:4 | → zod/v4.z.number, medium | OK |
| 21 | vitest.e2e.config.ts:9 | vitest.e2e.config → vitest/config.defineConfig, medium | OK (module-level caller) |
| 22 | completion/convert-to-openrouter-completion-prompt.ts:104 | → @ai-sdk/provider.UnsupportedFunctionalityError#<init>, medium | OK |
| 23 | video/schemas.ts:21 | → zod/v4.z.string, medium | OK |
| 24 | vitest.edge.config.ts:14 | → JSON.stringify, medium | OK |
| 25 | vitest.issues.config.ts:22 | → dotenv.config, medium | OK (`import { config } from 'dotenv'`) |
| 26 | chat/is-url.ts:9 | isUrl → URL#<init>, medium | OK |
| 27 | chat/get-tool-choice.ts:7 | src/chat/get-tool-choice → zod/v4.z.literal, medium | OK |
| 28 | chat/file-url-utils.ts:133 | getInputAudioData → Set#<init>, medium | OK |
| 29 | utils/reasoning-details-duplicate-tracker.ts:33 | #upsert → Set#has, medium | OK (`readonly #seenKeys = new Set<string>()`) |
| 30 | utils/with-user-agent-suffix.ts:18 | normalizeHeaders → Array.isArray, medium | OK |
| 31 | provider.ts:215 | createOpenRouter.getHeaders → JSON.stringify, medium | OK |
| 32 | tsup.config.ts:5 | tsup.config → node:fs.readFileSync, medium | OK |
| 33 | facade.ts:61 | OpenRouter#<init> → withoutTrailingSlash, medium | OK |
| 34 | chat/schemas.ts:26 | → .passthrough, low | OK |
| 35 | chat/index.ts:790 | #doStream → `accumulatedReasoningDetails.push`, low | **wrong callee/confidence** (see table) |
| 36 | schemas/reasoning-details.ts:43 | → .nullish, low | OK |
| 37 | embedding/schemas.ts:12 | → .optional, low | OK |
| 38 | utils/with-user-agent-suffix.ts:70 | withUserAgentSuffix → key.toLowerCase, low | OK (untyped arrow parameter) |
| 39 | chat/convert-to-openrouter-chat-messages.ts:484 | mapToolResultContentParts → mediaType.replace, low | OK (the property type is declared outside the scan) |
| 40 | schemas/provider-metadata.ts:69 | → .catchall, low | OK |
| 41 | image/schemas.ts:26 | → .passthrough, low | OK |
| 42 | schemas/error-response.ts:19 | → .passthrough, low | OK |
| 43 | completion/schemas.ts:60 | → .nullish, low | OK |
| 44 | completion/convert-to-openrouter-completion-prompt.ts:126 | → .join, low | OK |
| 45 | video/schemas.ts:30 | → .optional, low | OK |
| 46 | completion/index.ts:319 | #doStream → safeResponse.pipeThrough, low | OK (`const safeResponse = withStreamErrorHandling(...)` has an inferred type) |
| 47 | chat/file-url-utils.ts:152 | getInputAudioData → mediaType.replace, low | OK (`const mediaType = part.mediaType \|\| ...` has an inferred type) |
| 48 | video/index.ts:144 | #doGenerate → `videos.push`, low | **wrong callee/confidence** (see table) |
| 49 | utils/with-stream-error-handling.ts:17 | withStreamErrorHandling → reader.cancel, low | OK (`reader` has an inferred type) |
| 50 | embedding/index.ts:89 | #doEmbed → data.map, low | OK |

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/chat/index.ts:254 (sample #11) | `url: this.config.url({` (field `config: OpenRouterChatConfig`; `type OpenRouterChatConfig = {` at :54 in the same file) | src/chat.OpenRouterChatLanguageModel#doGenerate → `OpenRouterChatConfig#url`, medium, method | Decision A now covers `obj.field` chains whose property has a declared type, so the callee is the type's member: `src/chat.OpenRouterChatConfig#url`. Every TS type defined in the scan carries its module ID. Under the competing callback reading it would be `url`, unknown, callback. The tool's ID matches neither reading. | wrong callee | file-local type aliases are not module-qualified |
| src/chat/index.ts:790 (sample #35) | `accumulatedReasoningDetails.push(detail);` (decl :633 `const accumulatedReasoningDetails: ReasoningDetailUnion[] = [];`) | #doStream → `accumulatedReasoningDetails.push`, low, method | `Array#push`, medium (decision A, typed local). The tool resolves the same thing written as `Array<T>`: `const content: Array<LanguageModelV3Content>` → `content.push` gives `Array#push` at chat/index.ts:366. | wrong callee / wrong confidence | `T[]` shorthand annotation not treated as `Array<T>` |
| src/video/index.ts:144 (sample #48) | `videos.push({` (decl :140 `const videos: VideoModelV3VideoData[] = [];`) | #doGenerate → `videos.push`, low | `Array#push`, medium | wrong callee / wrong confidence | `T[]` shorthand |
| src/image/index.ts:90, :98, :168 (recall) | `warnings.push({` (decl :81 `const warnings: SharedV3Warning[] = [];`); `images.push(getBase64FromDataUrl(dataUrl));` (decl :163 `const images: string[] = [];`) | #doGenerate → `warnings.push` / `images.push`, low | `Array#push`, medium | wrong callee / wrong confidence | `T[]` shorthand |
| src/image/index.ts:141, :145 (recall) | `url: this.config.url({` / `headers: combineHeaders(this.config.headers(), headers),` | → `OpenRouterImageConfig#url` / `#headers`, medium | `src/image.OpenRouterImageConfig#url` / `#headers` | wrong callee | file-local type alias not module-qualified |
| src/video/index.ts:191, :195 | `abortSignal?.throwIfAborted();` (destructured parameter, `abortSignal?: AbortSignal;` at :180) | #pollUntilComplete → `abortSignal.throwIfAborted`, low | `AbortSignal#throwIfAborted`, medium | wrong callee / wrong confidence | types of destructured parameters (object-type literal) not used |
| src/chat/is-url.ts:11 | `return protocols.has(urlObj.protocol as \`${string}:\`);` (destructured parameter, `protocols: Set<\`${string}:\`>;` at :6) | isUrl → `protocols.has`, low | `Set#has`, medium | wrong callee / wrong confidence | destructured parameter type not used |
| src/completion/convert-to-openrouter-completion-prompt.ts:47 | `prompt = prompt.slice(1);` (destructured parameter, `prompt: LanguageModelV3Prompt;` at :20) | convertToOpenRouterCompletionPrompt → `prompt.slice`, low | `@ai-sdk/provider.LanguageModelV3Prompt#slice`, medium | wrong callee / wrong confidence | destructured parameter type not used |
| src/utils/with-user-agent-suffix.ts:53 | `const cleanedHeaders = removeUndefinedEntries(normalizedHeaders);` (import `'@/src/utils/remove-undefined'`; tsconfig `"@/*": ["./*"]`) | withUserAgentSuffix → `@/src/utils/remove-undefined.removeUndefinedEntries`, medium | `src/utils/remove-undefined.removeUndefinedEntries`, high | wrong callee / wrong confidence | tsconfig `paths` alias not resolved |
| src/utils/with-user-agent-suffix.ts:65 | `: userAgentSuffixParts.filter(Boolean).join(' ');` (rest parameter `...userAgentSuffixParts: string[]` at :50) | withUserAgentSuffix → `userAgentSuffixParts.filter`, low | `Array#filter`, medium | wrong callee / wrong confidence | `T[]` shorthand |
| src/chat/file-url-utils.ts:62 | `const match = dataUrl.match(/^data:[^;]*;base64,(.+)$/);` (`dataUrl: string`) | getBase64FromDataUrl → `dataUrl.match`, low | The spec does not say whether the primitive `string` maps to `String#match` | spec gap | primitive receiver type |
| src/chat/file-url-utils.ts:22 | `const stringData = data.toString();` (`data: string \| Uint8Array`, narrowed by the `instanceof` return at :17) | buildFileDataUrl → `data.toString`, low | The spec has no rule for union-typed or narrowed receivers | spec gap | union type |
| src/completion/index.ts:211 | `openrouter: OpenRouterProviderMetadataSchema.parse({` (imported module-level `const ... = z.object(...)`) | → `src/schemas/provider-metadata.OpenRouterProviderMetadataSchema.parse`, medium | No rule. The same-file form `OpenRouterChatCompletionBaseResponseSchema.extend({` (chat/schemas.ts:45) gives `OpenRouterChatCompletionBaseResponseSchema.extend`, low, so the two forms are treated inconsistently | spec gap | module-level const receiver |
| src/utils/reasoning-details-duplicate-tracker.ts:20 | `readonly #seenKeys = new Set<string>();` | caller `ReasoningDetailsDuplicateTracker##seenKeys` | The spec does not say how ES `#private` names appear in IDs | spec gap | ES private field name |

## Recall (3 functions)
- `src/chat/file-url-utils.getInputAudioData` (file-url-utils.ts:120-167): all 8 real calls found (getFileUrl, isUrl, new Set, new Error x2, getBase64FromDataUrl, mediaType.replace, OPENROUTER_AUDIO_FORMATS.join).
- `src/image.OpenRouterImageModel#doGenerate` (image/index.ts:54-190): all 14 real calls found (UnsupportedFunctionalityError, warnings.push x2, files.map, convertImageFileToContentPart, postJsonToApi, config.url, combineHeaders, config.headers, createJsonResponseHandler, NoContentGeneratedError, images.push, getBase64FromDataUrl, new Date). Five of these callees are wrong: three `T[]` receivers and two unqualified Config IDs (see the table).
- `src/utils/deterministic-stringify.sortKeys` (deterministic-stringify.ts:15-35): all 6 real calls found (Array.isArray, value.map, Object.entries, entries.sort, a.localeCompare inside the arrow, recursive sortKeys). `value.map(sortKeys)` passes `sortKeys` as a reference, and correctly produces no edge.
- No edge in these functions is something other than a call. A whole-scope script found no edge whose callee name is missing from its reported line, and no duplicate edges.

## Systematic patterns (scripted census, ordered by count)
1. **Function-valued properties of file-local config types get IDs without a module prefix:** 19 edges. They are `OpenRouterVideoConfig#url` 4, `OpenRouterChatConfig#url` 3, `OpenRouterCompletionConfig#url` 3, `OpenRouterChatConfig#headers` 2, `OpenRouterCompletionConfig#headers` 2, and `OpenRouter{Embedding,Image}Config#{url,headers}` and `OpenRouterVideoConfig#headers` 1 each. All are `type X = {...}` aliases defined in the scan (chat/index.ts:54, completion/index.ts:40, video/index.ts:29, image/index.ts:27, embedding). Type aliases imported from another module are qualified (`src/types/openrouter-chat-completions-input.OpenRouterChatCompletionsInput#push`, 5 edges). File-local ones are not. (`openrouter_v3_census2.py`)
2. **`T[]` shorthand annotations are not treated as `Array<T>` under decision A:** 15 edges, `recv.m` low where `Array#m` medium is due. They are uniqueDetails.push 1, accumulatedReasoningDetails.push/.some 3, accumulatedFileAnnotations.push 1, image warnings.push 2, images.push 1, error-response parts.push/.join 4, userAgentSuffixParts.filter 1, video warnings.push 1, videos.push 1. The `Array<T>`, `ReadonlyArray<T>` and `Set<T>` forms do resolve (8 `Array#push`, 1 `ReadonlyArray#map`, 4 `Set#has`, 3 `Set#add`). (`openrouter_v3_census3.py`)
3. **Types of destructured parameters (`({a, b}: {a: T; b: U})`) are ignored:** 4 edges. They are `abortSignal.throwIfAborted` 2, `protocols.has` 1 and `prompt.slice` 1. Plain typed parameters do resolve (`source: ReadableStream<T>` → `ReadableStream#getReader`). (`openrouter_v3_census3.py`)
4. **The tsconfig `@/*` path alias is not resolved:** 1 edge in scope. There are 79 in the whole graph; the other 78 are in e2e/test files. (`openrouter_v3_census2.py`)

Total wrong: 19 + 15 + 4 + 1 = 39 of 909, census precision 1 − 39/909 ≈ 95.7%.

## Spec gaps (counted separately, not wrong)
- **Receivers of primitive type:** 4 edges stay `recv.m` low (`dataUrl.match` 2, `str.replace` 1, `targetKey.toLowerCase` 1). The spec does not say whether `string` maps to `String#m`.
- **Union-typed or narrowed receivers:** 2 edges (`data.toString` with `string | Uint8Array`, `headers.entries` after `instanceof Headers`).
- **Receivers that are module-level consts holding zod schemas:**
  - Imported ones become dotted module IDs at medium: 14 edges, e.g. `src/schemas/provider-metadata.OpenRouterProviderOptionsSchema.safeParse`, plus `OPENROUTER_AUDIO_FORMATS.join`.
  - Same-file ones become `recv.m` at low: 3 edges.
  - The spec covers neither form.
- **Function-valued property versus typed member (`this.config.url(...)`):** whether this is a callback (unknown) or decision A (`T#url`) is still open. The 19 edges in pattern 1 are wrong under both readings, so they are counted as wrong.
- **ES `#private` names:** 2 edges use the ID `ReasoningDetailsDuplicateTracker##seenKeys`.
- **Type aliases of array types:** `messages: OpenRouterChatCompletionsInput` (an alias for an array) gives `...OpenRouterChatCompletionsInput#push`, 5 edges. The spec does not say whether aliases are expanded.
- **Root build and test config files** (`tsup.config.ts`, `vitest.*.config.ts`, 22 edges) are not named by the exclusion list. I included them, and all 4 sampled edges are correct.

## Previous findings
The in-scope edge set has the same tier counts as v2 (119/459/308/1 over `src/`), so I expected no change, and none was found.

**v2 mismatch-table rows**
| v2 row | status | v3 count |
|---|---|---|
| file-url-utils.ts:62 `dataUrl.match` (primitive `string`) | still present. Now classed as a spec gap, because the current spec still says nothing about primitives. | 2 (`dataUrl.match` at :57 and :62) |
| video/index.ts:191, 195 `abortSignal.throwIfAborted` (destructured typed parameter) | still present | 2. Pattern 3 now totals 4, adding `protocols.has` and `prompt.slice`, which v2 did not count. |
| with-user-agent-suffix.ts:53 `@/src/...removeUndefinedEntries` | still present | 1 in scope (79 graph-wide) |
| with-user-agent-suffix.ts:34 `targetKey.toLowerCase` (spec gap) | still present, still a spec gap | 1 |
| video/index.ts:198 and 18 more `OpenRouterVideoConfig#url` (spec gap in v2) | still present. Now counted wrong: the current typed-receiver rule explicitly covers `obj.field` chains, and the ID lacks the module prefix under either reading. | 19 |
| completion/index.ts:211 `...OpenRouterProviderMetadataSchema.parse` (spec gap) | still present, still a spec gap | 14 medium dotted, plus 3 same-file low |

**v2 systematic patterns**
1. tsconfig `@/*` alias unresolved: still present, 1 in scope and 79 graph-wide (unchanged).
2. Decision A not applied to some declared parameter types:
   - destructured parameters: still present, 4 (v2 counted 2);
   - primitive `string`: still present, 4 (v2 counted 3, missing `str.replace` at chat/index.ts:1293), spec gap.
   - A related pattern not reported in v2: `T[]` shorthand, 15 edges.
3. Config types defined in the scan get unqualified IDs: still present, 19 (unchanged). It moves from spec gap to wrong under the current spec.

**v2 "previous findings" carried forward (all still holding):** global namespace calls are emitted (JSON/Object/Array/console/Date, medium), zod `z.*` calls are medium, object-literal stream methods fold into the enclosing function, and chain line numbers are correct (0 line mismatches over the whole scope).
