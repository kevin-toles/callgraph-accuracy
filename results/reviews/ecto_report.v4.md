# ecto (elixir) call-graph review, v4

Summary: precision 50/50; census ≈99.53% (27 wrong of 5787 in-scope); recall: 0 missed of 47 real calls; 0 non-calls

**Scope.** 5,787 edges under `lib/` are in scope. Confidence split: high 2,690, medium 2,778, low 240, unknown 79. I excluded `test/` (16,798), `integration_test/` (4,809), `examples/` (18) and `mix.exs` (7). The in-scope counts and tier split are identical to v3.

**Precision sample.** I drew 50 edges with `random.Random(20261032)` (script `ecto_v4_sample.py`): 20 high, 20 medium, 5 low and 5 unknown, from 18 files. All 50 are correct. Some of the correct edges:
- recursion that matches by arity: uuid.ex:390 `to_datetime/1`, type.ex:866 `cast_fun`, query.ex:1183 private `from/5` inside the `from` macro
- multi-line calls reported on their own line: planner.ex:2391 `error!(` (arity 3, high)
- module-level helpers: uuid.ex:93/151 `c/1`, `d/1`
- `Kernel.*` auto-imports, medium
- the query-DSL names `field` (association.ex:1697) and `assoc` (association.ex:427), honest low per the spec
- `__struct__.build`, `schema.__schema__` and `repo.prepare_query`, low
- callbacks `fun` and `traverse_function`, unknown

**Recall.** I compared three functions against the source:

| Function | Real calls | Missed | Non-calls |
|---|---|---|---|
| `Ecto.Repo.Preloader.maybe_pmap` (repo/preloader.ex:152) | 16 | 0 | 0 |
| `Ecto.Changeset.validate_length` (changeset.ex:3090, including its anonymous fn) | 14 | 0 | 0 |
| `Ecto.Changeset.cast/7` (changeset.ex:760) | 17 | 0 | 0 |

The captures `&Ecto.Type.trim/2` and `&is_function/1` were correctly not reported. `&process_param(..., &2)` is an anonymous function, and its call is correctly reported. Access syntax (`opts[:is]`) and struct literals were correctly not reported.

**Census checks with no errors.** Each check covered all 5,787 edges:
- Every high callee is defined in the scan, and no medium or low callee is (`ecto_v4_defs.py`).
- No edge comes from an `&Mod.f/n` capture alone (`ecto_v4_captures.py`).
- The only `defdelegate` line produces `Ecto.Repo.all_running` → `Ecto.Repo.Registry.all_running`, high, as intended.
- No edges come from `@doc`/`@moduledoc` text. The 64 edges inside other heredocs are all `#{...}` interpolations, which are real calls.
- Every callee name appears on its reported line (`ecto_v4_lines.py`).
- Local calls match by arity:
  - `apply/4` → `Ecto.Repo.Schema.apply`, high; `apply/3` → `Kernel.apply`, medium.
  - Builder `import Kernel, except: [apply: N]` resolves to the local `apply`.
  - inspect.ex `except: [to_string: 1]` resolves to the local `to_string`.
- `import ..., only:` resolves: `Ecto.Query.from/where/join/distinct` and `Ecto.Query.Planner.attach_prefix`, all high.

A scan for written `Mod.f(` remote calls with no edge (`ecto_v4_missed2.py`) found only the two file-level calls in json.ex (pattern 5 below).

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| lib/ecto/query/api.ex:51 (census) | `def left == right, do: doc!([left, right])` | `Ecto.Query.API.left == right` → `Ecto.Query.API.doc!`, high, direct | caller `Ecto.Query.API.==` | wrong caller | the whole operator-definition head becomes the function name |
| lib/ecto/query/api.ex:131 (census) | `def not value, do: doc!([value])` | `Ecto.Query.API.not value` → `Ecto.Query.API.doc!`, high, direct | caller `Ecto.Query.API.not` | wrong caller | same: a paren-less unary operator head |
| lib/ecto/query/builder/join.ex:265 (census) | `%JoinExpr{unquote_splicing(join), on: %BooleanExpr{op: :and}},` | `Ecto.Query.Builder.Join.build_on` → `unquote_splicing`, low, direct | no edge (`quote` special form, a language construct; the tool already skips `unquote`) | not a call | `unquote_splicing` is not treated like `unquote` |
| lib/mix/tasks/ecto.gen.repo.ex:56 (census) | `create_directory Path.dirname(file)` | `Mix.Tasks.Ecto.Gen.Repo.run` → `create_directory`, low, direct | `Mix.Generator.create_directory`, medium (`import Mix.Generator`, line 5) | wrong callee / wrong confidence | the `use Mix.Task` guard suppresses an explicit external import |
| lib/mix/tasks/ecto.gen.repo.ex:57 (census) | `create_file file, repo_template(opts)` | → `create_file`, low, direct | `Mix.Generator.create_file`, medium | wrong callee / wrong confidence | same |
| lib/mix/tasks/ecto.gen.repo.ex:95 (census) | `embed_template :repo, """` | `Mix.Tasks.Ecto.Gen.Repo` → `embed_template`, low, direct | `Mix.Generator.embed_template`, medium | wrong callee / wrong confidence | same |
| lib/ecto/repo/supervisor.ex:120 (census) | `destructure [username, password], info.userinfo && String.split(info.userinfo, ":", parts: 2)` | `Ecto.Repo.Supervisor.parse_url` → `destructure`, low, direct | `Kernel.destructure`, medium | wrong callee / wrong confidence | one Kernel macro is missing from the auto-import set |
| lib/ecto/json.ex:2 (census) | `module = Macro.inspect_atom(:literal, encoder)` | no edge | `lib/ecto/json` → `Macro.inspect_atom`, medium | missed call | file-level code (outside any module) is not scanned |
| lib/ecto/json.ex:4 (census) | `if Code.ensure_loaded?(encoder) do` | no edge | `lib/ecto/json` → `Code.ensure_loaded?`, medium | missed call | same |
| lib/ecto/json.ex:6 (census) | `def encode(%{__owner__: owner, __field__: field}, _) do` (inside `defimpl encoder, for: Ecto.Association.NotLoaded`) | caller `encoder.Ecto.Association.NotLoaded.encode` | the protocol is a comprehension variable (`Jason.Encoder` / `JSON.Encoder`). The spec gives `P.T.fun` only for a literal `P` | spec gap | — |
| lib/ecto/query.ex:1163 (census) | `Ecto.Query.unquote(type)(unquote(quoted), unquote(binds), unquote(expr))` | `Ecto.Query.from` → `Ecto.Query.unquote`, medium, method | a remote call whose function name is computed. The spec has no rule for it | spec gap | — |
| lib/mix/tasks/ecto.gen.repo.ex:57 (census) | `create_file file, repo_template(opts)` | → `repo_template`, low, direct | `repo_template/1` is generated in this module by the external `embed_template` macro. The spec does not say whether that counts as "defined in the scan" | spec gap | — |
| lib/ecto/type.ex:834 (census) | `cast_fun(type).(value)` | `Ecto.Type.cast` → `cast_fun(type)`, unknown, callback | the spec names a callback after its variable and does not cover `expr.(args)` | spec gap | — |

**About the `use Mix.Task` rows.** `use Mix.Task` (line 2) is the only `use` in scope. Mix.Task's source is not in the scan, so I could not read its `__using__` here. The file itself contains an explicit `import Mix.Generator` at line 5. That import is the only visible definition of `create_file`, `create_directory` and `embed_template`, so I judged these against the source as wrong, the same as in v3.

## Systematic patterns (scripted counts over the 5,787 in-scope edges)

1. **Operator definitions give garbled caller IDs: 14.** Every operator `def` in `Ecto.Query.API` (api.ex:51–151) has the full head text as its caller:
   - `left == right`, `!=`, `<=`, `>=`, `<`, `>`, `+`, `-`, `*`, `/`, `and`, `or`, `in`
   - `not value`

   The caller should be `Ecto.Query.API.==` and so on. Scripted with `ecto_v4_callers.py`, which compares each edge's caller with its enclosing `def`. That check found no other wrong callers: the 24 other mismatches are correct module-level, `__using__` or comprehension callers. This pattern was already in the v2a/v2b outputs (14 each) but was not reported before.
2. **`unquote_splicing` is reported as a call: 7** (low, bare). Locations: join.ex:265, 288; builder.ex:1089, 1498, 1666; schema.ex:611, 629. The tool does not report `unquote(...)` (0 edges), so this is also inconsistent.
3. **The `use` guard blocks an explicit external import: 5.** `create_file` 2, `embed_template` 2, `create_directory` 1, all in ecto.gen.repo.ex.
4. **A Kernel macro is missing from auto-imports: 1.** `destructure`. The other 42 distinct `Kernel.*` callees resolve, medium.
5. **File-level code is not scanned: 2 missed calls.** These are json.ex:2 and json.ex:4. json.ex is the only lib file with code outside a module. Missed calls are not edges, so they are not in the census denominator.

Census: 14 + 7 + 5 + 1 = **27 wrong of 5,787 in-scope edges, ≈99.53%**.

## Spec gaps (counted separately, not as wrong)

- Variable-protocol `defimpl encoder, for: T` in json.ex: 9 edges with callers `encoder.Ecto.Association.NotLoaded.encode` and `encoder.Ecto.Schema.Metadata.encode`.
- Computed remote function name `Ecto.Query.unquote(type)(...)`: 3 edges, `Ecto.Query.unquote`, medium (query.ex:1163, 1168, 1180).
- Functions generated by an external macro (`embed_template` → `repo_template`/`config_template`): 3 low bare edges.
- `expr.(args)` callbacks: 2 edges, type.ex:834 and schema.ex:2056. The tool uses the raw expression text as the callee. That is not a usable ID, and one of them contains spaces and an `&` capture.
- `unquote(__MODULE__).count_alias!` (builder.ex:1082) → `.count_alias!`, low. This is correct by the computed-receiver rule, although `__MODULE__` is statically known.

Query-DSL names are no longer a gap: the current spec makes `field` (27), `type` (2) and `assoc` (1) honest low, and all 30 are counted correct.

## Previous findings

| v3 item | v3 count | v4 count | Status |
|---|---|---|---|
| Mismatch rows ecto.gen.repo.ex:56/57/69: `create_directory`/`create_file` bare low; pattern 1, the `use` guard blocks `import Mix.Generator` (including `embed_template`) | 5 | 5 | **Still present** |
| Mismatch row supervisor.ex:120: `destructure` bare low; pattern 2 | 1 | 1 | **Still present** |
| Mismatch rows ecto.gen.repo.ex:57/64/69: `repo_template`/`config_template` (spec gap) | 3 | 3 | Unchanged (still a spec gap) |
| Mismatch rows association.ex:1488/1489: query-DSL `field`/`type` (spec gap); pattern 4, DSL names `field` 27, `type` 2, `assoc` 1 | 30 | 30 | Unchanged in output. **Now correct** under the current spec (honest low) |
| Pattern 3: callback callee is raw expression text (type.ex:834, schema.ex:2056) | 2 | 2 | **Still present** (spec gap) |
| Pattern 4: `unquote_splicing` low bare edges | 7 | 7 | **Still present.** Reclassified from spec gap to not-a-call (language construct; `unquote` itself is skipped) |
| Pattern 4: `Ecto.Query.unquote` medium | 3 | 3 | Unchanged (spec gap) |
| Pattern 4: variable-protocol `defimpl` callers in json.ex | 9 | 9 | Unchanged (spec gap) |
| Total low bare direct edges | 46 | 46 | Unchanged: 6 wrong (`use` guard 5, `destructure` 1), 7 not-a-call, 33 correct or spec gap |
| v2 items v3 marked fixed (`Inspect.Algebra` imports, `import Ecto.Query, only:`, `defoverridable`, field-chain receivers, `inspect/1` in `defimpl Inspect`, captures, `defdelegate`) | 0 | 0 | **Still fixed.** Re-verified by census: 0 capture-only edges; `defdelegate` gives 1 correct high edge; `Inspect.Algebra.*` 20 medium; `Kernel.defoverridable` 5 medium |
| Not in v3: operator-definition callers in api.ex | not reported (present in v2a/v2b output) | 14 | **New finding**, not a regression |
| Not in v3: file-level calls in json.ex missed | not reported | 2 missed | **New finding** |

Helper scripts are in <fanout>/: `ecto_v4_load.py`, `ecto_v4_sample.py`, `ecto_v4_census.py`, `ecto_v4_callers.py`, `ecto_v4_defs.py`, `ecto_v4_captures.py`, `ecto_v4_missed2.py` and `ecto_v4_lines.py`.
