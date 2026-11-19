# h-phoenix (Elixir) blind call-graph review, round 8

precision 48/50; census ≈100.0% (0 wrong of 5311 in-scope); recall: 0 missed of 26 real calls; 0 non-calls

None of the 50 sampled edges is wrong. The other 2 sampled edges are spec gaps (#24, inside a `quote` block, and #47, a callback through an index expression), so they are not counted as correct or wrong. Across the whole in-scope set, 290 edges are spec gaps (5.5%), counted separately below.

## Scope
- Tool output: `<scans>/final13-A/h-phoenix.v2.json`, 23,732 edges in total.
- In scope: `.ex`/`.exs` edges not under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment. That is **5,311 edges in 89 files**. `integration_test/` (other than its `test/` subfolder), `installer/`, `config/` and `mix.exs` files are in scope.
- Out of scope: the JS/MJS edges (5,988) and the Elixir edges under `test/` dirs.
- Confidence split: medium 3,267 / high 1,765 / low 256 / unknown 23.
- call_type split: direct 5,054 / method 234 / callback 23.
- By tier and type: high+direct 1,765; medium+direct 3,267; low+method 234; low+direct 22; unknown+callback 23.
- The tool's 59 `use_source_unread` coverage notes are all under `integration_test/test/`, which is out of scope.
- The `measured_accuracy` field was ignored.

## Method
- **Precision sample:** seed `20261113`; quotas medium 26, high 14, low 5, unknown 5. The sample spreads over 48 files (`h-phoenix_r8_sample.py`).
- **Recall:** three functions in three files (`h-phoenix_r8_recall.py`):
  - `Phoenix.Digester.map_file`
  - `Phoenix.Socket.Transport.check_origin`
  - `Mix.Tasks.Phx.Gen.Schema.run`
  - Extra check: `Phoenix.Digester.clean`, 7/7 correct, with the default argument `now \\ now()` caught and no edge from `@spec`.
- **Census scripts** (all prefixed `h-phoenix_r8_`):
  - `lines.py`: is the callee name on the line, and is it written as a call?
  - `dups.py`: are there more same-line duplicate edges than written occurrences?
  - `defs.py`: is each high callee defined in the scan? It also checks alias resolution for nested `defmodule`s.
  - `bare.py`: do bare calls resolve to a module the file imports or `use`s?
  - `caller.py`: does each caller match the nearest enclosing `def`?
  - `quote.py`: detects `quote do … end` ranges.
  - `census.py`: the spec-gap union.
  - Every flagged edge was checked by hand.

## Mismatch table
No edge was judged wrong. The table lists the spec-gap rows: the two sampled ones, plus one example of each spec-gap class.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/phoenix/endpoint.ex:473 (sample #24) | `raise ArgumentError, "no :pubsub_server configured for #{inspect(__MODULE__)}"` (inside `quote do` in a macro, in `defp pubsub_server!`) | Phoenix.Endpoint.pubsub_server! → Kernel.raise, medium, direct | undecided (CAPABILITIES elixir/12-quote-blocks) | spec gap | a call written inside a `quote` block |
| lib/phoenix/code_reloader.ex:113 (sample #47) | `case opts[:reloader].(conn.private.phoenix_endpoint, opts) do` | Phoenix.CodeReloader.call → `opts[:reloader]`, unknown, callback | callback/unknown is right; the callee name for an index expression is undecided | spec gap | dynamic call through a non-identifier expression |
| lib/phoenix/code_reloader/server.ex:494 | `Enum.reduce(Mix.ProjectStack.pop_after_compiler(compiler), result, & &1.(&2))` | Phoenix.CodeReloader.Server.run_compiler → `&1`, unknown, callback | callee name for a capture placeholder is undecided | spec gap | dynamic call through a capture argument |
| lib/phoenix/code_reloader.ex:63 | `defdelegate reload!(endpoint, opts), to: Phoenix.CodeReloader.Server` | Phoenix.CodeReloader.reload! → Phoenix.CodeReloader.Server.reload!, high, direct | undecided (CAPABILITIES elixir/18-defdelegate) | spec gap | defdelegate |
| lib/phoenix/router.ex:904 | `add_route(:match, unquote(verb), path, expand_alias(plug, __CALLER__), plug_opts, options)` (body of `defmacro unquote(verb)(path, plug, plug_opts, options \\ [])` in a module-body `for`) | Phoenix.Router.unquote(verb) → Phoenix.Router.add_route, high, direct | caller ID of a function defined with a non-literal unquote name is undecided | spec gap | unquote fragment with a computed name |
| lib/phoenix/endpoint.ex:666 | `super(conn, opts)` (inside `quote`, after `defoverridable call: 2`) | Phoenix.Endpoint.call → `.call`, low, method | undecided (quote block) | spec gap | `super` in a quoted override |

## Systematic patterns (wrong edges), by scripted count
No wrong pattern was found. Each check below was scripted over all 5,311 in-scope edges, and every flagged edge was checked by hand.

| Check | Flagged | After hand check |
|---|---|---|
| Callee name not on the reported line | 3 | All are `super(...)` → `.call` / `.action` inside quote blocks (spec gap). No line errors. |
| Callee name on the line but not written as a call (field access, `&M.f/n` capture) | 1 | `defdelegate sync, to: …` (spec gap). No capture or field-access edges were emitted. |
| Same-line duplicate edges exceeding written occurrences | 0 | — |
| High callee not found as a `def` in a `defmodule` | 16 | All correct. 6 are `defprotocol Phoenix.Param` body-less `to_param` (high per Decisions 2026-11-09). 1 is `defimpl Inspect, for: Phoenix.Socket.Message` → `Inspect.Phoenix.Socket.Message.process_message`. 9 are top-level `x = fn … end` named nested functions: `config/config.esbuild` and `installer/recreate_default_css.shell!` / `.shell_in_daisy!`. |
| High callee missing from `nodes` (C1) | 0 | — |
| Medium callee naming a scanned module (C2) | 2 | `Phx.New.Umbrella.render` is generated by the scanned `Phx.New.Generator.__using__` quote, so medium is right per "Generated functions". The other is a defdelegate (spec gap). |
| Bare call resolved to another module | 117 | All match an `import` (Plug.Conn, Config, Mix.Generator) or a `use` (Phx.New.Generator `template` macro, Plug.CSRFProtection via defdelegate). |
| Caller differs from the nearest preceding `def` (outside quote) | 53 | All correct. They are module-body code after a `def`: module attributes, `Record.defrecordp(… Record.extract(…))`, module-level `if Version.match?(…)`, `@moduledoc` interpolation. A few are code after a closed `quote`, and one is file-level `.exs` code. |
| Nested `defmodule` alias used before its line (open defect elixir/03) | 0 | No occurrence in scope. |
| Edges on record macro uses (Decisions 2026-11-10) | 0 | `Record.defrecordp` emits no edge; `Record.extract` in its arguments is medium (10 edges, correct). |
| Typespec / `@spec` edges | 0 | — |

## Missed-call patterns (recall)
None.
- `map_file`: 9/9.
- `check_origin`: 10/10. This includes `sender.()` as a callback and the function-scoped `import Plug.Conn` resolving `get_req_header`, `resp` and `halt`.
- `run`: 7/7.
- In all three, string interpolation, field access (`stats.size`, `schema.opts[:primary_key]`) and the default-argument capture `&Plug.Conn.send_resp/1` correctly produce no edge.

## Spec gaps (290 in-scope edges, union; counted separately, never as wrong)
1. **Calls written inside `quote` blocks: 282 edges** (medium 136, high 106, low 37, unknown 3) in 13 files. The largest are endpoint.ex 78, router.ex 66, router/helpers.ex 48 and controller/pipeline.ex 28.
   - Example: `Phoenix.Channel.Server.broadcast_from(pubsub_server!(), from, topic, event, msg)` inside `quote do … def broadcast_from(…)` in a macro. The tool's caller is the quoted def, named under the macro's own module (`Phoenix.Endpoint.broadcast_from`).
   - The class includes:
     - calls inside `unquote(…)` within a quote (`def __sockets__, do: unquote(Macro.escape(sockets))`);
     - callers with computed names (`Phoenix.Router.Helpers.unquote(:"#{helper}_path")`, `Phoenix.Param.unquote(module).to_param`);
     - `super(conn, opts)` → `.call` (3);
     - the 6 `Kernel.defoverridable` edges.
   - The question SPEC leaves open is the one CAPABILITIES records as elixir/12-quote-blocks. Is a call written inside a `quote` block an edge? Is its caller the macro, the generated function in the expanding module, or neither? It also leaves open whether a call inside `unquote(…)` within the quote, which runs during expansion, follows the same rule.
2. **`defdelegate`: 6 edges.** Example: `defdelegate reload!(endpoint, opts), to: Phoenix.CodeReloader.Server`. The question is elixir/18-defdelegate: does the generated function get an edge to its target (direct or implicit, on the defdelegate line), or is it a declaration with no edge?
3. **Functions defined with a non-literal `unquote` name, outside a quote: 2 edges.** Example: `defmacro unquote(verb)(path, plug, plug_opts, options \\ [])` inside `for verb <- …` at module level. The tool's caller is `Phoenix.Router.unquote(verb)`. SPEC (Decisions 2026-10-29) decides `def unquote(:name)` only for a literal name. What caller ID does the body of a function whose name is computed from a comprehension variable get?
4. **Dynamic calls through a non-identifier expression: 2 edges outside quotes** (a third, `var!(add_resources, Phoenix.Router).(resource)`, is inside a quote).
   - `opts[:reloader].(…)` → callee `opts[:reloader]`.
   - `& &1.(&2)` → callee `&1`.
   - SPEC says such a call's callee is "the variable's name". It does not say what the callee name is when the called value is an index expression, a capture placeholder or a macro result.

## Helper scripts
In `<fanout>/`: `h-phoenix_r8_load.py`, `h-phoenix_r8_sample.py`, `h-phoenix_r8_recall.py`, `h-phoenix_r8_lines.py`, `h-phoenix_r8_dups.py`, `h-phoenix_r8_defs.py`, `h-phoenix_r8_mods.py`, `h-phoenix_r8_bare.py`, `h-phoenix_r8_caller.py`, `h-phoenix_r8_quote.py`, `h-phoenix_r8_census.py`.
