# h-roda (ruby) blind call-graph review, round 7

precision 44/50; census ≈99.1% (44 wrong of 4881 in-scope); recall: 0 missed of 76 real calls; 0 non-calls

(Precision counts 6 wrong edges. The 44 that are not wrong include 5 spec-gap edges, which are counted separately and not as wrong. Recall covers the three functions checked by hand. Missed calls I found by looking elsewhere are listed under the recall patterns below.)

## Scope
- Tool output: `<scans>/final8-A/h-roda.v2.json`, 27031 edges in total: 26891 `.rb` and 140 `.js`. I left out the JS edges (139 under `www/`, 1 under `spec/`) and the 22011 Ruby edges under `spec/`.
- In scope: **4881 edges** from 166 Ruby files (4863 in `lib/`, 18 in `www/make_www.rb`).
- Confidence: high 777, medium 880, low 3215, unknown 9.
- call_type: method 4125, direct 647, constructor 100, callback 9.
- I ignored the `measured_accuracy` field.
- Sample: seed 7, quotas low 30 / medium 8 / high 7 / unknown 5, covering 30 files. All 9 unknown edges exist, so the unknown quota is 5 of 9.
- Helper scripts are in the fanout folder, prefixed `h-roda_r7_`: `load`, `q`, `at`, `sample`, `recall`, `census`, `line`, `missed`.

## Mismatch table (sample and recall)
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/roda/plugins/streaming.rb:87 | `@block.call(self)` | Stream#each → `block.call`, low, method | `@block` is assigned from the `&block` parameter at line 52, so this is a stored Proc. Expected: callee is the variable's name (`block`/`@block` is spec gap ruby/17), callback, unknown | wrong confidence / call_type | open defect ruby/13: `.call` on a Proc is treated as a method call |
| lib/roda/plugins/assets.rb:483 | `opts[:compiled_css_prefix] = j.call(:prefix, :compiled_css_route, :compiled_name)` | Assets#configure → `j`, unknown, callback | `j = lambda do \|*v\| … end` (line 411) is a local bound to a function literal, so it is a named nested function: `Roda.RodaPlugins.Assets#configure.j`, high, direct | wrong callee / confidence | open defect ruby/13: lambdas bound to locals are not named nested functions |
| lib/roda/plugins/assets.rb:475 | `opts[:css_path] = sj.call(:path, :css_dir)` | Assets#configure → `sj`, unknown, callback | `…Assets#configure.sj`, high, direct | wrong callee / confidence | same (ruby/13) |
| lib/roda/plugins/assets.rb:420 | `s = j.call(*v)` | Assets#configure → `j`, unknown, callback | caller `…Assets#configure.sj`, callee `…Assets#configure.j`, high, direct | wrong callee / confidence (and caller) | same (ruby/13) |
| lib/roda/plugins/assets.rb:477 | `opts[:compiled_css_path] = j.call(:public, …)` | Assets#configure → `j`, unknown, callback | `…Assets#configure.j`, high, direct | wrong callee / confidence | same (ruby/13) |
| lib/roda/plugins/assets.rb:480 | `opts[:js_prefix] = sj.call(:prefix, :js_route)` | Assets#configure → `sj`, unknown, callback | `…Assets#configure.sj`, high, direct | wrong callee / confidence | same (ruby/13) |
| lib/roda/plugins/middleware.rb:140 | `@mid.plugin(:not_found, &NEXT_PROC)` | Forwarder#<init> → `mid.plugin`, low, method | `mid.plugin` or `@mid.plugin` | spec gap | ivar receiver naming (ruby/17) |
| lib/roda/plugins/route_csrf.rb:244 | `@_request.on{_roda_route_csrf_failure(@_request)}` | RouteCsrf.InstanceMethods#check_csrf! → `_request.on`, low | same question | spec gap | ruby/17 |
| lib/roda/plugins/class_matchers.rb:139 | `@captures.concat(captures)` | ClassMatchers.RequestMethods#_consume_segment → `captures.concat`, low | same question | spec gap | ruby/17 |
| lib/roda/plugins/hash_branch_view_subdir.rb:68 | `remove_method(meth)` | HashBranchViewSubdir.ClassMethods#hash_branch → `Module#remove_method`, medium, method | SPEC's Kernel ruling covers only Kernel. A bare Module method is undecided | spec gap | ruby/16 q2 / non-Kernel core methods |
| lib/roda/plugins/assets.rb:369 | `CompressorNotFound = Class.new(RodaError)` | caller `Roda.RodaPlugins.Assets` → `Class#<init>`, medium, constructor | callee is correct. The caller of a constant initializer (`Assets` or `Assets#CompressorNotFound`, plus `<clinit>`) is undecided | spec gap | ruby/16 q1 |

The other 39 sample edges are correct. They include:
- bare plugin-mixin calls (`scope`, `roda_class`, `assets_opts`) kept as low bare names under C4;
- computed receivers on call results (`.cookies_opts`, `.merge`, `.assets_opts`);
- `Kernel#require` / `Kernel#send`;
- `File#exist?`, `Time#now`, medium;
- in-module high calls (`_handle_error`, `nested_params`, `_cached_template_method_lookup`);
- `register_plugin` / `opt_attr_reader` called from module bodies, with the module as caller ("caller is its location").

## Systematic wrong patterns (scripted census, `h-roda_r7_census.py`; union 44)
1. **12: lib bare calls resolved high to `def`s inside spec-file blocks.**
   - What the tool does: `h(...)`, `body(...)`, `view(...)` and `render(...)` in plugin InstanceMethods become callees `h`, `body`, `view`, `render` (high, direct). Those IDs belong to defs inside `Module.new{def h; …}` (spec/plugin/module_include_spec.rb:7), `describe … do def body` (spec/plugin/chunked_spec.rb:252), `app(:bare) do def view(s)` (spec/plugin/symbol_views_spec.rb:8) and similar.
   - Examples: `href = h(href)` at link_to.rb:68; `render(template, :locals=>locals, &block)` at part.rb:50.
   - Why it is wrong: the runtime targets are other plugins' mixin methods (`…H.InstanceMethods#h`, Render's `render`), so each call should be a low bare name (C4). A block-local test def is not visible from lib code.
2. **9: lambda-bound locals `j`/`sj` in Assets#configure.** These are all 9 unknown edges in scope. Expected `…Assets#configure.j` / `.sj`, high, direct (open defect ruby/13).
3. **7: Kernel methods called bare kept as low bare names.**
   - `method(…)` ×4: autoload_hash_branches.rb:51/54, autoload_named_routes.rb:47/50.
   - `singleton_class` and `define_singleton_method`: recheck_precompiled_assets.rb:74/62.
   - `instance_variables`: shape_friendly.rb:144.
   - Expected `Kernel#m`, medium, method (Ruby `Kernel` ruling, 2026-11-10). The same scan does give `Kernel#instance_variable_get` and `Kernel#send`, so the output is inconsistent.
4. **4: `.call` on a local/ivar statically bound to a Proc, left as a low method guess.**
   - chunked.rb:324 `@_flusher.call` (`@_flusher = lambda do` at line 293).
   - sinatra_helpers.rb:255 `@block.call` (from `&block` at 214).
   - streaming.rb:61 `@out.call` (from `each(&out)` at 85).
   - streaming.rb:87 `@block.call` (from `&block` at 51).
   - Expected callback, unknown (open defect ruby/13). Receivers whose value comes from an opts hash (`serializer.call`, `opts[:parser].call`) are not counted.
5. **3: `self.opts` inside `app.instance_exec do … end`** (path.rb:92–94) named `Roda.RodaPlugins.Path#opts`, medium. Inside the block `self` is `app`. Neither the `Path` module nor its runtime ancestors define `opts`, so the ID is invented (C2).
6. **3: `super` in a non-initialize method whose superclass is outside the scan, named `Parent#m`, medium.**
   - opts.rb:10 `Hash#initialize_copy`, opts.rb:17 `Hash#[]=`, indifferent_params.rb:53 `Rack.QueryParser#parse_nested_query`.
   - The ID-format rule says "`super` when the superclass is not in the scan" gives `.member`, low.
   - The 30+ other `super` edges in modules follow that rule. Inside `initialize`, `Parent#<init>` is correct, for example indifferent_params.rb:60.
7. **2: `Module#public` for Roda's `r.public`.** Bare `public` inside `HashPublic.RequestMethods#hash_public` (hash_public.rb:120) and `TimestampPublic.RequestMethods#timestamp_public` (timestamp_public.rb:73). There `self` is a request, not a Module. The call is the public plugin's request method, so it should be a low bare `public` (C4).
8. **2: `::CGI` typed as `Object`.**
   - h.rb:19 `unless CGI.respond_to?(:escapeHTML)` → `Object#respond_to?`.
   - h.rb:29 `CGI.escapeHTML(string.to_s)` → `Object#escapeHTML`.
   - The `CGI = Object.new` at line 21 is conditional and comes after line 19, so at runtime `CGI` here is the external `::CGI`. Expected `CGI#respond_to?` / `CGI#escapeHTML`, medium. `Object#escapeHTML` names a method Object does not have.
9. **1: bare `new` in a class method.** typecast_params.rb:332 `e = new("#{e.class}: #{e.message}")` in `def self.create` of `class Error` → `…TypecastParams.Error#new`, medium, method. Expected `…Error#<init>`, high, constructor (open defect ruby/15).
10. **1: self-edge from `super` in a computed-superclass initializer.** flash.rb:54 `super(hash||{})` in `class FlashHash < DelegateClass(Hash)` → `…FlashHash#<init>` (itself), high. Expected `.<init>`, low, constructor (the superclass is computed).

Hand checks: every pattern was checked against at least 2 source sites, or against all of them where the count is 4 or less. A line-number scan (`h-roda_r7_line.py`) found no wrong-line edges: every remaining mismatch is a `super` line or a setter.

## Missed-call patterns (recall)
- The three recall functions have every call: `SendFile.InstanceMethods#send_file` (send_file.rb:71–122, 21 calls), `Base.ClassMethods#define_roda_method` (roda.rb:98–192, 47 calls) and `Middleware.Forwarder#call` (middleware.rb:153–175, 8 calls). Forwarder#initialize (8 calls) also has all of its calls.
- Found by looking (`h-roda_r7_missed.py`):
  - **20: Kernel conversion functions never emitted.**
    - `Array(x)` ×17, for example assets.rb:853 `([file] + Array(deps))`, mail_processor.rb:446 `Array(to) + Array(cc)`, typecast_params.rb:967.
    - `::Kernel::Integer(v, 10)` / `::Kernel::Integer(v)` ×2 (typecast_params.rb:557, 561).
    - `::Kernel::Float(v)` ×1 (typecast_params.rb:574).
  - **2: `binding` (Kernel#binding) not emitted.** make_www.rb:16, 19.
  - **2: lambda invoked with `[]`.** `format[params]` at error_email.rb:68 and error_mail.rb:91, where `format = lambda do |h|`. No edge.

## Spec gaps (counted separately, not wrong; union 522 edges outside the wrong set)
- **214: ivar receivers** such as `@mutex.synchronize{…}` (cache.rb:17) → `mutex.synchronize`. Open question (ruby/17): is the ID `x.m` (property name) or `@x.m` (sigil kept)?
- **170: `Module#*` calls**: `attr_writer :roda_class` (opts.rb:6), `define_method`, `private`, `alias_method`, `class_eval`, `include`, `private_constant`, `remove_method`, … called bare where `self` is a class or module. Open question (ruby/16 q2): are these calls, and is the callee `Module#m`, `Scope#m` or a low bare name? The Kernel ruling covers only Kernel.
- **74 (single-line count; multi-line initializers such as `DEFAULTS = { :filter=>lambda{…} … }` in error_email.rb:43–60 add more): calls inside a constant initializer in a class/module body.** Example: `SCOPE_INSTANCE_VARIABLES = [:@_chunked, …].freeze` (chunked.rb:151) has caller `Roda.RodaPlugins.Chunked`. Open question (ruby/16 q1): is the caller the type or `Type#CONST`, and is there an implicit `<clinit>` edge?
- **42: setter calls.** `res.status = 412` (caching.rb:93) → `res.status=`. Open question (golden Q10): is `obj.x = v` a call?
- **33: non-Kernel core methods called bare, left as low bare names.**
  - The methods: `instance_exec(@_request, &block)` (_before_hook.rb:19) ×10, `allocate` ×5, `instance_method` ×5, `ruby2_keywords` ×8, and bare `new` in module `ClassMethods` ×5 (`new(env)._roda_handle_main_route`, direct_call.rb:18).
  - Open question: do BasicObject/Class/Module methods get a `Class#m`-style ID like Kernel's? And which type is a bare `new` in a module extended onto an unknown class?
- **4: `self.m` in a mixin module for a method the including class provides.**
  - `if host = self.host` (host_routing.rb:209) → `…HostRouting.RequestMethods#host`, medium. Also `self.content_type` (json_parser.rb:89), `self.params` (params_capturing_restore.rb:30), `self.path` (run_append_slash.rb:46).
  - Open question: a plugin module has no declared ancestry (it is included at runtime), so is `Mod#m` "inherited from a base outside the scan", or should it be a low guess?
  - Not counted: `self.class` / `RodaPlugins.warn` / `self.object_id` → `Type#m` medium. Those resolve through Object/Kernel, which every receiver has, so I read them under the inherited-external-member ruling.
- **1: methods generated by scanned metaprogramming.** `RodaPlugins.opt_attr_reader(self, :custom_matchers)` defines `custom_matchers`. `self.custom_matchers` (custom_matchers.rb:64) → `…ClassMethods#custom_matchers`, medium. The same kind of generated reader called bare (`assets_opts`, `path_classes`, `render_opts`) stays a low bare name. Open question: does the "generated functions" ruling (Elixir/C macros) extend to Ruby `define_method`/`attr_*` generators in the scan?
- **2: constants typed by an `= Object.new` initializer.** `TERM.freeze` (request.rb:74) → `Object#freeze`; `CGI.extend(...)` (h.rb:22) → `Object#extend`. Open question (golden Q5): does decision-A-style initializer typing apply to Ruby constants or locals?
- **1: constructor of a reopened external class at high.** `Rack::Headers.new` (response.rb:184) → `Rack.Headers#<init>`, high. The only scanned definition is spec_helper.rb:79 `class Rack::Headers`, which adds `must_equal` and no `initialize`. Open question: is `T#<init>` high when T is scanned but its constructor is not?
