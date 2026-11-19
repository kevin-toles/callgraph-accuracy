# Blind call-graph review: s-rubygems (Ruby), round 5

precision 50/50; census ≈99.72% (71 wrong of 25650 in-scope); recall: 0 missed of 61 real calls; 0 non-calls

## Scope
Source root `.../devtools/package-managers/rubygems/lib`; tool output `s-rubygems.v2.json` (25,650 edges, all `.rb`). No source file sits under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment, so all **25,650 edges are in scope**. They cover 333 files. Confidence split: high 9,135 / medium 4,349 / low 12,152 / unknown 14. call_type split: method 24,534 / constructor 1,102 / callback 14. Edges marked `is_external`: 2,105.

The tool emits **no edges at all** for the vendored trees `bundler/vendor/{thor,fileutils}` and `rubygems/vendor/{pub_grub,uri,net-http,optparse,tsort,timeout,securerandom,resolv,net-protocol}`. That is 93 `.rb` files and about 29,900 lines. The 2026-11-09 decision puts them in scope, so this is reported under recall below. One consequence: vendored Thor is not part of what the tool scanned. Bundler's `CLI < Thor` classes therefore have an ancestor outside the scan, and their Thor DSL calls (`Bundler.CLI#desc`, `#method_option` and so on, medium) are correct under the Ruby rule.

Sample: seed `random.Random(20261109)`, stratified as low 22 / high 16 / medium 7 / unknown 5, drawn from 40 files. No sampled edge is wrong. Four of them are spec-gap cases and are counted separately, not as wrong:
- #18 `specs` called on an abstract base
- #40 `self.class` → `Bundler.Retry#class`
- #49 and #50, `.call` on lambda/proc locals

Recall functions, all tool edges matched:
- `Bundler.Source.Git.GitProxy#git_remote_fetch`: 27 calls
- `Gem.Ext.Builder#build_extensions`: 16 calls
- `Bundler.Fetcher#connection`: 18 calls

Operators (`-=`, `==`, `[]`) were not counted because the spec does not cover them.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| rubygems/requirement.rb:64 | `new input` | Gem.Requirement#create → `new`, low, method | Gem.Requirement#<init>, high, constructor | wrong callee | bare `new` in a class method (self.new) not treated as constructor |
| bundler/index.rb:8 | `i = new` | Bundler.Index#build → Bundler.Index#new, medium, method | Bundler.Index#<init>, high, constructor | wrong callee | same; class with external include gets `Scope#new` instead |
| rubygems/package/tar_header.rb:175 | `EMPTY = new({ # :nodoc:` | Gem.Package.TarHeader → `new`, low, method | Gem.Package.TarHeader#<init>, high, constructor | wrong callee | bare `new` in class body |
| bundler/cli.rb:29 | `super` (in `def self.start`) | Bundler.CLI#start → Thor.Actions#start, medium | `.start`, low (superclass Thor not in scan) | wrong callee | `include Thor::Actions` from bundler/cli/gem.rb (class CLI::Gem) attached to Bundler::CLI |
| bundler/cli.rb:60 | `super` (in initialize) | Bundler.CLI#<init> → Thor.Actions#<init>, medium, constructor | parent Thor#<init>, medium | wrong callee | same mis-attached include |
| rubygems/version.rb:219 | `@@all[version] \|\|= super` (in `def self.new`) | Gem.Version#new → Comparable#new, medium | `.new`, low | wrong callee | super in a singleton method routed into an included module's instance methods |
| rubygems/package/tar_reader.rb:20 | `reader = super` (in `def self.new`) | Gem.Package.TarReader#new → Enumerable#new, medium | `.new`, low | wrong callee | same |
| bundler/deprecate.rb:25 | `original = skip` (in `def Deprecate.skip_during`) | Bundler#skip_during → Bundler#skip, high | Bundler.Deprecate#skip_during → Bundler.Deprecate#skip, high | wrong caller + callee | `def Const.m` defined on the enclosing module, not on `Const` |
| rubygems/user_interaction.rb:620 | `SilentDownloadReporter.new(@outs, *args)` | Gem.SilentUI#download_reporter → SilentDownloadReporter#<init>, medium | Gem.StreamUI.SilentDownloadReporter#<init>, high | wrong callee + confidence | constant lookup does not walk the superclass (Gem::SilentUI < Gem::StreamUI) |
| bundler/cli/outdated.rb:355 | `return "" unless Gem.const_defined?(:DEFAULT_SOURCE_DATE_EPOCH)` | Bundler.CLI.Outdated#release_date_for → Bundler.CLI.Gem#const_defined?, medium | Gem#const_defined?, medium | wrong callee | `class CLI::Outdated` treated as lexically inside Bundler::CLI |
| bundler/source.rb:17 (sample #18) | `specs.unmet_dependency_names` | Bundler.Source#unmet_deps → `specs`, low | — | spec gap | method defined only in subclasses (template method) |
| bundler/retry.rb:24 (sample #40) | `retries = self.class.default_retries` | Bundler.Retry#<init> → Bundler.Retry#class, medium | — | spec gap | Kernel/Object builtins have no fixed Ruby ID (`Kernel#raise` vs `T#class` vs bare `__dir__`) |
| bundler/cli/outdated.rb:63 (sample #49) | `definition_resolution.call` | Bundler.CLI.Outdated#run → definition_resolution, unknown, callback | — | spec gap | Ruby `x = proc/lambda/->` not listed among named nested functions |
| bundler/inline.rb:110 (sample #50) | `configure_forked_definition.call(definition) if installed_in_fork` | gemfile → configure_forked_definition, unknown, callback | — | spec gap | same |

## Systematic patterns (wrong), scripted counts
1. **W1, bare `new` in class scope is not a constructor: 56.** The 47 bare `new` edges are low/method. Another 9 come out as `T#new` medium/method, for classes with an external include (GemHelper, Index, StubSpecification, DependencyList, NameTuple ×2, NoAliasYAMLTree, SourceList, SpecificationRecord). All should be `T#<init>`, high, constructor. Gem::Package, Gem::Platform and Gem::Version define `def self.new` and are excluded. I hand-checked all 56 lines; each is inside `def self.x`, `class << self` or a class body.
2. **W2, `super` resolved into an included module: 9.** Six Bundler::CLI edges go to `Thor.Actions#{start,dispatch,<init>,default_command,help,handle_no_command_error}`. Bundler::CLI does not include Thor::Actions; only Bundler::CLI::Gem does. Three `super` calls inside `def self.new` go to `Comparable#new` (Version ×2) or `Enumerable#new` (TarReader).
3. **W3, `def Const.m` attributed to the enclosing module: 3** (bundler/deprecate.rb:25, 26, 29). Both caller and callee name `Bundler#…` instead of `Bundler.Deprecate#…`.
4. **W4, constant inherited through the superclass not resolved: 2** (user_interaction.rb:620, 624).
5. **W5, compact nesting `class CLI::Outdated` given the wrong lexical scope: 1.**

The union of all wrong patterns is 71 edges. 1 − 71/25,650 = 99.72%.

## Missed-call patterns (recall)
- **Vendored code not analysed: 93 files, about 29,900 lines, 0 edges.** These are under `bundler/vendor/` and `rubygems/vendor/`, which are in scope under the 2026-11-09 decision. Every call in them is missed; I did not count them call by call.
- The three recall functions miss nothing: 0 of 61 missed, 0 non-calls. Line numbers are right on every multi-line statement checked. A scripted check that the callee name appears on the reported line flagged 73 edges, and all 73 are `super` calls, which are correct.

## Spec gaps (not counted as wrong), scripted counts
- **G0, Ruby receiver that is itself a zero-argument method call:** the tool writes `X.y.m` as `.m`, low (4,188 leading-dot edges, about 1,392 of them shaped like `X.y.m`). The spec's `a.b.c()` → `b.c` example conflicts with its "call result → `.m`" rule, because in Ruby `X.y` is always a call.
- **G1, Kernel/Object/Module builtins: 177.** 63 are bare-low edges (`__dir__`, `eval`, `object_id`, `caller_locations`, `deprecate_constant`, …). 114 are `self.class` → `T#class`, medium. Elsewhere the tool emits `Kernel#raise`, `Kernel#caller` and `Module#attr_reader` as medium.
- **G2, mixin module calling a method of the class that includes it: about 153, bare low.** Callers include Gem::GemcutterUtilities `say`/`options`, Gem::QueryUtils, and Gem::InstallUpdateOptions `add_option`. The count also takes in 3 abstract-base `specs` calls in Bundler::Source and 3 that overlap G3.
- **G5, members of `X = Struct.new/Class.new(...) do … end` blocks: 57.** The caller is the enclosing type (for example `Bundler.Settings#base_path`) rather than `Bundler.Settings.Path#…`.
- **G7, readers generated by `attr_reader(*FIELDS)`: 19, bare low** (tar_header.rb).
- **G3, methods created by `alias`/`alias_method`: 6, bare low** (`gem_original_require`, `rg_extension_dir`, …).
- **G4, locals bound to `proc`/`lambda`/`->` and then `.call`ed: 5,** emitted as callback/unknown.
- **G6, constructors of `Struct.new`-generated classes: 3, medium** (`Bundler.Settings.Path#<init>`, `…CompactIndex.ClientFetcher#<init>`).
- The spec-gap union is 413 edges.

Helper scripts are in `<fanout>/`: `s-rubygems_r4_load.py`, `_sample.py`, `_highrecv.py`, `_bare.py`, `_super.py`, `_selfsuper.py`, `_linecheck.py`, `_ctor.py`, `_constres.py`, `_lexical.py`, `_recall.py`, `_census.py`, `_dotchain.py`. Wrong-edge keys are in `s-rubygems_r4_census_wrong.json`.
