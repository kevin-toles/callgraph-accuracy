# s-sidekiq (ruby): blind call-graph review, round 7

precision 49/50; census ≈98.35% (79 wrong of 4780 in-scope); recall: 3 missed of 59 real calls; 0 non-calls

## Scope
Tool output `final8-A/s-sidekiq.v2.json` has 13,760 edges: 13,376 from `.rb` files and 384 from `.js` files. The `.js` edges are excluded because they are not the repo's language. Of the Ruby edges, 8,596 come from paths with a `test/`, `spec/`, `examples/` or `docs/` segment and are excluded. That leaves **4,780 in-scope edges in 97 files** (`lib/` 4,442, `myapp/` 333, `bare/` 5).
- Confidence: high 1,148, medium 992, low 2,637, unknown 3.
- call_type: method 4,304, direct 255, constructor 218, callback 3.
- By tier and type: low/method 2,389, high/method 1,013, medium/method 902, low/direct 247, high/constructor 127, medium/constructor 90, high/direct 8, unknown/callback 3, low/constructor 1.

The `measured_accuracy` field was ignored.

**Sample.** `random.Random(20261113)`, stratified by tier and spread round-robin over files: low 26, high 12, medium 9, unknown 3 (all three that exist; the tier has fewer than 5). That covers 43 files.
- Spec-gap rows are judged "not wrong" and listed separately.
- 15 of the 50 sample rows fall in a spec gap: sample #1, 2, 4, 6, 10, 12, 15, 16, 19, 20, 22, 24, 30, 39 and 42.

Helper scripts are in the fanout folder, named `s-sidekiq_r7_*.py`. The census is `s-sidekiq_r7_census.py`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/sidekiq/fetch.rb:25 (**sample #9**) | `config.redis do \|conn\|` (inside `UnitOfWork = Struct.new(:queue, :job, :config) { def requeue …`) | `Sidekiq.BasicFetch#requeue` → `.redis`, low, method (and → `Sidekiq.Component#config`, high) | caller `Sidekiq.BasicFetch.UnitOfWork#requeue`; `config` is the struct member, not `Component#config` | wrong caller | open defect ruby/14: defs in a `Struct.new` block are assigned to the enclosing class |
| lib/sidekiq/fetch.rb:26 | `conn.rpush(queue, job)` | `Sidekiq.BasicFetch#requeue` → `job`, **high**, direct | caller `…UnitOfWork#requeue`; `job` is a struct accessor, not a scanned free function | wrong caller / wrong confidence | ruby/14, plus a bare name promoted to high |
| lib/sidekiq/api.rb:1445 | `raw["ex"].to_i` (in `State = Struct.new(:jid, :raw) do def executions`) | `Sidekiq.IterableJobQuery#executions` → `raw`, low, direct | caller `Sidekiq.IterableJobQuery.State#executions` | wrong caller | ruby/14 |
| lib/sidekiq/rails.rb:49 | `if ::Rails.logger.respond_to?(:broadcast_to)` | `Sidekiq.Rails` → `Sidekiq.Rails#logger`, medium | `Rails#logger`, medium (`::Rails` is the top-level constant) | wrong callee | a `::`-anchored constant is resolved lexically to the nested `Sidekiq::Rails` |
| lib/sidekiq/cli.rb:48 | `logger.info "Booted Rails #{::Rails.version} …"` | `Sidekiq.CLI#run` → `Sidekiq.Rails#version`, medium | `Rails#version`, medium | wrong callee | same |
| lib/sidekiq/middleware/i18n.rb:16 | `job["locale"] \|\|= I18n.locale` (file opens `module Sidekiq::Middleware::I18n`) | `…I18n.Client#call` → `Sidekiq.Middleware.I18n#locale`, medium | `I18n#locale`, medium. Compact nesting: `Module.nesting` is `[Client, Sidekiq::Middleware::I18n]`, neither defines a constant `I18n`, so this is `::I18n` | wrong callee | lexical lookup matches the enclosing module's own name |
| lib/sidekiq/test_api.rb:257 | `Queues.jobs_by_class[to_s]` | `Sidekiq.Job.ClassMethods#jobs` → `to_s`, **high**, direct | `Kernel#to_s`, medium, method (Kernel ruling) | wrong callee / wrong confidence | bare name matched to a definition that does not exist as a free function in scope |
| lib/sidekiq/web/helpers.rb:73 | `@@strings[lang] \|\|= config.locales.each_with_object({}) …` | `Sidekiq.WebHelpers#strings` → `config`, **high**, direct | bare `config`, low, direct (not defined on `WebHelpers`) | wrong confidence | same |
| lib/sidekiq/cli.rb:32 | `def self.instance; @instance \|\|= new` | `Sidekiq.CLI#instance` → `new`, low, direct | `Sidekiq.CLI#<init>`, high, constructor | wrong callee | open defect ruby/15 (bare `new` in a class method) |
| lib/sidekiq/client.rb:210 | `class << self; def push(item) new.push(item)` | `Sidekiq.Client#push` → `new`, low, direct | `Sidekiq.Client#<init>`, high, constructor | wrong callee | ruby/15 |
| lib/sidekiq/manager.rb:35 | `@workers << Processor.new(@config, &method(:processor_result))` | `Sidekiq.Manager#<init>` → `method`, low, direct | `Kernel#method`, medium, method | wrong callee | Kernel ruling not applied to `method` |
| lib/sidekiq/job.rb:99 | `singleton_class.instance_eval do` | `…Options.ClassMethods#sidekiq_class_attribute` → `singleton_class`, low, direct | `Kernel#singleton_class`, medium, method | wrong callee | same, for `singleton_class`, `define_singleton_method`, `singleton_methods`, `instance_variables` and `gem` |
| lib/sidekiq/rails.rb:5 | `gem "railties", ">= 7.0"` | `Sidekiq` → `gem`, low, direct | `Kernel#gem`, medium, method (RubyGems defines `Kernel#gem`) | wrong callee | same |
| lib/sidekiq/component.rb:91 | `arr.each do \|block\| block.call` (lifecycle event blocks) | `Sidekiq.Component#fire_event` → `block.call`, low, method | `block`, unknown, callback | wrong callee | open defect ruby/13: `.call` on a Proc is treated as a method call. The same construct is a callback at lib/sidekiq.rb:142, which is a C2 inconsistency |
| lib/sidekiq/cli.rb:229 | `hndlr = SIGNAL_HANDLERS[sig]; hndlr ? hndlr.call(self) :` | → `hndlr.call`, low, method | `hndlr`, unknown, callback (the values are lambdas) | wrong callee | ruby/13 |
| lib/sidekiq/metrics/query.rb:54 | `stride, keyproc = ROLLUPS[granularity] … keyproc.call(time)` | → `keyproc.call`, low, method | `keyproc`, unknown, callback | wrong callee | ruby/13 |
| lib/sidekiq/metrics/query.rb:118 | `class Result < Struct.new(…)`; `def initialize … super` | `…Query.Result#<init>` → `…Query.Result#<init>`, high, constructor | parent `<init>`: the superclass is the computed `Struct.new(…)`, so `.<init>`, low, constructor (super with an unnamed superclass). Never a self-call | wrong callee | `super` resolved to the defining class itself |
| lib/sidekiq/metrics/query.rb:116 | `class Result < Struct.new(:granularity, …)` | `Sidekiq.Metrics.Query.Result` → `Struct#<init>`, medium | caller is the scope that runs the `class` statement (`Query`'s body), not `Result` | wrong caller | open defect ruby/06 (the superclass expression's caller is the class being defined) |
| lib/generators/sidekiq/job_generator.rb:56 | `@_file_name \|\|= super.sub(/_?job\z/i, "")` (superclass `::Rails::Generators::NamedBase`) | → `.Rails.Generators.NamedBase#file_name`, medium | `.file_name`, low (`super` when the superclass is not in the scan) | wrong callee | malformed ID: a leading dot glued to a type |
| lib/sidekiq/web/config.rb:84 | `tab = Array(tab)` | (no edge) | `Kernel#Array`, medium, method | missed call | capitalized Kernel conversion functions (`Array(…)`, `Integer(…)`, `Float(…)`) emit nothing |

## Systematic patterns (wrong; scripted counts, union 79)
1. **18: Kernel methods left as bare low guesses** (`method` 4, `singleton_class` 5, `define_singleton_method` 4, `gem` 3, `singleton_methods` 1, `instance_variables` 1). The Kernel ruling makes each `Kernel#m`, medium, method. The tool applies the ruling to `raise`, `puts`, `require`, `block_given?`, `send` and `instance_variable_get`, but not to these.
2. **17: methods in `Struct.new {…}` / `Struct.new do … end` / `Data.define do … end` blocks get the enclosing class as caller** (open defect ruby/14). The blocks are fetch.rb:16–28 (`UnitOfWork`), api.rb:1444–1462 (`State`) and api.rb:46 (`QueueSummary`'s `alias_method`). This includes the `job` high/direct edge.
3. **14: `::Const.m` resolved to a nested scanned type of the same name.** `::Rails.x` becomes `Sidekiq.Rails#x` in rails.rb (8, including the `::Rails.logger =` setter), cli.rb (3), job_generator.rb (2) and rails.rb:12's default argument.
4. **11: `.call` on a verified Proc held by a parameter, block parameter or local emitted as `x.call` method/low** (open defect ruby/13). The sites are component.rb:91, cli.rb:58 and 229, config.rb:37, job_retry.rb:231 and 259, launcher.rb:98, loader.rb:34 and 51, and query.rb:54 and 93.
5. **8: bare callee promoted to high/direct with no scanned free function.** These are `to_s` ×4 (test_api.rb), `config` ×2 and `session` ×1 (web/helpers.rb), and `job` (fetch.rb, also counted in pattern 2).
6. **4: bare `new` in a class method is a low bare guess** instead of `Type#<init>` (open defect ruby/15): cli.rb:32, client.rb:210 and 214, web.rb:82.
7. **3: compact-nesting lexical error**: `I18n.*` in `module Sidekiq::Middleware::I18n` resolved to `Sidekiq.Middleware.I18n#*`.
8. **2: superclass-expression caller is the class being defined** (ruby/06): query.rb:116 and 125.
9. **2: `super` in `initialize` of a class with a computed superclass is a self-loop** (query.rb:118 and 127).
10. **1: malformed `super` callee `.Rails.Generators.NamedBase#file_name`.**

How I checked: I hand-checked every edge in patterns 1–10 (the census script prints each set). I verified the Proc-ness of each pattern 4 receiver from its source: the lifecycle and death blocks, `SIGNAL_HANDLERS` lambdas, `ROLLUPS` lambdas, `&block` captures and the `Signal.trap` old handler.

## Missed-call patterns (recall)
| function | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|
| `Sidekiq.Processor#process` (processor.rb:167–225) | 29 | 29 | 0 | 0 |
| `Sidekiq.Client#atomic_push` (client.rb:284–303) | 15 | 15 | 0 | 0 |
| `Sidekiq.Web.Config#register_extension` (web/config.rb:83–113) | 15 | 12 | 3 (`Array(tab)`, `Array(index)`, `Array(asset_paths)`) | 0 |

- Operators (`-`, `<<`), indexing and `yield` are not counted as calls. `yield` is a spec gap, listed below.
- **Repo-wide, Kernel conversion functions are never emitted.** I found 19 in-scope sites, all with no edge: `Array(` ×9, `Integer(` ×8, `Float(` ×2. One example is lib/sidekiq/systemd.rb:11, `usec = Integer(ENV["WATCHDOG_USEC"])`. Under C4 each should be at least a bare low guess, and under the Kernel ruling it is `Kernel#Integer`, medium.

## Spec gaps (counted separately, not wrong; union 1,561 edges excluding the wrong ones)
1. **637: Ruby class/module-body code caller (GOLDEN Q3, ruby/16).**
   - Constructs: `PROCTITLES = [ proc { \|me, data\| "[#{Processor::WORK_STATE.size} …" } ]` (launcher.rb:19); `get "/busy" do … end` route blocks in `Sidekiq::Web::Application` (322 edges); `SIGNAL_HANDLERS = { "TTIN" => ->(cli) { … } }` (cli.rb).
   - Tool: the caller is the type, e.g. `Sidekiq.Launcher`.
   - Open question: is the caller of class/module-body code the type, `Type#CONST` with an `implicit` `<clinit>` edge, or the file?
2. **556: receiver that is a parenless method call (GOLDEN Q6).**
   - Constructs: `cli.logger.warn …` → `.warn`; `config.redis_pool`, where `config` is an `attr_accessor` → `.redis_pool`; `Sidekiq.logger.warn` → `.warn`; `self.class.name` → `.name`.
   - Tension: SPEC's own examples (`self.client.get()` → `client.get`, `a.b.c()` → `b.c`) point to the last segment. In Ruby `a.b` is always a call, so the receiver is a "call result" (`.m`), which is what golden ruby/07 rules when the parens are explicit.
   - Open question: for parenless Ruby calls, `b.m` or `.m`?
3. **244: instance-variable receivers (GOLDEN Q4, ruby/17).**
   - Constructs: `@capsules.fetch(nm)` → `capsules.fetch`; `@callback.call(self)` → `callback.call`, low, method.
   - Open question: is the sigil dropped or kept? Is `@hook.call` a callback named `hook` or `@hook`?
4. **144: `include X`, `attr_reader :a`, `attr_accessor`, `alias_method`, `private`, `undef_method` emitted as `Module#m` medium calls (GOLDEN Q3).**
   - Construct: `include Sidekiq::Component`.
   - Open question: are these calls, and to `Module#m` or bare low guesses, or are they declarations or module dependencies with no edge?
   - Related: `method_defined?`, `private_method_defined?`, `remove_const`, `ruby2_keywords` and `singleton_class?` are bare low (18), while `const_defined?` is `Module#const_defined?`. SPEC names only Kernel methods.
5. **120: `obj.x = v` setters emitted as calls (GOLDEN Q10).**
   - Constructs: `Thread.current.name = "sidekiq.#{name}"` → `.name=`; `result.marks = fetch_marks(…)` → `result.marks=`; `self.sidekiq_options_hash = …` → `Sidekiq.Job.Options.ClassMethods#sidekiq_options_hash=`, medium. That last method is defined at runtime by `define_singleton_method`.
   - Open question: is an attribute assignment a call, and with which ID?
6. **45: `attr_*`-generated methods resolved at high.**
   - Construct: `attr_accessor :config` then `config.redis_pool` → `Sidekiq.ServerMiddleware#config`, high.
   - Open question: is a method generated by `attr_reader`/`attr_accessor` "defined in the scanned source" (high), or a generated function without a written body (medium, as for `defdelegate`)?
7. **14: constants bound to `T.new` used as typed receivers (GOLDEN Q5).**
   - Construct: `WORK_STATE = SharedWorkState.new` … `WORK_STATE.set(tid, …)` → `Sidekiq.Processor.SharedWorkState#set`, high. Also `FAILURE.incr` and `RTT_READINGS.reset`.
   - Golden ruby/07 keeps locals bound to `.new` low, and decision A is scoped to statically typed languages.
   - Open question: does constructor typing apply to a Ruby constant?
8. **6: `.call` on a handler parameter or constant lambda whose callable kind is unproven.**
   - Constructs: `death_handlers.each do \|handle\| handle.call(job, ex)` (api.rb:970); `@options[:error_handlers].each do \|handler\| handler.call(ex, ctx, self)` (config.rb:307); `LABEL_MAKER.call` (deploy.rb:34); `MEMORY_GRABBER.call(pid)` (launcher.rb:252).
   - Open question: does a `.call` through a parameter or constant of unknown type count as a callback (golden ruby/13 treats an untyped `cb` parameter that way), or does it stay a `x.call` receiver guess when the value may be any object that responds to `call`?
9. **5: class methods mixed in by `base.extend(ClassMethods)` inside `self.included`.**
   - Construct: `HardJob.perform_async("bob", 15, x)` → `HardJob#perform_async`, medium. Also `Sidekiq::ActiveJob::Wrapper.set(options)` → `Sidekiq.ActiveJob.Wrapper#set`, medium.
   - The method is defined in the scan as `Sidekiq::Job::ClassMethods#perform_async`.
   - Open question: how is a method added by an `included`-hook `extend` named, and at which tier? C2 says a medium member of a scanned type must be defined there or inherited from outside the scan, which conflicts with this.
10. **3: `alias_method :die, :exit` then `die(1)`** → bare `die`, low. Open question: does a Ruby alias resolve to its target (`Kernel#exit`) or to `Sidekiq.CLI#die`?
11. **1: bare `new` inside `module ClassMethods`** (test_api.rb:283, `instance = new`). Open question: with no class to name, what is `new` inside a module that is extended into classes?
12. **Recall side, not in the union: `yield` (53 in-scope sites, no edges).** Construct: `yield self if block_given?`. Open question: is `yield` an invocation of the block, as a `block`/callback edge, or a language construct with no edge?
