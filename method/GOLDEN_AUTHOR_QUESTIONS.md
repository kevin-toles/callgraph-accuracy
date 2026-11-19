# Spec questions raised by the golden-corpus authors (2026-11-10)

Each was raised by an author who saw only SPEC.md. Each needs a disposition under SPEC change control (ruling, or "spec already decides: <rule>").

## python, ruby
1. Python `super().__init__(x)`: an edge for `super()` itself (`builtins.super`) besides `Parent#<init>`? Same for `super().m()` with the parent outside the scan. (python/14 spec_gap)
2. Python decorators: is `@trace` a call at definition time; caller module or decorated function; is applying the returned wrapper a callback; which line? (python/15 spec_gap)
3. Ruby class/module-body code: caller of `ORIGIN = Struct.new(...)` — `Geo` or `Geo#ORIGIN` (+ implicit from `<clinit>`)? Are `attr_accessor`/`include` calls? (ruby/16 spec_gap)
4. Ruby ivar receivers: `@client.post` → `client.post` or `@client.post`; `@hook.call` callback named `hook` or `@hook`? (ruby/17 spec_gap)
5. Typed receivers in Python/Ruby: decision A is scoped to statically typed languages, but the JS note allows `= new Foo()` typing. Author read Python/Ruby literally: `x = Foo(); x.m()` low (python/05, ruby/07).
6. Ruby "last receiver segment": `a.b.c` — in Ruby `a.b` is a call, so receiver of c is computed (`.c`)? Fixtures use explicit parens.
7. Ruby implicit Object ancestry: author treated the external-ancestry list as complete (bare unresolved calls stay low).
8. Ruby builtins: no Kernel naming rule (`puts`, `require`); author made `puts` a low bare guess.
9. Python `__init__` definition ID: SPEC states `Type#<init>` explicitly only for Ruby/PHP; author used `C#<init>`.
10. Ruby setter rule placement (`Type#x=` under "code outside a method body"); whether `obj.x = v` is a call is undecided.

## haskell, ocaml (fixtures NOT syntax-checked: ghc/ocaml not installed)
11. Haskell operators: is an operator application an edge (`+`, scanned `<+>`, section `(+ 1)`); ID/call_type? Do `$`/`&` get their own edge? (haskell/16 spec_gap)
12. OCaml operators: `+`, scanned `+++`, `|>`, `@@` edges? Do `x |> f` / `f @@ x` call f? Definition ID of `let ( +++ )`? (ocaml/15 spec_gap)
13. OCaml top-level value let: caller of `let default_path = load "…"` — module or `config.default_path`? Also inside `module M = struct … end`. (ocaml/16 spec_gap)
14. OCaml `inherit counter`: superclass ctor call? caller? class `val` initializers? (ocaml/17 spec_gap)
15. COUNTEREXAMPLE (change-control (a)): SPEC resolves Stdlib before the innermost external local open, but `let open Float in abs x` calls `Float.abs` at runtime.
16. Headerless Haskell file is module `Main` in the language; SPEC names it after the file.
Author choices to confirm: external import lists qualified with the module (`Data.List.sort`); scanned qualified alias `S.f` → defining ID; bare `show` with in-scan instance stays `Prelude.show`; OCaml class IDs `objs.counter#m`; functor application = module binding, no edge; record-field function call callee = field name.

## scala, groovy (NOT compiled: no scalac/groovy/JVM)
17. Scala case-class `Point(0, 0)`: data construction (no edge), `Point#<init>` constructor, or `Point#apply` method (high without a written definition?). (scala/16 spec_gap)
18. Scala class-body statement (primary-constructor code): caller `Type#<init>` or `Type`? (scala/17 spec_gap)
19. Scala 3 top-level def: `app.greet`, `app.Greet#greet` or `app.Greet$package#greet`; caller of a top-level val initializer? (scala/18 spec_gap)
20. Groovy property read through a declared getter (`conf.store` → `getStore()`): edge or field access? Also generated getters. (groovy/16 spec_gap)
21. Groovy default imports are wildcard imports: the ">1 on-demand import → low" rule read literally makes every Groovy type low; author counted only explicit on-demand imports.
22. Honest-low (several wildcard imports) vs C1 when the scan defines the name exactly once: author assumed C1 wins (scala/14).
23. Getter receivers (Decisions 2026-11-09) vs ObjC "dot-syntax property access is not a call".
24. Enum-constant rule names only Java; author applied it to Groovy.
25. call_type direct vs method undefined: author used method for any receiver (written or implicit this), direct for nested functions and unresolved bare names.
26. Confidence of implicit edges unspecified (author: high when the field is in the scan).
27. `super.m()` with external superclass → `.m` low while bare `m()` → medium (inconsistency).

## php, rust (PHP NOT syntax-checked: php not installed; Rust passes cargo check)
28. PHP namespaced builtin: inside `namespace App;` unqualified `strtoupper($s)` → `strtoupper` or `App.strtoupper`; low or medium? (php/15 spec_gap)
29. `Option<T>#unwrap` (Decisions 2026-10-29 example) vs "generic type arguments are dropped from every ID": author used `Option#unwrap`.
30. direct vs method undefined: author used method for every `Type#m`/`recv.m`/`.m` incl. static `Cls::m()` and `Type::assoc()`; direct for free and nested functions. Rust `T::new()` → method. (most-cited question across authors)
31. PHP `parent::__construct` with external parent: superclass-ctor rule (`Parent#<init>`) vs "super with superclass not in scan → `.member`": author applied the specific rule.
32. Rust macro callee ID `println` vs `println!`; tier of external macros (author: no `!`, std medium, macro_rules! in scan high).
33. PHP builtins: literal tier text makes them low, other languages make builtins medium (author: low, global namespace).
34. PHP `$` kept in receiver/callback names? (author dropped it)
35. `T#<init>` high for a scanned class without an explicit constructor? (avoided)
36. Rust auto-deref through a user Deref runs `Guard#deref` without a written call: implicit edge? (author: no edge)
37. Rust module-level const/static initializer: caller `crate::config`, no implicit edge (author's reading).
38. Parameterless-member rule implies `storeFor(2)->find()` stays `.find` low, while Rust bindings take an in-scan associated function's declared return type: intended asymmetry?

## c, cpp (all clang-checked)
39. C X-macros included inside a function body: caller (function vs fragment file), edges from expansion/token pasting and their line, are `X(...)` macro edges? (c/12 spec_gap)
40. libc calls (`strlen`, `malloc`) declared only in system headers: medium or low; bare ID; `memcpy` macro under _FORTIFY_SOURCE? (c/13 spec_gap)
41. Honest-low (several wildcard imports) vs C++ using-directive resolution (ComPtr with both namespaces in the scan).
42. Callback vs typed receiver with operator(): author treated std::function / fn pointers as callbacks, user functors as `T#operator()`.
43. Computed receivers: `b.add(1).add(2)` → `.add` low although the return type is declared in the scan; Rust-only return-type rule.
44. Undefined: implicit-edge confidence; implicit edge for `int x = 0;` (no call); implicit default ctor tier; `T x(args);` as a constructor edge; `TEST_F(...)` macro edge or declaration head (author: declaration); bare call in a class with an out-of-scan base: inherited member or free function.

## csharp, go (C# NOT compiled: no .NET; Go vetted)
45. Go `f := func(){…}`: general named-nested rule (`pkg.F.f`, high) vs Go note (`pkg.F$1`, callback)? (go/10 spec_gap)
46. Go range-over-func: edge for `seq(yield)`? kind? caller of loop-body calls? (go/17 spec_gap)
47. Short variable declarations typing locals (`a := &Dog{}`, `b := NewDog()`), C# `var x = Make()`? (go/18 spec_gap)
48. C# extension methods: `App.TextExt#Shout` (runtime) vs `App.Note#Shout` (decision A, forbidden by C2); LINQ. (csharp/17 spec_gap)
49. C# property read with user getter: edge to `Type#Prop` (and `Type#Prop=` on assignment)? (csharp/18 spec_gap)
50. Go closures: general fold rule vs Go note `pkg.F$1` (author followed Go note).
51. C4 "never dropped" vs "silence = no call or coverage note" when a package fails to type-check (go/16 assumes edges required).
52. Author choices: C# attributes are declarations; C# static ctor = `<clinit>`; single `using` qualifies an external type; Go embedding = superclass rule.

## java, kotlin (Java javac-checked; Kotlin NOT compiled)
53. Java functional-interface calls `f.apply(s)` / `h.handle(s)`: decision A typed call vs callback rule; `Runnable r = () -> …` named nested? (java/18 spec_gap)
54. Kotlin stdlib default imports: `println` → `kotlin.io.println` medium or bare low; stdlib extension IDs (`forEach`, `uppercase`, `apply`, `let`, `buildMap`, `by lazy`). (kotlin/16 spec_gap)
55. Kotlin top-level property initializer caller (`com.acme.top.registry` / `TopKt#registry` / module) and implicit edge? (kotlin/17 spec_gap)
56. Author conventions: no written receiver = direct, written receiver (incl. this./super./Type.) = method; implicit edges high; in-scan class without a written constructor → `#<init>` high.
57. Avoided: bare/this. call to a method inherited from an external base (`Type#m` vs `Base#m`); unbounded Java type variable; `new T().m()`; untyped local bound to a call result; implicit edge for `int x = 5`; Kotlin enum constants. **Decided 2026-11-12 (untyped local bound to a call result):** typed by the callee's declared return type; see SPEC Decisions 2026-11-12.

## objc, zig (ObjC clang-checked; Zig NOT checked: no zig)
58. ObjC C function/macro declared only in an SDK header (`NSLog`, `printf`, `MAX`): low or medium; `MAX` macro when its #define is not visible? (objc/17 spec_gap; same as Q40)
59. Zig `const g = struct { fn g… }.g;`: named nested, alias, or callback? (zig/14 spec_gap)
60. Zig unannotated `const a = Point.init(1)` / `Point{…}` typing the binding? (zig/16 spec_gap; cf. Q47)
61. Zig qualifier for `src/geo/shapes.zig`: `shapes`, `geo.shapes`, `geo/shapes`; file-scope caller? Also the Zig note ("file-qualified") vs the top-level rule listing "Zig file scope" among unqualified languages. (zig/17 spec_gap)
62. Zig methods of the anonymous struct returned by an in-scan `fn Stack(comptime T) type`; is `Stack(u8)` an edge? (zig/18 spec_gap)
63. Author resolutions to confirm: `std.AutoHashMap(u32,u32)` is a type (no edge); decl literals `.init()` via result type; `[super m]` → `Base#m` when base in scan.

## lua, elixir (checked with tree-sitter grammars; no interpreters)
64. Lua top-level `local X = Base:extend()`: static identity (superclass rule) or nameless under the 2026-11-10 "local bound to a call result" clause? What does `X.super.new(self)` resolve to? (lua/14 spec_gap) — NOTE: the ruling's call-result clause was meant for function-local tables; top-level locals are `mod.T#f` regardless.
65. Lua module ID of a file no require string names. (lua/15 spec_gap)
66. Elixir calls inside `quote` in a macro: edge? caller? high or low for a function only an expansion defines? module-body macro invocation: edge, direct or macro? (elixir/12 spec_gap)
67. Elixir `defdelegate`: edge from generated function to target; call_type; line? (elixir/18 spec_gap)
68. Records ruling wording: `require Record` alone permits only `Record.defrecord`, not the bare form (wording fix).
69. call_type conventions: Lua `:` = method, `.`/bare = direct; Elixir every call direct (macro defined only for C/C++/ObjC/Rust).
70. Elixir "code outside any module → file's module" undefined for zero or several modules in a file.
71. Derivations to confirm: Lua entry file at require root named `main`; unscanned Lua require → `json#decode`; Kernel functions `Kernel.<name>` medium.

## javascript, typescript (node --check)
72. JS `var X;` later `X = function(){}` at top level: function-literal evidence (mod.X, direct, high; inner caller mod.X) or no evidence? (javascript/16 spec_gap)
73. JS/TS note says decision-A typed receivers give `Foo#m` "(medium)" vs high tier for in-scan types (author: high).
74. Alias tier: "Medium, not high: matched a binding" vs alias of a scanned function (author: high, it resolves to the definition).
75. call_type for global namespace functions (`JSON.stringify`, `console.log`), object-literal/namespace members, static `Type.m()`: author chose direct for dotted IDs, method for `Type#m`.
76. Implicit-edge tier; implicit edge for a literal-only initializer.
77. `module.exports = fn` → `mod.default` vs C1 when fn is a declared function/class (author: the declaration's own ID).
78. TS receivers of primitive/array type (`s: string; s.trim()`): `string#trim` medium vs `s.trim` low.
79. Bare global constructors (`new Map()` → `Map#<init>` or `globalThis.Map#<init>`) and IIFE call edges.
80. (2026-11-10, raised by the maintainer while writing javascript/19-bind-of-function.) The ID of a call of a function value's own method (`f.bind(…)`, `f.call(…)`, `f.apply(…)`). Today the builder names it two ways. On an imported function it's `shared/util._isValidExplicitDest.bind`, direct, medium. On a local declaration it's `display/api_utils.add#bind`, method, medium. Options: `Function#bind` (the builtin, as `string#find` is for Lua), `mod.f.bind` direct, or `mod.f#bind` method. javascript/19 pins today's output until this is decided. **Decided 2026-11-12** (SPEC Decisions 2026-11-12, `.call`/`.apply`/`.bind`): `Function#call`/`#apply`/`#bind`, method, medium, plus the target edge for `.call`/`.apply`.
