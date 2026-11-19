# h-distilabel (python): blind call-graph review, round 8

precision 50/50; census ≈99.8% (10 wrong of 4653 in-scope); recall: 0 missed of 25 real calls; 0 non-calls

## Scope
Tool output `<scans>/final13-A/h-distilabel.v2.json` has 9147 edges, all from `.py` files. I excluded `tests/` (4195), `examples/` (230) and `docs/` (69). That leaves **4653 in-scope edges**, all under `src/distilabel/` (141 files).
- Confidence: medium 2033, low 1663, high 921, unknown 36.
- call_type: method 2299, direct 2045, constructor 273, callback 36.
- Combined: low/method 1663, medium/direct 1810, high/method 600, high/direct 235, medium/constructor 187, high/constructor 86, unknown/callback 36, medium/method 36.

I ignored the `measured_accuracy` field. Helper scripts are in the fanout folder with the prefix `h-distilabel_r8_`.

## Method
- **Precision sample:** seed 8, stratified as unknown 5 / high 10 / low 16 / medium 19, covering 36 files (`h-distilabel_r8_sample.py`). For each edge I checked the source line, the caller, the callee ID, the tier, the call_type and the line number. All 50 are correct under SPEC.
  - Python gets no receiver typing (decision A excludes it; golden python/05), so receiver guesses are `recv.m` / `.m`, low.
  - Builtins and stdlib classes follow the 2026-10-29 Python ruling as clarified on 2026-11-12. Class-body code has the class as its caller.
- **Recall:** I listed every call in three functions and compared them with the tool's edges. All 25 calls have edges; there are no extra edges.
  - `distilabel.utils.dicts.merge_dicts`: 13 calls.
  - `distilabel.steps.filtering.minhash.MinHashDedup#process`: 8 calls.
  - `distilabel.pipeline.base.BasePipeline#_add_edge`: 4 calls.
- **Whole-scope cross-check** (`h-distilabel_r8_missed.py`, `h-distilabel_r8_noncall.py`): I matched every `ast.Call` in `src/` (4655) against the edges, using the line of the callee name.
  - One call has no edge.
  - No line has more edges than calls. The 24 repeated (caller, callee, line) tuples are genuinely repeated calls on that line.
  - Every edge's callee name, or its import alias, appears on its reported line (`h-distilabel_r8_lowcheck.py`).
- **self-call check** (`h-distilabel_r8_selfres.py`): `self.m()` resolution against AST class definitions turned up no wrong-class resolutions. Every high callee is in `nodes`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/distilabel/pipeline/base.py:1922 | `self._stop()` (inside nested `def signal_handler` of `_handle_keyboard_interrupt`) | `…BasePipeline#_handle_keyboard_interrupt.signal_handler` → `self._stop`, low, method | → `distilabel.pipeline.base.BasePipeline#_stop`, high, method | wrong callee / wrong confidence | `self` captured by a nested function is not treated as the method's `self` |
| src/distilabel/pipeline/batch_manager.py:1106 | `self.save(path=batch_file, format="json", dump=batch_dump)` (nested `def save_batch` in `_BatchManager#cache`) | `…_BatchManager#cache.save_batch` → `self.save`, low, method | → `distilabel.utils.serialization._Serializable#save`, high, method (inherited from a scanned base) | wrong callee / wrong confidence | same |
| src/distilabel/models/llms/litellm.py:249 | `completion: … = await self._aclient(` (nested `async def _call_aclient_until_n_choices` in `agenerate`) | `…LiteLLM#agenerate._call_aclient_until_n_choices` → `self._aclient`, low, method | → `_aclient`, unknown, callback (`_aclient: Optional[Callable] = PrivateAttr(...)`, assigned `litellm.acompletion`) | wrong callee / call_type / confidence | same; it also misses that the attribute holds a callable |
| src/distilabel/pipeline/routing_batch_function.py:73 | `routed_steps = self.routing_function(steps)` | `…RoutingBatchFunction#route_batch` → `…RoutingBatchFunction#routing_function`, medium, method | → `routing_function`, unknown, callback (class field `routing_function: RoutingBatchFunc`, a Callable alias; no such method) | wrong callee / call_type / confidence | a callable attribute declared as a class-body field is treated as a method (matches open defect python/13) |
| src/distilabel/exceptions.py:40 | `super().__init__(f"Batch generation with jobs_ids={jobs_ids} is not finished")` | `…DistilabelOfflineBatchGenerationNotFinishedException#<init>` → `.__init__`, low, method | superclass constructor call: → `distilabel.exceptions.DistilabelGenerationException#<init>`, constructor (the parent is in the scan, so the `.member` computed-`super` form does not apply) | wrong callee / call_type | an in-scan parent with no explicit `__init__` falls back to a computed-receiver guess. Compare `pipeline/ray.py:73` → `BasePipeline#<init>` and `pipeline/local.py:102` → `multiprocessing.pool.Pool#<init>` |
| src/distilabel/pipeline/_dag.py:951 | `edge_label = ":".join(list(dict.fromkeys(edge_label)))` | `DAG#…` → `builtins.dict.fromkeys`, medium, direct | `Type.m()` on a builtin type → `builtins.dict#fromkeys`, medium, method | wrong callee / call_type | a lowercase builtin/stdlib class is treated as a module |
| src/distilabel/utils/dicts.py:42 | `k: list(chain.from_iterable(v)) for k, v in combined_dict.items()` | `group_dicts` → `itertools.chain.from_iterable`, medium, direct | `itertools.chain#from_iterable`, medium, method (`chain` is a stdlib class; compare `transformers.AutoTokenizer#from_pretrained`) | wrong callee / call_type | same |
| src/distilabel/cli/pipeline/utils.py:150 | `sys.path.insert(0, os.getcwd())` | `get_pipeline_from_url` → `sys.path.insert`, medium, direct | `sys.path` is a list attribute, not a module: `path.insert`, low, method | wrong callee / call_type / confidence | a module attribute chain is treated as a module-function path |
| src/distilabel/models/llms/litellm.py:118 | `for key in logging.Logger.manager.loggerDict.keys():` | `LiteLLM#load` → `logging.Logger.manager.loggerDict.keys`, medium, direct | `loggerDict.keys`, low, method | wrong callee / call_type / confidence | same |
| src/distilabel/utils/logging.py:83 | `queue_listener = QueueListener(` (`from logging.handlers import QueueHandler, QueueListener`) | `setup_logging` → `logging.handlers.QueueListener`, medium, direct | known stdlib class → `logging.handlers.QueueListener#<init>`, medium, constructor. Line 100 `QueueHandler(log_queue)` does get `#<init>` constructor | wrong callee / call_type | incomplete stdlib-class knowledge |
| src/distilabel/envs.py:47 | `return ENVIRONMENT_VARIABLES[name]()` | (no edge) | C4: an unresolved call is still emitted (see spec gap 9 for its name) | missed call | calls whose callee expression is a subscript are dropped |

## Systematic patterns (wrong, scripted counts in `h-distilabel_r8_census.py`; union 10)
1. **`self.m()` inside a nested function of a method left as the literal `self.m`, low: 3.** The selector is any callee starting with `self.`. I checked all 3 by hand. All other nested-function edges with `self.` calls on their line are absent, so this is the whole pattern.
2. **Lowercase builtin/stdlib class method named as a module function (`builtins.dict.fromkeys`, `itertools.chain.from_iterable`): 2.**
3. **Attribute of a non-module object promoted to a module-function ID, medium direct (`sys.path.insert`, `logging.Logger.manager.loggerDict.keys`): 2.** I read every medium/direct callee with 3 or more segments (64 distinct IDs); only these two pass through a non-module attribute. `matplotlib.pyplot.cm.Spectral` is listed under spec gaps.
4. **Python `super().__init__` with an in-scan parent emitted as `.__init__` low: 1.**
5. **Callable class-body field called through `self` named `T#field`, medium method (open defect python/13): 1.**
   - Every other `self.<attr>()` on a non-method attribute is a correct callback: `_hasher`, `_model`, `_tokenizer`, `_pipeline`, `_truncator`, `_formatter`, `_image_to_str`, `_image_from_str`, `_make_sampler`, `_mlx_generate`, `_ChatMessage`.
   - Script: every `self.X(` where no `def X` exists in `src/`.
6. **Capitalized stdlib class called as direct: 1** (`logging.handlers.QueueListener`).
   - Other stdlib capitalized direct callees are factories, correctly direct: `threading.Lock`, `multiprocessing.Queue`, `multiprocessing.Manager`.
   - All 187 medium constructors are builtins or stdlib classes; none is a third-party name.

Census precision = 1 − 10/4653 = 99.79%.

## Missed-call patterns (recall)
- **Three-function recall:** 0 missed of 25.
- **Whole scope:** 1 missed of 4655 source calls: `ENVIRONMENT_VARIABLES[name]()` (envs.py:47), a call whose callee is a subscript.
  - The 7 other unmatched calls are aliased imports (`_vLLM(`, `_DBSCAN(`, `_UMAP(`, `OpenAIChatCompletion(`, `_ordered_storage(`, `_unordered_storage(`). They are present under their target IDs and are correct.
- **Bare decorators (no call written), 311 in scope:** no edge. These are not counted as missed (spec gap 3).

## Spec gaps (counted separately, not wrong; union ≈498 edges)
1. **`builtins.super` edge for `super()`: 101 edges** (open question python/14). Construct: `super().load()` emits `builtins.super`, medium, direct, plus the target edge. SPEC does not say whether the `super()` call itself is an edge.
2. **Lowercase builtin/stdlib classes called directly: 373 edges.**
   - Construct: `str(x)`, `list(...)`, `set(...)`, `dict(...)`, `type(None)`, `int(...)`, `range(...)`, `enumerate(...)`, `zip(...)`, `defaultdict(list)`, `functools.partial(...)`, `contextlib.suppress(...)`. The tool emits `builtins.str` / `collections.defaultdict`, medium, direct.
   - Question: SPEC's Python ruling covers only external *capitalized* names ("Known to be a class: a builtin (`builtins.ValueError`) or a standard-library class"). It does not say whether a lowercase builtin or stdlib class call is a direct call (`builtins.str`) or a constructor (`builtins.str#<init>`).
   - The golden fixtures python/03 and python/06 use `builtins.map`, direct, but SPEC text does not decide it.
3. **Decorator call edges: 12 edges** (open question python/15). Construct: `@model_validator(mode="after")` → `pydantic.model_validator`; `@app.command()` → `app.command`; `@routing_batch_function(...)`. SPEC leaves open:
   - whether the decorator call is an edge;
   - its caller and its line;
   - whether the bare decorators (311, no edge) are calls.
4. **Calls in parameter default values and annotations: 13 edges.**
   - Construct: `config: Optional[str] = typer.Option(` (cli/pipeline/app.py:47) and `key: Optional[Callable] = lambda x: int(x.stem)` (utils/files.py:20). The tool's caller is the function being defined (`distilabel.cli.pipeline.app.run`).
   - Question: these run once at definition time, in the enclosing scope. SPEC calls function heads declarations and does not say whether the caller is the defined function or the enclosing module/class.
5. **`super().__init__(...)` where the parent is outside the scan: 2 edges.**
   - Construct: `super().__init__()` in `ComponentsGalleryPlugin(BasePlugin[...])` (components_gallery.py:166) gives `.__init__`, low, method. `super().__init__(` in `_NoDaemonPool(Pool)` (pipeline/local.py:102) gives `multiprocessing.pool.Pool#<init>`, medium, constructor.
   - Question: SPEC has two rules that both apply: "Superclass constructor calls (`super(...)` …) → `Parent#<init>`" and "computed receiver (`super` when the superclass is not in the scan): `.member`". It does not say which governs Python's `super().__init__` with an external parent.
6. **`super().m()` where the scanned bases do not define `m` (it comes from `object`/pydantic through scanned bases): 2 edges.**
   - Construct: `return super().__repr__()` in `BasePipeline(ABC, RequirementsMixin, _Serializable)` (pipeline/base.py:793), and `super().model_post_init(__context)` in `_Step` (steps/base.py:215). Both give `.m`, low.
   - Question: SPEC's `.member` form is for "`super` when the superclass is not in the scan". It does not say what to emit when the superclasses are in the scan but the method is inherited from beyond them (cf. `self.m()` → `Type#m`, medium).
7. **Class defined inside a method body: 2 edges.**
   - Construct: `class MultiLabelSchema(BaseModel): …` then `return MultiLabelSchema.model_json_schema()` (steps/tasks/text_classification.py:354, 359). These give `MultiLabelSchema.model_json_schema`, low.
   - Question: SPEC names nested functions in a method (`C#m.inner`) and nested types in types (`Outer.Inner`). It gives no ID for a class local to a method, so it does not say whether `Type.m()` on it is a named call.
8. **Call through an imported module-level non-function binding: 1 edge.**
   - Construct: `from distilabel.cli.app import app` then `app(prog_name="distilabel")` (`__main__.py:18`), where `app = typer.Typer(...)`. The tool emits `app`, unknown, callback.
   - Question: for Python, SPEC does not say whether the callee is the bare variable name or the binding's canonical ID (`distilabel.cli.app.app`), as the JS/TS module-binding ruling gives.
9. **Call of a callable object exported as a module attribute: 1 edge, plus the 1 missed subscript call.**
   - Construct: `plt.cm.Spectral(np.linspace(...))` (text_clustering.py:166) gives `matplotlib.pyplot.cm.Spectral`, medium, direct.
   - Construct: `ENVIRONMENT_VARIABLES[name]()` has no edge.
   - Question: SPEC does not say whether a call through a module attribute that holds a non-function callable is a direct call of that name or a callback. It also gives no callee name for a call whose callee expression is a subscript (`.?` vs a variable name).
