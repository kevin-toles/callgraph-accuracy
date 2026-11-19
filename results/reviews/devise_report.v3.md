# devise (ruby) — call-graph review (v3)

Summary: precision 50/50; recall: 0 missed of 47 real calls; 0 non-calls

**Scope.** The output has 10315 edges. 2781 are in scope: .rb files outside test/ and the other excluded dirs, plus lib/devise/test/, guides/ and lib/generators/templates/. By confidence: low 1444, medium 699, high 638, unknown 0. By call_type: method 2752, constructor 29.

**Precision sample.** I drew 50 edges with a fixed seed (2026), stratified roughly in proportion to the tier counts: 11 high, 13 medium, 26 low. The tool emitted no unknown-confidence edges. The sample covers 30 files. Every sampled edge is correct per the spec. I checked each one for:
- a real call
- the right caller
- the right callee
- the right confidence tier
- the right line, including chain lines such as failure_app.rb:79 `.tap` and confirmable.rb:214 `.nil?`

Notable correct cases in the sample:
- **Inherited from a scanned grandparent:** rememberable.rb:30 → `Devise.Strategies.Authenticatable#remember_me` (high).
- **Methods from included modules:**
  - helpers.rb:218 → `Devise.Controllers.StoreLocation#stored_location_for` (high)
  - mongoid generator :20 → `Devise.Generators.OrmHelpers#model_exists?` (high)
- **External ancestor named on the scope:**
  - rails.rb:11 → `Devise.Engine#config` (medium)
  - devise_generator.rb:16 → `Devise.Generators.DeviseGenerator#hook_for` (medium)
- **Unknown receivers:**
  - Block parameter: timeoutable.rb:10 → `warden.request` (low)
  - Local: authenticatable.rb:231 → `record.authenticatable_salt`
  - Parameter: helpers.rb:179 → `context.respond_to?`
  - Instance variable: mapping.rb:146 → `constraints.merge!`

Statistically, 50/50 only bounds precision at about 94% or better (95% one-sided, rule of three). To tell 95% from 99%, I also ran scripted checks over all in-scope edges. They found 9 wrong edges, listed below with their root causes. That is about 99.7% in scope if the spec-gap patterns are not counted as errors. Counting the in-scope spec-gap patterns 1 and 2 below as errors as well (132 edges) gives about 94.9%.

**Recall.** I checked 3 functions, all different from v2.
- `Devise.Strategies.Rememberable#authenticate!` (strategies/rememberable.rb:21-34): 13 real calls, 13 found, 0 non-calls.
  - The inherited `mapping` resolves to `Devise.Strategies.Base#mapping` (high), and `validate` / `remember_me` to `Authenticatable#…` (high).
  - The Warden methods `cookies`, `pass` and `success!` are `Devise.Strategies.Rememberable#…` (medium).
  - The local `resource` gives no edge, and `resource.after_remembered` is low.
- `Devise.FailureApp#scope_url` (failure_app.rb:155-180): 15 real calls, 15 found, 0 non-calls.
  - The local `route` (`route = route(scope)`, then `context.respond_to?(route)`) correctly gives only the call on :162.
  - The local `context` gives `context.respond_to?` and `context.send`.
  - `root_url` → `Devise.FailureApp#root_url` (medium).
- `Devise.Models.Confirmable#confirm` (models/confirmable.rb:79-103): 19 real calls, 19 found, 0 non-calls.
  - The setters are `#confirmed_at=`, `#email=` and `#unconfirmed_email=` (medium).
  - Both `save` calls are present.
  - The local `saved` gives no edge.

## Mismatch table

No sampled edge was wrong. The rows below come from the scripted checks and the previous-findings checks, plus spec gaps.

| file:line | source line | tool said | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/devise/rails/routes.rb:246 | `rescue NameError => e` | ActionDispatch.Routing.Mapper#devise_for → `e`, low | `e` is a rescue-bound local, so there is no call | not a call | rescue binding `=> e` not registered as a local |
| lib/devise/rails/routes.rb:251 | `rescue NoMethodError => e` | → `e`, low | no call | not a call | same |
| lib/devise/rails/routes.rb:252 | `raise unless e.message.include?("undefined method `devise'")` | → `e`, low; → `.message`, low | there is no call to `e`. The member call is `e.message` (low). `.include?` is correct | not a call + wrong callee | same: the local is treated as a call, so the receiver becomes "computed" |
| lib/devise/models.rb:32 | `class << mod; attr_accessor :available_configs; end` | Devise.Models#config → `mod`, low | `mod` is the method parameter (`def self.config(mod, *accessors)`) and the target of a singleton class, not a call | not a call | `class << x` target is treated as a bare call |
| lib/devise/strategies/database_authenticatable.rb:24 (×2) | `Devise.paranoid ? fail(:invalid) : fail(:not_found_in_database)` | → `Kernel#fail`, medium ×2 | `fail` is `Warden::Strategies::Base#fail`, inherited from the external ancestor, so the callee is `Devise.Strategies.DatabaseAuthenticatable#fail` (medium) | wrong callee | Kernel builtin-name lookup wins over the external-ancestor rule |
| lib/devise/omniauth/config.rb:8 | `super("Could not find a strategy with name …")` (in `def initialize`, `class StrategyNotFound < NameError`) | → `NameError#initialize`, medium, method | `NameError#<init>`, constructor ("Superclass constructor calls (`super(...)`) → `Parent#<init>`, constructor") | wrong callee + wrong call_type | `super` inside `initialize` is not mapped to `<init>` |
| lib/devise/controllers/helpers.rb:287 | `super "Devise could not find the `Warden::Proxy` instance on …"` (`MissingWarden < StandardError`) | → `StandardError#initialize`, medium, method | `StandardError#<init>`, constructor | wrong callee + wrong call_type | same |
| models/confirmable.rb:67, models/database_authenticatable.rb:45 | `super` inside `def initialize` of a concern module | → `.initialize`, low, method | the ancestor is unknown, so `.member` applies. Following the constructor rule, the callee would be `.<init>`, constructor | spec gap | the spec does not cover `super` in an initializer whose parent is unknown |
| (28 in-scope edges) e.g. mapping.rb `def initialize` body | — | caller `Devise.Mapping#initialize` | constructor calls name `Devise.Mapping#<init>` (133 high `#<init>` callee edges in the whole output), but no edge has caller `#<init>`, so constructor calls never connect to the initializer body | spec gap | the spec does not say whether a Ruby `initialize` definition's ID is `#<init>` |
| lib/devise/rails/routes.rb:377 (17 edges in lib) | `resource :session, only: [], controller: controllers[:sessions], path: "" do` | ActionDispatch.Routing.Mapper#devise_session → `resource`, low | The scan reopens `module ActionDispatch::Routing` / `class Mapper`, an external class. `resource`, `get`, `post`, `constraints`, `match` and `scope` are Mapper's own external methods. Under the stated "ancestry reaches outside the scan → `Scope#m` medium" behaviour, the callee is `ActionDispatch.Routing.Mapper#resource` (medium) | spec gap (likely wrong) | a reopened external class is treated as fully scanned |
| app/controllers/devise/passwords_controller.rb:4 (114 edges in app/) | `prepend_before_action :require_no_authentication` | → `prepend_before_action`, low | `DeviseController < Devise.parent_controller.constantize` is a computed superclass. The ancestry is external but not named, so either low/bare or `Devise.PasswordsController#prepend_before_action` (medium) could be argued | spec gap | computed superclass expression |
| lib/devise/strategies/rememberable.rb:67 (170 in scope) | `Warward::Strategies.add(:rememberable, Devise::Strategies::Rememberable)` | caller `<global>` | the spec gives no caller for top-level Ruby code | spec gap (unchanged) | — |
| lib/devise/models.rb:83 | `Devise::ALL.index(s) \|\| -1` | → `Devise.ALL#index`, medium | ALL is an Array constant, not a type | spec gap (unchanged) | — |
| lib/devise.rb:493 (6 edges) | `warden_config.scope_defaults mapping.name, …` | → `warden_config`, low | the reader is generated by `mattr_accessor :warden_config` in module Devise. The same reader called as `Devise.warden_config` is `Devise#warden_config` (medium). The bare form is "not found in scan", so low matches the tiers, but it is inconsistent | spec gap | methods generated by mattr / delegate |

(The rememberable.rb:67 row should read `Warden::Strategies.add(...)`; the source is unchanged from v2.)

## Systematic patterns

All counts are scripted over the whole output (10315 edges) unless they say "in scope".

1. **A reopened external class is treated as fully scanned.** Bare calls inside it, and inside its scanned subclasses, stay bare at low instead of `Scope#m` at medium.
   - The scan reopens `ActiveSupport::TestCase` (4 files), `ActionDispatch::IntegrationTest`, `ActionDispatch::Routing::Mapper` and `Warden::Mixins::Common`.
   - Edges directly in those types: Mapper 17 (lib), Warden.Mixins.Common 1 (lib), IntegrationTest 16, TestCase 8.
   - Subclasses: about 842 edges in `< ActiveSupport::TestCase` classes and about 1487 in `< Devise::IntegrationTest` classes (all under test/). For example, `test` appears 631 times bare at low.
   - Contrast: a test class `< ActionController::TestCase`, which is not reopened, gets `ControllerAuthenticatableTest#test` at medium.
   - Total about 2370, of which 18 are in scope. This pattern decides most of the test/ graph, so it is the fix with the largest whole-output effect.
2. **Computed superclass (`DeviseController < Devise.parent_controller.constantize`).** Bare Rails calls in DeviseController and its 6 subclasses stay bare at low: 114 edges in app/ (e.g. `respond_with` 17, `request`, `redirect_to`, `params`). Spec gap. If these were meant to be `Scope#m` medium, this is the largest in-scope pattern.
3. **Rescue-bound locals emitted as calls.** `=> e` gives 3 non-call edges, plus 1 wrong callee (`.message` instead of `e.message`). All are in routes.rb.
4. **`class << x` target emitted as a call.** 1 edge (models.rb:32).
5. **Kernel builtin name used where the external ancestor defines the method.** `Kernel#fail` in a Warden strategy: 2 edges. The other 3 `Kernel#fail`/`raise` uses checked in lib are correct. I verified with the local Ruby that `extend`, `fail`, `send` and `respond_to?` are owned by Kernel, so `Kernel#extend` is correct.
6. **`super` in `initialize` is named `#initialize` (method) instead of `#<init>` (constructor).** 2 edges are wrong per spec, and 2 more are in the spec-gap form `.initialize`. Related: initializer bodies have caller `Type#initialize` (28 edges), while constructor calls target `Type#<init>` (133 edges), so the two never join.
7. **`<global>` caller for top-level code.** 550 edges in total (lib 170, test 353, guides 27). Spec gap, unchanged.

Effect on precision. In scope, patterns 3–6 add up to 9 definitely wrong edges (0.3%). Patterns 1 and 2 are spec-dependent and cover 132 in-scope edges (4.7%). Settling what reopened and computed ancestry should produce would move in-scope precision more than every other fix combined. Across the whole output, pattern 1 (about 2370 edges) dominates.

## Previous findings

Mismatch-table rows from v2:
- **devise.rb:496 `mapping.to.serialize_into_session(record)`: fixed.** The edges are now `mapping.to` (low) and `.serialize_into_session` (low), with no `mapping` edge.
- **devise.rb:474 `include scope::UrlHelpers`: fixed.** Only `Module#include` (medium) remains.
- **database_authenticatable.rb:13 `resource` / `.valid_password?`: fixed.** It is now `resource.valid_password?` (low), with no `resource` edge.
- **database_authenticatable.rb:10 `password` / `mapping` / `authentication_hash` (×3): fixed.** They are now `Authenticatable#password`, `Base#mapping` and `Authenticatable#authentication_hash`, all high.
- **database_authenticatable.rb:13/14 `validate` / `remember_me` (×2): fixed.** Both are `Devise.Strategies.Authenticatable#…`, high.
- **database_authenticatable.rb:24 `Kernel#fail` (×2): still present** (pattern 5).
- **lockable.rb:103/109 missed `super`: fixed.** Both lines now emit `.valid_for_authentication?` (low). Lockable is a module with no scanned ancestor, so the spec's `.member` form applies.
- **responder.rb:23 setter def head: fixed.** 0 edges on any `def` head now name the method being defined (was 6: responder.rb:23/:28, devise.rb:358, devise_controller.rb:108, database_authenticatable.rb:65, scoped_views.rb:13).
- **authenticatable.rb:129 multiple assignment to setters (×2): fixed.** It now emits `#authentication_hash=` and `#authentication_type=` (high).
- **failure_app.rb:71 `request`: fixed.**
  - Lines 71/72/74/79 give `Devise.FailureApp#request` (medium).
  - Line 78 gives `Devise.FailureApp#flash` (medium).
- **`<global>` caller: spec gap, unchanged.** Still 170 in scope.
- **`Devise.ALL#index`: spec gap, unchanged.**

Systematic patterns from v2:
1. **Locals, parameters and block parameters emitted as calls: fixed for the v2 forms, with a small residue.**
   - About 78 edges before. Now 0 bare edges are named `mapping` or `conditions`.
   - The remaining `scope` / `options` bare edges are real methods (Thor `argument :scope`, `options`).
   - Residue: 4 non-call edges in new forms (3 rescue bindings, 1 `class << mod`) and 1 wrong callee (patterns 3 and 4 above).
2. **Inherited methods from a scanned grandparent: fixed.** 0 bare edges remain in strategies/ (was 12).
3. **`super` never emitted: fixed.** All 24 non-comment `super` lines in app/ and lib/ now have an edge (was 0). They resolve as follows:
   - Scanned ancestor: authenticatable.rb:14 → `Devise.Strategies.Base#store?` (high); views_generator.rb:90 → `Devise.Generators.ViewPathTemplates#copy_views` (high), through `include`.
   - External ancestor: `NameError#…`, `StandardError#…` (medium).
   - Unknown ancestor: `.m` (low).
   - The remaining issue is the initializer naming (new pattern 6: 2 wrong edges, 2 spec gap).
4. **Setter method heads give a self-edge to the getter: fixed.** 0 of 6 remain.
5. **Multiple assignment to setters reported as getters: fixed.** 2 of 2 corrected.
6. **Inherited Kernel/Object/Module methods named by guess: partly fixed.**
   - `Kernel#fail` in the Warden strategy is still wrong (2 edges).
   - `Kernel#extend` is correct: Ruby reports `Kernel` as the owner. The v2 remark that it should be `Object#extend` was wrong, and I withdraw it.
   - `Kernel#send` and `Kernel#respond_to?` in FailureApp are correct, since ActionController::Metal does not override them.
