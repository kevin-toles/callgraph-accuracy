# Blind call-graph review: s-stripe-node (typescript), round 6

precision 49/50; census ≈98.2% (46 wrong of 2568 in-scope); recall: 0 missed of 50 real calls; 0 non-calls

(Sample: 49 correct, 0 wrong, 1 spec gap (#43), which is not counted as wrong.)

## Scope
Tool output `<scans>/final13-A/s-stripe-node.v2.json` has 12,246 edges: 9,758 `.ts` and 2,488 `.js`. The `.js` edges are out of scope (not the main language). Of the `.ts` edges, 6,958 under `test/` and 232 under `examples/` are excluded. That leaves **2,568 in-scope edges in 204 files** (`src/`, `testProjects/`, `scripts/`).
- Confidence: high 1,334, medium 916, low 269, unknown 49.
- call_type: method 1,172, direct 799, constructor 506, callback 49, implicit 42.

The `measured_accuracy` field was ignored. Every high callee is in `nodes` (C1). Every caller is in `nodes`.

## Method
- **Precision:** 50 edges, stratified as high 24, medium 16, low 5 and unknown 5. Random with seed `20261113`, at most 2 per file per tier, across 34 files (`s-stripe-node_r6_sample.py`).
- **Recall:** three functions in three different files.
  - `src/StripeResource.StripeResource#_makeRequest` (StripeResource.ts:59–165)
  - `src/net/NodeHttpClient.NodeHttpClient#makeRequest` (NodeHttpClient.ts:42–127)
  - `src/Webhooks.createWebhooks.parseEventDetails` (Webhooks.ts:340–418)
- **Census:** done by script in `s-stripe-node_r6_census.py`, with helpers `s-stripe-node_r6_aliasmember.py`, `_propcall2.py`, `_recvexpr.py`, `_lowdecl.py` and `_show.py`. Each pattern was checked by hand against the source.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/RequestSender.ts:62 (sample #43) | `return clientContext?.toString() \|\| null;` | `RequestSender#_normalizeStripeContext → clientContext.toString`, low, method | Receiver is declared `string \| StripeContext \| null` (a union of two types) | spec gap | union-typed receiver |
| testProjects/types/typescriptTest.ts:38 | `httpClient: Stripe.createNodeHttpClient(),` | `testProjects/types/typescriptTest → stripe.createNodeHttpClient`, medium, direct | Binding is `import Stripe from 'stripe'`, so the name is `stripe.default.…`. The same file gives `new Stripe.StripeContext` as `stripe.default.StripeContext#<init>` (C2). | wrong callee | default-import static member drops `.default` |
| testProjects/types/typescriptTest.ts:501 | `const testDecimal = Stripe.Decimal.from('1.0');` | `… → stripe.Decimal.from`, medium, direct | `stripe.default.Decimal.from` (same binding as above) | wrong callee | same |
| src/autoPagination.ts:141 | `return this.stripeResource._makeRequest(` | `V1ListIterator#getNextPage → src/Types.StripeResourceObject#_makeRequest`, medium, method | `StripeResourceObject` is `export type … = {…}`. A TS type alias names no type of its own (2026-11-12 final5 readings), so this should be the guess `stripeResource._makeRequest`, low. | wrong callee | type-alias member named as `Alias#m` |
| src/StripeResource.ts:82 | `spec.validator(data, {headers});` | `StripeResource#_makeRequest → src/Types.MakeRequestSpec#validator`, medium, method | `MakeRequestSpec` is a type alias and `validator?:` is a function-valued property. Should be a guess or callback, not `Alias#m`. | wrong callee | type-alias member / function-valued property |
| src/Webhooks.ts:514 | `return header.split(',').reduce<…>(` | `createWebhooks.parseHeader → WebhookHeader#split`, medium, method | `header: WebhookHeader`, where `type WebhookHeader = string \| string[] \| Uint8Array`, so the guess `header.split`, low | wrong callee | type-alias member |
| src/net/FetchHttpClient.ts:237 | `this._requestTimeout.release();` | `FetchHttpClientResponse#toStream → RequestTimeout#release`, medium, method | `type RequestTimeout = { release: () => void; … }` is a file-local alias with a function-valued property. Not `RequestTimeout#release`, which is also unqualified although the type is in the scan. | wrong callee | type-alias member |
| src/StripeEventNotificationHandler.ts:154 | `return await this.fallbackCallback(` | `BaseEventNotificationHandler#dispatchEvent → …BaseEventNotificationHandler#fallbackCallback`, medium, method | `private fallbackCallback: FallbackCallback` is a stored property holding a function, so `fallbackCallback`, callback, unknown | wrong callee / call_type | CAPABILITIES open defect `typescript/03` (function-valued props as `this.f()`) |
| src/stripe.core.ts:1202 | `this._requestSender = Stripe._requestSenderFactory(this as any);` | `Stripe#<init> → src/stripe.core.Stripe#_requestSenderFactory`, high, method | `private static _requestSenderFactory: RequestSenderFactory = …` is a property holding a function, so `_requestSenderFactory`, callback, unknown | wrong callee / call_type | same open defect |
| src/net/FetchHttpClient.ts:200 | `… = await this._fetchFn(` | `FetchHttpClient#makeRequest → …FetchHttpClient#_fetchFn`, high, method | `private readonly _fetchFn: FetchWithTimeout`, so `_fetchFn`, callback, unknown | wrong callee / call_type | same open defect |
| src/RequestSender.ts:603 | `? new TextEncoder().encode(data).length` | `RequestSender#_getContentLength → .encode`, low, method | `TextEncoder#encode`, medium, method (typed call result: the receiver is `new TextEncoder()`). The tool already gives `TextEncoder#encode` for a local bound to `new TextEncoder()`. | wrong callee / confidence | in-place `new T().m()` not typed |
| src/autoPagination.ts:513 | `}).then((shouldContinue) => {` (receiver `new Promise((next) => {…})`) | `…handleIteration → .then`, low, method | `Promise#then`, medium, method | wrong callee / confidence | same |
| testProjects/bun/index.ts:44 | `throw new stripe.errors.StripeError({` | `testProjects/bun → stripe.errors.StripeError#<init>`, medium, constructor | `stripe` is a local (`const stripe = new Stripe(…)`) of an out-of-scan type. The receiver type is unknown, so this is a low guess, not a medium package path. | wrong confidence | local receiver path read as a module path |
| src/RequestSender.ts:319 | `HttpClient.CONNECTION_CLOSED_ERROR_CODES.includes(error.code)` | `RequestSender#_shouldRetry → src/net/HttpClient.HttpClient.CONNECTION_CLOSED_ERROR_CODES.includes`, medium, direct | `static CONNECTION_CLOSED_ERROR_CODES: string[]` is declared, so `Array#includes`, medium, method. The emitted ID is invented (C2). | wrong callee / call_type | typed static field not used |
| src/Webhooks.ts:456 | `platformFunctions.secureCompare.bind(platformFunctions, expectedSignature)` | `validateComputedSignature → secureCompare.bind`, low, method | The receiver resolves to the scanned method `PlatformFunctions#secureCompare`, so `Function#bind`, medium, method (2026-11-12 `.call/.apply/.bind`) | wrong callee / confidence | `.bind` on a typed method reference |
| src/resources/V2/Core/Events.ts:18 | `response.data.map(this.addFetchRelatedObjectIfNeeded.bind(this))` | `EventResource#list.transformResponseData → addFetchRelatedObjectIfNeeded.bind`, low, method | `Function#bind`, medium, method | wrong callee / confidence | same |
| src/RequestSender.ts:182 | `res.toJSON().then(` | `RequestSender#_jsonResponseHandler → .then`, low, method | `res: HttpClientResponseInterface` has `toJSON: () => Promise<any>`, and the tool resolves `res.toJSON()` itself. So `Promise#then`, medium. | wrong callee / confidence | CAPABILITIES open defect `typescript/05` (parameterless member as receiver stays low) |

## Systematic patterns (scripted counts, union = 46 wrong of 2,568)
1. **19 — Default-import static members drop `.default`.** These are in `testProjects/types*/typescriptTest.ts` with `import Stripe from 'stripe'`.
   - Calls: `Stripe.createNodeHttpClient` (7), `Stripe.createNodeCryptoProvider` (3), `Stripe.StripeEventNotificationHandler.withoutVerification` (3), `Stripe.createSubtleCryptoProvider` (2), `Stripe.createFetchHttpClient` (2) and `Stripe.Decimal.from` (2). All are emitted as `stripe.<member>`.
   - In the same files, `new Stripe(…)`, `new Stripe.StripeContext` and `new Stripe.CustomerResource` are `stripe.default…`. The same binding resolves two ways, which violates C2.
   - The `import Stripe = require('stripe')` file (cjs-ts), whose binding is the module itself, is correctly excluded.
2. **9 — Members of scanned TS type aliases named `Alias#m` (medium).**
   - `src/Types.StripeResourceObject#_makeRequest` ×3, `src/Types.MakeRequestSpec#validator`/`#transformResponseData` ×2, `RequestTimeout#release` ×2, `RequestTimeout#guard` ×1 and `WebhookHeader#split` ×1.
   - The final5 readings say a TS type alias names no type: these should stay guesses, and the function-valued properties should be callbacks.
   - The tool itself leaves other alias-typed receivers as guesses (`this.signature.verifyHeader` with `WebhookSignatureObject`, `this._stripe._platformFunctions.tryBufferData` through `this: StripeResourceObject`).
3. **6 — In-place `new T(…).m()` left as `.m` low.** `new TextDecoder('utf8').decode` ×3, `new TextEncoder().encode` ×2 and `new Promise(…).then` ×1.
4. **5 — Function-valued class properties called as methods (open defect typescript/03).** `fallbackCallback`, `preHandleCallback`, `_fetchFn` and `Stripe._requestSenderFactory` ×2 (core and esm.node).
5. **3 — `new <local>.errors.StripeError(…)` named as a package path at medium** (bun, mjs-ts, cjs-ts `stripeNew`). The receiver is a local instance of an out-of-scan type.
6. **2 — `.bind` on a scanned method reference left as a receiver guess** instead of `Function#bind`.
7. **1 — Invented static-field ID** `src/net/HttpClient.HttpClient.CONNECTION_CLOSED_ERROR_CODES.includes`. The field is declared `string[]`.
8. **1 — Typed parameterless call result left low** (`res.toJSON().then`, open defect typescript/05).

## Missed-call patterns (recall)
None of the 50 real calls in the three recall functions was missed: `_makeRequest` has 23, `NodeHttpClient#makeRequest` 17 and `parseEventDetails` 10. No edge was a non-call. Of those edges, `_makeRequest`'s lines 82 and 115 have wrong callee IDs (pattern 2), but the calls are present.

## Spec gaps (25 edges, not counted as wrong)
1. **12: a function-typed property signature in an interface, called through a typed receiver.** `export interface HttpClientResponseInterface { getHeaders: () => ResponseHeaders; toJSON: () => Promise<any>; … }` with `res.getHeaders()` is emitted as `src/net/HttpClient.HttpClientResponseInterface#getHeaders`, high, method. Open question: SPEC does not say whether a call of an interface member declared as a function-typed property (not a method signature) is an `I#m` method call (the body-less member rule) or a call through a stored property holding a function (callback, unknown).
2. **4: receiver typed by an intersection that contains a mapped utility type.** `prepareOptions(...)` returns `Omit<WebhookTestHeaderOptions, …> & { cryptoProvider: CryptoProvider; generateHeaderString: (signature: string) => string; … }`. This affects `preparedOpts.cryptoProvider.computeHMACSignature(…)`, `preparedOpts.generateHeaderString(signature)` and the async pair, all emitted as low guesses. Open question: SPEC says a mapped utility type names no type. It does not say whether an intersection with an object type literal gives the literal's member declarations (`CryptoProvider`) to a property chain.
3. **3: primitive declared types.** `_coefficient: bigint` with `this._coefficient.toString()` is emitted as `bigint#toString`, medium, while `header: string` gives `String#split`. Open question: SPEC does not say how a declared primitive type (`bigint`, `string`, `number`) is named in a `T#m` ID.
4. **2: union-typed receivers.** `optsContext?: string | StripeContext | null` with `optsContext.toString()` gives `optsContext.toString`, low. Open question: SPEC covers `T?` / `T | undefined`, but not a declared union of two or more non-null types that both define the member.
5. **3: call result of a call through a function-typed value.** `authenticator(request).then(…)` (with `authenticator: RequestAuthenticator`, where `type RequestAuthenticator = (request) => Promise<void>`) and `asyncIteratorNext().then(…)` (with parameter `asyncIteratorNext: () => Promise<IteratorResult<T>>`) are emitted as `.then`, low. Open question: SPEC does not say whether "a declared return type in the scan" (Typed call results) covers the return type written in the function type of a callback parameter or alias.
6. **1: ambient declaration.** `declare const endpointFetch: EndpointFetch | undefined;` with `await endpointFetch(endpointFetchRequest)` is emitted as `endpointFetch`, low, direct. Open question: SPEC's JS/TS module-level binding rule does not say whether an ambient `declare const` (a runtime-provided global, not a binding the module defines) is `mod.name` under the Function-type rule, a global (`globalThis.name`), or a bare unresolved name.

The exact ID form for a constructor on an unknown receiver path (`new stripe.errors.StripeError`, pattern 5) is also undecided. Only the confidence is judged wrong there.
