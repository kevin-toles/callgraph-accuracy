# s-realtime (elixir) blind call-graph review, round 9

precision 50/50; census ≈99.96% (3 wrong of 7526 in-scope); recall: 0 missed of 24 real calls; 0 non-calls

## Scope
Tool output `<scans>/final13-A/s-realtime.v2.json`, 32,565 edges in total. In scope: `.ex`/`.exs` files with no `test/`, `tests/`, `spec/`, `examples/` or `docs/` path segment. That leaves **7,526 edges in 289 files**: `lib/` 5,874, `forum/` 1,070, `config/` 259, `priv/` 177, `dev/` 128 and `mix.exs` 18. Most of the 23,212 `.exs` edges sit under `test/` and are out of scope. The TS/JS edges (1,856) are also out of scope.
- Confidence: high 2,281 / medium 4,032 / low 1,199 / unknown 14.
- call_type: direct 7,451 / method 61 / callback 14. The pairs are high-direct, medium-direct, low-direct (1,138), low-method (61, all receiver guesses `recv.f` / `.f`) and unknown-callback.
- I ignored the `measured_accuracy` field.

Precision sample: seed 9009, high 15 / medium 24 / low 6 / unknown 5, across 33 files. I checked each edge against the source line, the enclosing def or defmodule (including nested modules and named fn-locals), the aliases and imports in effect, and the scan's definitions. Fifty edges are not wrong. One (#48, `state.limit.log_fn`) is a spec gap and is counted separately, not as wrong. Every low bare-name edge in the sample (`assign`, `attr`, `assign_new`) is in a file the tool's coverage notes mark `use_source_unread` (Phoenix / Ecto `use`). A low guess there is correct under C4.

Recall functions:
1. `Realtime.Tenants.Connect.connect` (connect.ex:198–216): 4 calls, all found.
2. `Realtime.RateCounter.maybe_trigger_limit`, all three clauses (rate_counter.ex:259–279): 3 calls, all found. That includes the callback `state.limit.log_fn.()`.
3. `RealtimeWeb.StatusLive.Index.mount` (status_live/index.ex:19–44): 17 calls, all found. `connected?` and the 10 `assign` calls are low under a `use_source_unread` note.

I did not count operators (`++`, `<`) as calls. The written `Kernel.++` is emitted.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| dev/bench/secrets.exs:18 | `H.encrypt!(string_to_encrypt, secret_key)` | dev/bench/secrets → Realtime.Helpers.encrypt!, medium, direct | `Realtime.Helpers` is scanned and does not define `encrypt!`; it has no `use`, so nothing is inherited. C2 forbids a medium callee naming an undefined member of a scanned module, and C4 makes it a low guess. | wrong confidence | Stale bench script calls a removed function; the alias-resolved ID is emitted at medium. |
| dev/bench/secrets.exs:21 | `H.decrypt!(string_to_decrypt, secret_key)` | dev/bench/secrets → Realtime.Helpers.decrypt!, medium, direct | same as above | wrong confidence | same |
| dev/bench/gen_counter.exs:4 | `_gen_counter = GenCounter.new(:any_term)` | dev/bench/gen_counter → Realtime.GenCounter.new, medium, direct | `Realtime.GenCounter` (`use GenServer`) does not define `new`, and `GenServer` does not inject it. Low per C2/C4. | wrong confidence | same |
| lib/realtime/rate_counter/rate_counter.ex:273 (sample #48) | `state.limit.log_fn.()` | maybe_trigger_limit → `state.limit.log_fn`, unknown, callback | undecided | spec gap | Callback ID for a function held in a nested map field |

No sampled edge was wrong. The three wrong edges came from the census script that checks every medium callee naming a scanned module (`s-realtime_r9_load.py` / `_defs.py`). That script found 53 such edges. The other 50 are functions injected by an external `use`: `Realtime.Repo` (Ecto.Repo), `RealtimeWeb.Endpoint`, `RealtimeWeb.Presence`, the PromEx `__ets_cron_flusher_name__`, and `JwtAuthToken.verify_and_validate` (Joken.Config). Those are correct as inherited from a base outside the scan.

## Systematic patterns (scripted counts)
1. **Medium callee naming an undefined member of a scanned module (C2): 3 edges.** All three are in `dev/bench/*.exs` and call functions the library no longer defines. I checked all three by hand.

Checks that found no wrong edges:
- High callee not defined in its scanned module: 0 of 2,281.
- Low bare name defined in the caller's module or in a scanned module the file imports: 0.
- Low bare name reachable through the imports a scanned `use` target injects (`use RealtimeWeb` → `RealtimeWeb.Components`/`ErrorHelpers`/`Gettext`, `use Realtime.Logs`): 0.
- Low bare name in a file without a coverage note: 0 of 1,138.
- A bare call resolved to an external module despite a local definition: 0. The six `query(...)` calls in subscriptions.ex are arity-correct: `import Postgrex, only: [query: 3, query: 4]` beside a local `query/5`.
- Callee name absent from its line: 0.
- Caller differing from the enclosing def, defmodule, nested module or named fn-local (15 heuristic hits): all 15 hand-checked correct. They are `defimpl` members `Jason.Encoder.Tuple.encode`, fn-locals `parse_and_start.formatter_fun` / `handle_event.update`, and `defdelegate` heads.
- Open defect `elixir/03` (nested-module alias applied before its defmodule line): 0 occurrences across 59 nested modules.
- A reference resolved through an `alias` that appears later in the file: 0.

## Missed-call patterns (recall)
None in the three recall functions (0 of 24).

Recall gaps the tool reports itself: the coverage list has 273 partial files (`use_source_unread`: Phoenix, Ecto, PromEx.Plugin, Snabbkaffex and others). Bare calls in those files stay low guesses rather than being attributed to the library that injects them (for example `assign` 153, `execute` 261, `field` 79). That is C4-compliant. `assets/vendor` is skipped (not Elixir).

## Spec gaps (counted separately, not wrong)
1. **Calls inside `quote` blocks: 29 edges.**
   - Examples: `lib/realtime/logs.ex:23` `Logger.error("#{code}: #{Realtime.Logs.to_log(error)}", …)` inside `defmacro log_error … quote bind_quoted: … do`. The tool's caller is `Realtime.Logs.log_error`.
   - `lib/realtime_web/socket.ex:23` `Phoenix.Socket.__child_spec__(…)` inside `defmacro __using__ … quote do def child_spec(opts) do`. The tool's caller is `RealtimeWeb.Socket.child_spec`.
   - `lib/realtime_web.ex:131` `statics: RealtimeWeb.static_paths()` inside the quote.
   - Open question (CAPABILITIES `elixir/12`): is a call written inside `quote` an edge at all? If so, is its caller the macro, the function generated in the expanding module, or neither?
   - Six further edges in quote blocks are `unquote(view_helpers())` / `unquote(verified_routes())`. Their arguments run when the enclosing function evaluates the quote, so I did not count them as gaps.
2. **Remote calls through aliases injected by an unread `use`: 20 edges.** These are `Event.build(…)` / `Polling.build(…)` in `lib/realtime/monitoring/prom_ex/plugins/*.ex` under `use PromEx.Plugin`, emitted as `Event.build` / `Polling.build`, medium. Where the file writes `alias PromEx.MetricTypes.Event` (tenants.ex:6) the tool gives `PromEx.MetricTypes.Event.build`. Open question: when a module alias may come from an unread `use`, is `Short.f` named as written at medium, or is it an unresolved low guess?
3. **`defdelegate` edges: 2.** `lib/realtime/signal_handler.ex:31` `defdelegate handle_info(info, state), to: :erl_signal_handler` gives `Realtime.SignalHandler.handle_info → erl_signal_handler.handle_info`, medium, direct; line 34 does the same for `handle_call`. Open question (CAPABILITIES `elixir/18`): is a `defdelegate` an edge from the generated function to its target (and with which call_type), or a declaration with no edge?
4. **Callback ID for a function stored in a nested field: 1 edge.** `lib/realtime/rate_counter/rate_counter.ex:273` `state.limit.log_fn.()` gives callee `state.limit.log_fn`. Open question: SPEC says "callee is the variable's name" for a stored property holding a function. Is that the full path `state.limit.log_fn`, or the last segment(s) under the receiver rule (`limit.log_fn` / `log_fn`)?

Helper scripts are `<fanout>/s-realtime_r9_{load,defs,sample,ctx,check,lowbare,useimp,callers,aliasorder,aliaslate,recall,gaps}.py`.
