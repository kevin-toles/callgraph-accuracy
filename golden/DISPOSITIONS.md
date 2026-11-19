# Golden corpus dispositions

Every change to an `expected.json` after authoring, and every case allowed to fail (`dispositions.json`), is recorded here with its reason (SPEC.md, Change control).

## 2026-11-10: ruling "direct vs method" applied to authored expectations

SPEC did not define `direct` vs `method`, and every author raised it. The ruling (SPEC Decisions 2026-11-10) defines the label by the callee's identity. Each case's IDs, tiers and lines are unchanged; only that label was recomputed, by script, for `direct`/`method` edges in every language except Lua:
- `T#m` (not `<init>`, no `.` after `#`) → method;
- `T#m.f` (nested function) → direct;
- other named callees at medium/high → direct;
- low guesses: dotted `recv.m`/`.m` → method, bare → direct.

The Lua authors' convention (`:` method, `.` direct) already matched.

Edges changed from what the authors wrote: java 17 (bare and `this.` calls of members the authors had marked direct), kotlin 19 (same), elixir 3 (low receiver guesses). The other languages were unchanged.

## 2026-11-10: rulings "Decisions (2026-11-10, golden corpus)" applied

Each changed expectation follows a ruling made because SPEC did not decide the construct, or because the author misread a rule that SPEC already decided. Edges changed (callee/tier/label only, lines unchanged):

| Ruling | Cases | Change |
|---|---|---|
| Typed call results | go/06, cpp/09, zig/08, zig/06, kotlin/12 | `.m` low → `T#m` (high, scanned type) |
| Go types through its type checker | go/05 | `r.Len`, `.Unix`, `.Size` low → `strings.Reader#Len`, `time.Time#Unix`, `strings.Reader#Size` medium |
| Known external exports | haskell/09, elixir/14 | bare low → `Data.Maybe.fromMaybe`, `Data.Char.isDigit`, `Phoenix.HTML.html_escape` medium |
| Elixir file-level code | elixir/15 | caller `MyApp.Boot` → `lib/boot` |
| Generated functions | elixir/13 | `MyApp.NotFound.exception` / `.message` high → medium |
| Rust macro IDs keep `!` | rust/04, rust/08 | `println` → `println!` etc.; nodes_include `square` → `square!` |
| Ruby Kernel | ruby/12 | `puts` low direct → `Kernel#puts` medium method |
| C# external types as written | csharp/04, csharp/15 | `System.Exception#<init>` → `Exception#<init>`; `System.Collections.Generic.List#…` → `List#…` |
| Inherited from an external base (already decided; authoring error) | groovy/04, scala/03 | `java.lang.Thread#start` → `zoo.Worker#start` / `app.Worker#start` |

## 2026-11-10: cases added for the amendment rulings

The gate diffs of the fixes build and the final build against HEAD turned up four counterexamples. They are in SPEC Decisions (2026-11-10, amendment), and each ruling has a new fixture. These fixtures were written from the amendment text by the maintainer, who had seen the implementation, not by a blind author. Each was RED against the pre-amendment builder: its matching contract test failed before the fix.

| Ruling | Case | What it pins |
|---|---|---|
| JS/TS function types through a type alias | typescript/17-function-type-alias | `baseRender as RootRenderFunction<E>` (an imported generic alias of a function type) gives `mod.render`, direct, medium. An object-type alias is no evidence. |
| JS/TS conditional initializers and factory returns | javascript/18-conditional-factory-evidence | A conditional of an alias and a factory call, and a factory returning a function declared in its body, give direct/medium. A value branch makes the conditional no evidence. JSDoc is ignored. |
| Lua tables of external modules | lua/17-external-module-mock | A mock stored on a required external module folds into its enclosing function. The library call stays medium. |
| JS/TS `.bind` of a function (raised by the final-build gate diff, pdf.js `isValidExplicitDest`) | javascript/19-bind-of-function | `.bind` of an imported or local function declaration gives `mod.name`, direct, medium, from its own file and from importers. `.bind` on a call result is no evidence. The two `.bind` invocation edges are pinned as produced, pending question 80. |

## 2026-11-12: rulings "Decisions (2026-11-12)" and the defect fixes of the re-review cycle

Expectations changed, each by a ruling:

| Ruling | Case | Change |
|---|---|---|
| Typed call results (2026-11-10, golden corpus), which extends the parameterless rule to calls with arguments | kotlin/09-multiline-chains | `.done` (low) after `.limit(3)` → `com.acme.chain.Pipeline#done`, high. The fixture predates the ruling. |
| `.call`/`.apply`/`.bind` (2026-11-12, question 80) | javascript/19-bind-of-function | The two `.bind` invocations → `Function#bind`, method, medium. Calls through the bound bindings → their targets (`shared/util._isValidExplicitDest`, `display/api_utils.add`), high. `display/api_utils.add1` leaves `nodes_include`. |
| Typed call results (2026-11-10, golden corpus), which extends the parameterless rule to calls with arguments | java/14-multiline-chains | `.done` (low) after `.limit(3)` → `com.acme.chain.Pipeline#done`, high. The fixture predates the ruling (the Java twin of kotlin/09). |
| Typed call results (2026-11-10, golden corpus) | csharp/13-unresolved-low | `Lookup(1).Trim()` (low `.Trim`) → `System.String#Trim`, medium: `Lookup` is a scanned method declared `string`, so its result is typed by a declaration in the scan; the owner is outside it. `r.ReadLine()` on `File.OpenText` (a library signature) stays low. The fixture predates the ruling. |

Open defects fixed (their cases now pass, so their dispositions are removed): rust/06-typed-receivers, kotlin/09-multiline-chains, kotlin/13-lambda-receiver, python/12-gap-external-capitalized-function, scala/05-parameterless-chain.

Cases added. They were written by the maintainer from the ruling text after seeing the implementation, not blind. Each was RED against the previous builder: its matching contract test failed before the fix.

| Ruling | Case | What it pins |
|---|---|---|
| JS/TS local object literals fold | javascript/20-local-object-literal-folds | Two tests' `const Comp = { setup() {} }` fold into the module. `export const Top` stays named. |
| `.call`/`.apply`/`.bind` | javascript/21-call-apply-bind | Two edges for `.call`/`.apply`; `Function#bind`; calls through bound bindings reach the target; `Object.prototype.m.call`; an IIFE through `.call`; a receiver without evidence stays a guess; an imported function's member has one ID. |
| A scanned standard library is the scan's own code | ocaml/18-scanned-stdlib | Bare `print_string` and `Stdlib.failwith` resolve to the scanned `stdlib.ml` at high. Names it does not define stay `Stdlib.f`, medium. |
| Generated functions cover C/C++ macros, widened to nested expansions | cpp/19-macro-generated-functions | Functions generated directly, through nested scanned macros (`WASM_DEFINE_TYPE` → `WASM_DEFINE_OWN`, `WASM_DEFINE_VEC_OWN` → `WASM_DEFINE_VEC_BASE(…, *)`) are medium. An expression argument (`a + b`) is not expanded: low. |

Fixed defects pinned by cases added later in the cycle (h-luvit v9, h-mosaic v15, s-ktlint v11, s-zio v13, h-fs2 v15 re-reviews):

| Defect | Case | What it pins |
|---|---|---|
| C2 invented members of scanned Lua tables; stored function properties; value-field locals; forward-declared local shadowed by a nested local; own table-field aliases; two-step and inline external require chains | lua/18-undefined-members-and-value-locals | `self.isAbsolute`, `utils.dump`, alias `c` stay low guesses; `self.encode(f)` and `handler(f)` are callbacks; `url.len` and `url.format` high; `luvi.bundle#readfile`, `luvi.path#join` medium. |
| Member extensions in receiver scopes; member extension on an undetermined receiver; imported external extensions on a receiver | kotlin/18-member-and-imported-extensions | `RowScope#weight` / `ColumnScope#weight` innermost first; `Rule#toUniqueId`; `org.jetbrains.kotlin.psi.psiUtil.leaves`. |
| C2 invented members of scanned Scala types; function-type alias values | scala/19-undefined-members-and-function-aliases | `ZStream.fromEffect`, `z.bracket`, `ZIO` low; external-base, universal members keep medium; `pipe(1)` is a callback. |

Rulings of 2026-11-12 approved after the re-review cycle (let-bound call results; optional chaining), implemented in Rust, Kotlin, Java, C#, Scala, TypeScript and C++ (Swift in its own session). Changed expectations: java/14-multiline-chains, csharp/13-unresolved-low (above). Cases added:

| Ruling | Case | What it pins |
|---|---|---|
| Typed call results, let-bound call results, optional chaining | typescript/18-typed-and-let-bound-call-results | `make().run()`, `const s = make(); s.run()`, `maybe()?.run()`, `svc.with(1).run()` and a reassigned `let` → `a.Svc#run`, high; `any<Svc>()` stays `g.run`, low. |
| Typed call results, let-bound call results, optional chaining | csharp/19-typed-and-let-bound-call-results | `var s = Svc.Make(1); s.Run()`, `Svc.Make(2).With(3).Run()`, `Svc.Make(4)?.Run()` and a reassigned `var` → `P.Svc#Run`, high; `Svc.Any<Svc>()` stays `g.Run`, low. |
