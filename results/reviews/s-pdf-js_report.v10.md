# Blind call-graph review: s-pdf-js (javascript), round 10

precision 49/50; census ≈99.59% (159 wrong of 38471 in-scope); recall: 0 missed of 42 real calls; 0 non-calls

(In the sample, 47 edges are correct, 1 is wrong (#45) and 2 are spec gaps (#33, #44, a caller ID on a computed-key method). The spec gaps are not counted as wrong.)

## Scope
Tool output: `<scans>/final13-A/s-pdf-js.v2.json`, which has 76,253 edges and 18,504 nodes. In-scope edges are those whose `source_file` is `.js`/`.mjs` and has no `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment. The 208 `.py` and 12 `.ts` edges are excluded. That leaves **38,471 edges in 330 files**. By top-level directory: src 23,634; web 7,599; external 5,810 (emscripten-generated `*_nowasm_fallback.js` and other vendored code, in scope per Decisions 2026-11-09); gulpfile.mjs 1,177; extensions 235; other 16.
Confidence: high 16,472 / low 12,979 / medium 7,773 / unknown 1,247. call_type: method 19,755 / direct 12,040 / constructor 4,182 / implicit 1,247 / callback 1,247.
`measured_accuracy` in the JSON was ignored. Helper scripts are `<fanout>/s-pdf-js_r10_*.py`. The minified files were checked with a tree-sitter parse, used as a text parser only. No repo code was executed.

## Method
- **Precision sample.** Seed 20261113, stratified high 20 / low 16 / medium 9 / unknown 5, drawn from 35 files (sample file `s-pdf-js_r10_sample.json`). Minified emscripten edges (#3, 7, 8, 9, 13, 42, 46, 47, 50) were checked by locating the caller function and its own calls in the parse tree and by resolving callee declarations by scope. For example, `N=Math.imul` and `T=Math.floor` are locals inside `za`, so callback/unknown is correct. `o` is declared in the same anonymous scope as `ga`, so `JBig2.o` is correct.
- **Recall.** I checked three functions: `src/core/writer.js` `writeXFADataForAcroform` (13 calls), `web/pdf_thumbnail_viewer.js` `PDFThumbnailViewer##deletePages` (12 calls) and `src/core/font_renderer.js` `parseCmap` (17 calls).
- **Census.** Each pattern was counted by script, and each script was hand-validated on several hits.

## Mismatch table (sample and recall)
| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/scripting_api/app.js:502 | `this._send({ command: "zoom", value: "page-fit" });` | App#execMenuItem → src/scripting_api/app.App#_send, medium, method | `_send`, callback, unknown. `_send` is a stored property (`this._send = data.send \|\| null;` in superclass PDFObject, pdf_object.js:19), not a method. The JS note says "`this.x` assigned a value is a callback". | wrong callee / confidence / call_type | stored-property call treated as a method; invents `App#_send` (C2) |
| src/core/xfa/xfa_object.js:296 | `const attributes = (proto._attributes = new Set());` inside `get [_attributeNames]()` | caller XFAObject#_attributeNames | callee `Set#<init>` medium constructor is correct; the caller ID of a symbol-keyed getter is not decided | spec gap | computed-key method name |
| src/core/xfa/xfa_object.js:489 | `if (usehref.startsWith("#som(") && usehref.endsWith(")")) {` inside `[_getPrototype](...)` | caller XFAObject#_getPrototype → usehref.startsWith, low | callee is correct; the caller ID is undecided | spec gap | computed-key method name |

The recall check found no missed calls and no non-calls.

## Systematic patterns (scripted census, by count)
1. **Calls through stored properties reported as methods: 89 edges** (55 high, 34 medium). Each is written as a call through a property assigned a value (`this.#x = param`, `this.x = data.send \|\| null`, `this.x = null`, or a static block's `this._isSameOrigin = (…) => …`). The tool emits it as a `Type#x` method instead of `x`, callback, unknown. Examples:
   - `this.#onPanning?.(dx, dy)` (touch_manager.js:376, `#onPanning` set from a constructor parameter)
   - `this.#convertPixel(src, srcOffset)` (icc_colorspace.js:106, a field assigned arrows in the constructor)
   - `this._send(…)` (29 edges in scripting_api)
   - `PDFWorker._isSameOrigin(…)` (api.js:2226)
   - `this.task.onError?.(error)` → `RenderTask#onError` high (api.js:3478, where `onError = null;` is a field)

   The tool handles the same construct correctly elsewhere: 34 edges such as `this.tintFn(…)` and `this._externalCall(…)` are callback/unknown. That is a C2 inconsistency. Script: `s-pdf-js_r10_p1b.py`, a class-aware check that the member is a field/`this.x =` value in the class chain and not a method definition, plus the 7 cases listed in `s-pdf-js_r10_union.py`.
2. **Bare low `direct` callees for calls through local bindings: 34 edges.** Script: `s-pdf-js_r10_p5.py`, which resolves scopes over all 65 low-direct edges.
   - **Forward references to function-literal bindings, 19 edges.** These should be the named nested function at high. Examples: `sendTest();` at api.js:2281 before `const sendTest = () => {` at 2288, where the later call at 2297 resolves to `PDFWorker##initialize.sendTest` high; `enableActive();` at pdf_cursor_tools.js:135; `validateFileURL(file);` at app.js:901 with `var validateFileURL = function (file)` at 2691; and 16 emscripten `addOnPreRun` / `callRuntimeCallbacks` / `addOnPostRun` calls in jbig2/openjpeg. These violate C2 because resolution depends on declaration order.
   - **Locals holding a value, 15 edges.** These should be callback/unknown:
     - `var` assigned later: `__emscripten_timeout` and quickjs `S`, `V`, `W`, `ka` (9 edges)
     - destructured bindings: `checker(self, event)` at tools.js:656 is a destructured parameter; `report(…)` and `validateOptions(…)` in no-unused-custom-properties.mjs come from a top-level destructure and should be `mod.report`, callback, unknown, as the tool itself does for `createPlugin` on line 108 (3 edges)
     - for-of bindings: `listener(data)` at event_utils.js:147, `check(nsName)` at xfa/builder.js:150, `create()` at gulpfile.mjs:1818 (3 edges)
3. **Invented type IDs from computed constructor expressions: 18 edges**, all medium. The script matches `this.`, `.prototype.` or `.#` in the callee's type. Examples:
   - `new this.prototype.constructor({` → `this.prototype.constructor#<init>` (annotation.js:1955, editor.js:1884, inkdraw.js:624)
   - `new this.#PDFStreamReader(this)` → `this.#PDFStreamReader#<init>` (base_pdf_stream.js:59)
   - `new CanvasImagesTracker.#CoordsArray(…)`, `new this.win.URL(cUrl)`, `new editorType.prototype.constructor(params)`

   These invented types also type later receivers: `outlines.build(` → `this.prototype.constructor#build`, `this._fullReader._enqueue(buffer)` → `this.#PDFStreamReader#_enqueue`, `newCoords.set(…)` → `CanvasImagesTracker.#CoordsArray#set`. The receivers are unknown, so the callee should not be a medium-tier named type (C2, C5).
4. **Calls in default-parameter values become callbacks named after the callee: 14 edges.** Examples:
   - `constructor(initialState = new EvalState())` → `EvalState`, callback, unknown, instead of `src/core/evaluator.EvalState#<init>`, high, constructor (evaluator.js:5091, also 5369)
   - `verbosity = getVerbosityLevel(),` → callback instead of `src/shared/util.getVerbosityLevel`, high, direct (api.js:2137)
   - `= new Set()`, `= new RefSet()`, `= new Uint8ClampedArray(3)`, `= new Date()` in 9 more signatures

   The same name is also mis-bound later in the body: `const rgbColor = defaultColor || new Uint8ClampedArray(3);` (annotation.js:593) and `date = new Date(date);` (core_utils.js:713) are also callbacks. Script: `s-pdf-js_r10_p7.py`; these are the binding classes `undeclared`/`funcdecl` for non-minified callback edges.
5. **`.bind` on a scanned class named as the class's own member: 4 edges.** `return AES256Cipher.bind(null, this.encryptionKey);` → `src/core/crypto.AES256Cipher#bind`, medium (crypto.js:1305, 1308, 1319, 1344). The class does not define `bind`, so the ID is invented (C2). Per the `.call/.apply/.bind` ruling, the callee is `Function#bind`, medium, method.

Union of patterns 1–5: 159 edges. 1 − 159/38,471 = 99.59%. Of the sample, only #45 falls in this union.

## Missed-call patterns (recall)
- **Computed-member calls produce no edge.** Examples are `formNode[$setValue](createText(value));` (xfa/bind.js:92, where only `createText` is emitted) and `node[$getParent]()[$removeChild](node)` (bind.js:669). C4 says an unresolvable call is still emitted as a low guess. A scripted line scan finds about 414 `x[expr](…)` call sites in scope, concentrated in src/core/xfa; some of these are array-index calls. CAPABILITIES.md does not list this construct as unsupported.
- The three recall functions (42 calls) were complete.

## Spec gaps (counted separately, not wrong)
- **Method-reference `.bind`, 169 edges.** `this.#hide.bind(this)` (annotation_layer.js:2483) and `this.fetchBuiltInCMap.bind(this)` (evaluator.js:250) are emitted as `#hide.bind` / `fetchBuiltInCMap.bind`, low (150 edges). Methods of the `PDFViewerApplication` object literal account for 19 more, for example `this._cleanup.bind(this)` at web/app.js:436. Open question: is a reference to a scanned class or object-literal method a "scanned declaration" that gives function evidence under the `.call/.apply/.bind` ruling (so `Function#bind`)? Or is it a receiver guess?
- **Computed-key method names as callers, 624 edges.** For example `get [_attributeNames]()` and `[$toHTML](…)` are named `XFAObject#_attributeNames` and `…#$toHTML`. Open question: what is the member ID of a method whose key is a computed Symbol-valued expression?
- **In-place `new T(…).m()`, 36 edges.** For example `new SimpleXMLParser({ hasAttributes: true }).parseFromString(str)` (writer.js:243) and `new ImageResizer(imgData, isMask)._createImage()` (image_resizer.js:205) are emitted as `.m`, low. Open question: does "Typed call results" or decision A type a JS `new T(…)` expression used in place as a receiver? Decision A covers only the `= new T()` binding, and the in-place chain is ruled only for Rust.
- **Bundler path aliases, 32 edges.** `import { Toolbar } from "web-toolbar";` gives `web-toolbar.Toolbar#<init>`, medium. gulpfile.mjs:234 maps it to `web/toolbar.js` (and :265 to `web/toolbar-geckoview.js`). Open question: should a build-config alias with several possible targets resolve to a scanned module? The spec covers only package.json `exports`.
- **Host (DOM) globals, 18 edges.** `getComputedStyle(…)` and `createImageBitmap(…)` are bare low, direct. Elsewhere `window.getComputedStyle` is medium. Open question: are browser/worker host globals "Globals" like `globalThis.parseInt`?
- **`this.m()` where `m` is defined only in subclasses, 11 edges.** For example `this.createNewDict(…)` in MarkupAnnotation (annotation.js:1900) and `this.decodeImage(…)` in DecodeStream (decode_stream.js:115) give `MarkupAnnotation#createNewDict`, medium. The base chain is fully scanned, so C2 forbids the ID, but the ID rule gives `Type#m`. Open question: what is the callee for a call to an abstract-by-convention method in JS?
- **Members that do not exist on the typed class, 2 edges.** `this.#idManager.getNextId()` (tools.js:1070) is installed with `Object.defineProperty` under TESTING. `this.annotationEditorLayer?.updatePageIndex(…)` (annotation_editor_layer_builder.js:86) names a method AnnotationEditorLayer does not define. Open question: what is the callee for a call on a typed receiver whose type does not define the member?
- **Named function expression calling itself, 2 edges.** `promiseBody(resolve, reject);` inside `new Promise(function promiseBody(resolve, reject) {` (evaluator.js:1731, 3212) is bare low. Open question: is a named function expression's own name a named nested function?
- **Classic-script globals, 1 edge.** `canRequestBody(…)` with `/* globals canRequestBody */ // From preserve-referer.js` (extensions/chromium/pdfHandler.js:364) is bare low. Open question: do top-level functions of another scanned classic script resolve?
