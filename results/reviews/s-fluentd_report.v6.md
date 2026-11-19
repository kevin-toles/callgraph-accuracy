# s-fluentd (ruby): blind call-graph review, round 6

precision 50/50; census ≈98.2% (283 wrong of 15675 in-scope); recall: 1 missed of 37 real calls; 0 non-calls

## Scope
Tool output: `s-fluentd.v2.json`, 64,691 edges, all from `.rb` files. In scope are the `.rb` edges not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment (SPEC Decisions 2026-11-09). That leaves **15,675 edges**: 15,555 under `lib/` and 120 under `tasks/`, across 227 files. `lib/fluent/test/` is excluded. `lib/fluent/test.rb` is a file, not a directory, so it stays in scope.
- Confidence: low 9,328 · medium 3,420 · high 2,867 · unknown 60.
- call_type: method 14,805 · constructor 810 · callback 60.

Precision sample: seed `20261109`, stratified 27 low / 10 medium / 8 high / 5 unknown, over 36 files (`s-fluentd_r5_sample.py`). All 50 edges are real calls on the right line with the right callee form and tier. 7 of the 50 fall under spec gaps and are not counted wrong:
- #13, #14, #16, #20, #22: class-body `desc` / `config_param` / `config_section` left as bare low names.
- #9, #41: calls in a constant initializer in a module body, whose caller is the module.

The census and recall checks then found wrong patterns that the sample happened to miss.

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/fluent/root_agent.rb:333 | `lifecycle(kind_or_agent_list: kind_or_agent_list) do \|instance, kind\|` (inside `lifecycle_safe_sequence = ->(method, checker) {`) | Fluent.RootAgent#shutdown → Fluent.RootAgent#lifecycle, high, method | caller `Fluent.RootAgent#shutdown.lifecycle_safe_sequence` | wrong caller | a local bound to a lambda literal is not treated as a named nested function |
| lib/fluent/counter/server.rb:109 | `v = store.init(key, param, ignore: options['ignore'])` (inside `do_init = lambda do \|store, key\|`) | Fluent.Counter.Server#init → store.init, low, method | caller `Fluent.Counter.Server#init.do_init` | wrong caller | same |
| lib/fluent/root_agent.rb:387 | `lifecycle_safe_sequence.call(:stop, :stopped?)` | Fluent.RootAgent#shutdown → lifecycle_safe_sequence, unknown, callback | `Fluent.RootAgent#shutdown.lifecycle_safe_sequence`, high | wrong callee / wrong confidence | a call to a named nested function is emitted as a callback |
| lib/fluent/plugin/in_forward.rb:206 | `send_data.call(:to_msgpack.to_proc, generate_helo(nonce, user_auth_salt))` | Fluent.Plugin.ForwardInput#handle_connection → send_data, unknown, callback | `Fluent.Plugin.ForwardInput#handle_connection.send_data`, high | wrong callee / wrong confidence | same (`send_data = ->(serializer, data){ … }` at :194) |
| lib/fluent/config/yaml_parser/section_builder.rb:22 | `indent = ' ' * indent_size` (inside `SectionBuilder = Struct.new(...) do def to_s`) | Fluent.Config.YamlParser#to_s → indent_size, low | caller `Fluent.Config.YamlParser.SectionBuilder#to_s` | wrong caller | methods defined in a `Const = Struct.new(...) do … end` block are put on the enclosing module |
| lib/fluent/plugin/buffer.rb:79 | `m.seq = seq + 1` (inside `Metadata = Struct.new(...) do def dup_next`) | Fluent.Plugin.Buffer#dup_next → Fluent.Plugin.Buffer#seq, medium | `Fluent.Plugin.Buffer.Metadata#dup_next` → `Fluent.Plugin.Buffer.Metadata#seq` | wrong caller + wrong callee | same; Metadata's `initialize` also turns into `Buffer#<init>` |
| lib/fluent/config/yaml_parser/fluent_value.rb:27 | `to_s` (in `JsonValue = Struct.new(:val) do def to_element`) | Fluent.Config.YamlParser.FluentValue#to_element → Fluent.Config.YamlParser.FluentValue#to_s, high | `…FluentValue.JsonValue#to_element` → `…FluentValue.JsonValue#to_s`, high | wrong caller + wrong callee | same |
| lib/fluent/compat/parser.rb:251 | `value = ::Fluent::StringUtil.match_regexp(@null_value_pattern, value) ? nil : value` | …ValuesParser#convert_value_to_nil → StringUtil.match_regexp, low | `Fluent.Compat.StringUtil#match_regexp`, high | wrong callee / wrong confidence | constant alias `StringUtil = Fluent::Compat::StringUtil` (plugin/string_util.rb:21) not expanded |
| lib/fluent/plugin.rb:142 | `impl = Fluent::TextParser.lookup(type)` | Fluent.Plugin#new_parser → TextParser.lookup, low | `Fluent.Compat.TextParser#lookup`, high | wrong callee / wrong confidence | alias `TextParser = Fluent::Compat::TextParser` not expanded |
| lib/fluent/compat/socket_util.rb:98 | `super` (in `class BaseInput < Fluent::Input`, `initialize`) | …SocketUtil.BaseInput#<init> → Fluent.Input#<init>, medium, constructor | `Fluent.Compat.Input#<init>`, high, constructor | wrong callee / wrong confidence | alias `Input = Fluent::Compat::Input` not expanded |
| lib/fluent/plugin/in_tail/position_file.rb:26 | `pf = new(file, follow_inodes, logger: logger)` (in `def self.load`) | …PositionFile#load → new, high, method | `Fluent.Plugin.TailInput.PositionFile#<init>`, constructor | wrong callee | a bare `new` in a singleton method is not mapped to `Type#<init>` |
| lib/fluent/log.rb:748 | `super` (in `class LogDeviceIO < ::Logger::LogDevice`, `def flush`) | Fluent.LogDeviceIO#flush → .Logger.LogDevice#flush, medium | `Logger.LogDevice#flush`, medium | wrong callee | the leading `::` of the superclass becomes a leading dot |
| lib/fluent/config/element.rb:150 | `each_pair { \|k, v\|` (in `class Element < Hash`) | Fluent.Config.Element#to_s → each_pair, low | `Fluent.Config.Element#each_pair`, medium | wrong callee / wrong confidence | Ruby rule for external ancestry not applied to a `Hash` subclass (`self.keys` in the same class is medium) |
| lib/fluent/plugin/compressable.rb:73 | `io.pos -= adjust` | only io.pos= (low) | also `io.pos` (getter), low | missed call | compound assignment emits only the setter |
| lib/fluent/config/yaml_parser/loader.rb:63 | `@on_file_parsed&.call(File.expand_path(path.to_s))` | Loader#load → on_file_parsed.call, low, method | spec gap: `on_file_parsed`, callback, unknown if the ivar counts as a "stored property holding a function" | spec gap | Ruby `.call` on a non-`&block` receiver |
| lib/fluent/plugin/in_exec.rb:26 | `desc 'The command (program) to execute.'` | Fluent.Plugin.ExecInput → desc, low | spec gap: `Fluent::Configurable::ClassMethods#desc` reaches the class through `self.included(mod) mod.extend(ClassMethods)` | spec gap | class-body call to a singleton method added by `extend` |

## Systematic patterns (census, scripted in `s-fluentd_r5_census.py`)
| count | pattern | script | hand checks |
|---:|---|---|---|
| 137 | Calls inside the body of a local bound directly to a `->`/`lambda`/`proc` literal inside a `def` keep the outer method as caller, not `outer.f`. There are 24 such locals, e.g. root_agent.rb `lifecycle_safe_sequence`/`lifecycle_unsafe_sequence`, counter/server.rb `do_init`/`do_delete`/`do_inc`/`do_reset`, buffer.rb `get_next_chunk`. Locals that are also bound to a non-function, like `feeder = nil` in in_forward.rb, are excluded. | s-fluentd_r5_lambda.py | root_agent.rb:333–339, counter/server.rb:109–111 |
| 104 | Methods defined in `Const = Struct.new(...) do … end` blocks are attributed to the enclosing namespace: `YamlParser#to_s`, `Buffer#dup_next`, `Buffer#<init>` for Metadata, `FluentValue#to_s`, `GrepFilter#match?` for Expression, and so on. There are 12 such blocks. In-block self-calls also name the wrong type. | s-fluentd_r5_structblk.py | section_builder.rb:22–34, buffer.rb:73–84, fluent_value.rb:23–27 |
| 19 | A call to a lambda-bound local is emitted as `name`, unknown, callback. Per spec it is the named nested function `outer.name`, high. | s-fluentd_r5_lambda.py | root_agent.rb:387–396, in_forward.rb:206–230, out_exec_filter.rb:217/224 |
| 14 | Constant aliases (`Fluent::StringUtil/FileUtil/TextParser/TextFormatter/NullOutputChain/Input = Fluent::Compat::…`) are not expanded. The result is either a `StringUtil.match_regexp`-style low guess or a `Fluent.Input#…` / `Fluent.TextParser.X#<init>` medium ID naming the alias. | s-fluentd_r5_alias.py | compat/parser.rb:251, plugin.rb:142, socket_util.rb:98, out_secondary_file.rb:58 |
| 4 | A bare `new` inside `def self.x` comes out as callee `new`, high, method, where `Type#<init>`, constructor, is expected. | inline in census | daemonizer.rb:22, position_file.rb:26, static_config_analysis.rb:40, time.rb:99 |
| 4 | A superclass written `::Logger::LogDevice` gives `.Logger.LogDevice#m` IDs, which read as a computed receiver. | inline in census | log.rb:748/756/764/772 |
| 3 | In `class Element < Hash`, bare `each_pair`/`each_key` stay low bare names instead of `Fluent.Config.Element#m` medium. | s-fluentd_r5_extanc.py | element.rb:131/150/165 |

Union: 283 edges, census precision 1 − 283/15,675 ≈ **98.19%**. These checks came back clean:
- Line numbers: every edge's callee name appears on its reported line, apart from `super` lines (`s-fluentd_r5_line.py`).
- Bare low calls never name a method defined on the caller's own type (`s-fluentd_r5_baredef.py`).
- `&block.call` edges are all emitted as callbacks (`s-fluentd_r5_callrecv.py`).
- `super` calls:
  - Into an in-scan superclass, they resolve to that class, high.
  - Into an external superclass, they come out as `Ext#m`, medium. The `::Logger` case above is the exception.
  - From mixin modules, they come out as `.m`, low.

## Missed-call patterns (recall)
The recall functions were `Fluent.Agent#lifecycle_control_list` (9 calls), `Fluent.Plugin.Compressable#string_decompress_gzip` (11) and `Fluent.Config.YamlParser.Loader#load` (17). Of those 37 calls, 1 was missed and there were no non-calls (`s-fluentd_r5_recall.py`). Operator methods (`<<`, `[]`) are not counted; see spec gaps.
- **Getter of a compound assignment missed:** `recv.attr op= v` emits `recv.attr=` but not `recv.attr`. That happens in 8 of the 9 such lines in scope (cat.rb:25, literal_parser.rb:174/178, compressable.rb:73/112, group_watch.rb:163/167, child_process.rb:186). Script: `s-fluentd_r5_opassign.py`.

## Spec gaps (not counted wrong; `s-fluentd_r5_gaps.py`, union 1,249)
| count | case |
|---:|---|
| 1,026 | Class-body calls to singleton methods that come from `extend`. This covers both `extend` through a `self.included` hook (`desc` 333, `config_param` 513, `config_section` 62, `config_set_default` 56, `helpers` 28, `helpers_internal` 11, `config_argument` 9, `configured_in` 5) and direct `extend Forwardable` (`def_delegators` 9). They are emitted as bare low names. Classes whose ancestry reaches outside the scan get `Scope#m`, medium, which matches the Ruby rule. The spec does not say how `extend`, and especially `extend` from an `included` hook, takes part in resolving these calls. |
| 99 | Calls in a constant initializer in a class/module body (`PUT = 'PUT'.freeze`, `BUFFER_REGISTRY = Registry.new(...)`). Their caller is the type. The spec's `Type#field` rule is not stated for Ruby constants. |
| 93 | `x.call(...)` where `x` is a plain parameter, ivar or local, not a `&block` and not bound to a literal. It is emitted as `x.call`, low. Whether that counts as a "stored property holding a function" (callback, unknown) cannot be decided without types. |
| 31 | `define_method(:name) do … end` bodies fold into the enclosing scope, as an anonymous block would. At runtime they are methods of the class with a dynamic name. |
| — | Operator method calls (`<<`, `[]`, `==`, `+`) are never emitted, and the 68 argument-less `private` lines get no edge (`private :sym` does). The spec does not say whether these are calls. |
