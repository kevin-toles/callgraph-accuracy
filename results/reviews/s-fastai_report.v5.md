# s-fastai (python): blind call-graph review, round 5

precision 50/50; census ≈99.35% (42 wrong of 6473 in-scope); recall: 0 missed of 69 real calls; 0 non-calls

## Scope
Tool output `final13-A/s-fastai.v2.json` has 6892 edges, all from `.py` files. 419 edges under `nbs/examples/` are out of scope. That leaves **6473 in-scope edges** in 59 files (`fastai/` 6451, `dev_nbs/` 15, `nbs/dltest.py` 7). By confidence: high 1302, medium 2462, low 2553, unknown 156. By call_type: direct 3689, method 2179, constructor 449, callback 156. Breakdown: medium/direct 2283, low/method 1844, low/direct 709, high/direct 697, high/constructor 346, high/method 259, unknown/callback 156, medium/constructor 103, medium/method 76. I ignored the `measured_accuracy` field. Precision sample: seed 20261113, 18 low + 18 medium + 9 high + 5 unknown, over 29 files. All 50 edges are real calls with the correct caller, callee, tier, call_type and line under SPEC. Three of them are spec gaps (#6 decorator, #27 and #35 `builtins.super`), not errors. Each wrong pattern below came from a scripted census and was checked by hand. Helper scripts: `fanout/s-fastai_r5_*.py`.

How the repo affects resolution: fastai reaches most names through chains of star imports. `fastai/imports.py`, `torch_basics.py`, `basics.py` and the `*/all.py` files have no `__all__`, so they re-export everything they import. Feature modules declare `__all__`. The tool follows these chains correctly:
- Star-import resolution to scanned modules agrees with `__all__` in every case: 0 high/medium callees name a non-exported member.
- Aliased imports such as `from torch import zeros_like as t0` resolve to `torch.zeros_like`.
- fastcore and fasttransform names (`L`, `store_attr`, `delegates`, `ifnone`, …; 709 low/direct) are not defined in the scan, so they correctly stay bare low guesses.
- No bare low name matches a scanned top-level definition.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| fastai/collab.py:51 | `dot = self.u_weight(users)* self.i_weight(items)` | `EmbeddingDotBias#forward → fastai.collab.EmbeddingDotBias#u_weight`, medium, method (`i_weight` the same) | `u_weight` / `i_weight`, callback, unknown. Set by tuple assignment at line 45 `(self.u_weight, self.i_weight, …) = [Embedding(*o) …]` | wrong callee / wrong confidence | stored callable attribute read as an inherited method (open defect python/13, tuple assignment) |
| fastai/layers.py:312 | `f,g,h = self.query(x),self.key(x),self.value(x)` | `SelfAttention#forward → fastai.layers.SelfAttention#query` (`#key`, `#value`), medium, method | `query`/`key`/`value`, callback, unknown. Tuple-assigned at line 302 | wrong callee / wrong confidence | same (open defect python/13) |
| fastai/learner.py:225 | `self.pred = self.model(*self.xb)` | `Learner#_do_one_batch → fastai.learner.Learner#model`, medium, method | `model`, callback, unknown. Line 130 `self.dls,self.model = dls,model` | wrong callee / wrong confidence | same (tuple assignment) |
| fastai/learner.py:197 | `self.opt = self.opt_func(self.splitter(self.model), lr=self.lr)` | `Learner#create_opt → Learner#opt_func`, `Learner#splitter`, medium, method | `opt_func`, `splitter`, callback, unknown. Stored by `store_attr(but='dls,model,cbs')` (line 131) | wrong callee / wrong confidence | callable attribute stored through fastcore `store_attr` read as a method |
| fastai/callback/schedule.py:22 | `def __call__(self, pos): return self.f(self.start, self.end, pos)` | `_Annealer#__call__ → fastai.callback.schedule._Annealer#f`, medium, method | `f`, callback, unknown (`store_attr('f,start,end')`). `_Annealer` has no base class at all, so the medium `_Annealer#f` also names a member that is neither defined in the scan nor inherited from outside it (C2) | wrong callee / wrong confidence | same |
| fastai/callback/hook.py:28 | `self.stored = self.hook_func(module, input, output)` | `Hook#hook_fn → Hook#hook_func`, medium, method | `hook_func`, callback, unknown (`store_attr('hook_func,…')`; `class Hook():` has no base, C2) | wrong callee / wrong confidence | same |
| fastai/data/core.py:336 | `return self._dbunch_type(*dls, path=path, device=device)` | `FilteredBase#dataloaders → FilteredBase#_dbunch_type`, medium, method | `_dbunch_type`, callback, unknown. Class-level tuple `_dl_type,_dbunch_type = TfmdDL,DataLoaders`; `FilteredBase` has no base (C2) | wrong callee / wrong confidence | same (tuple assignment) |
| fastai/text/core.py:164, 190, 297, 309 | `if tok is None: tok = WordTokenizer()` | `… → WordTokenizer`, unknown, callback | `fastai.text.core.SpacyTokenizer#<init>`, high, constructor. Line 132 `WordTokenizer = SpacyTokenizer`; C1 requires a call through an alias to use the definition's ID. Even unresolved, a module-level binding is not a bare name | wrong callee / wrong confidence / wrong call_type | module-level alias of a scanned class is not resolved and is left unqualified |
| fastai/data/load.py:106, 175; fastai/callback/wandb.py:94 | `self.rng = random.Random(self.rng.randint(0,2**32-1))` | `… → random.Random`, medium, direct | `random.Random#<init>`, medium, constructor. Under Decisions 2026-10-29 (Python), a standard-library class is "known to be a class" | wrong callee / wrong call_type | stdlib class not recognised as a class (`pathlib.Path`, `collections.Counter`, `io.BytesIO` are recognised) |
| fastai/callback/mixup.py:52 (×2) | `loss = torch.lerp(lf(pred,*self.yb1), lf(pred,*yb), self.lam)` | `MixHandler#lf → lf`, low, direct | `lf`, callback, unknown. A local bound by `with NoneReduce(self.old_lf) as lf:` (line 51) | wrong call_type / wrong confidence | `with … as` binding not treated as a local holding a function |
| fastai/metrics.py:414 | `[self.NGram(x[i:i+n], max_n=max_n) …]` | `CorpusBLEUMetric#get_grams → fastai.metrics.CorpusBLEUMetric#NGram`, medium, method | `fastai.metrics.CorpusBLEUMetric.NGram#<init>`, high, constructor. `class NGram()` is nested in the class at line 406, and the tool's own nodes list `CorpusBLEUMetric.NGram#<init>` | wrong callee / confidence / call_type | nested class reached through `self.` treated as an inherited method |
| fastai/callback/captum.py:111 | `classes=_get_vocab(dl.vocab),` | `insights → _get_vocab`, unknown, callback | `fastai.callback.captum.insights._get_vocab`, high, direct. Line 100 `_get_vocab = lambda vocab: …` | wrong callee / confidence / call_type | open defect python/03 (lambda bound to a local) |
| fastai/torch_core.py:146 (sample #6) | `@use_kwargs_dict(dtype=None, …)` | `fastai.torch_core → use_kwargs_dict`, low, direct | spec gap | spec gap | decorator (python/15) |
| fastai/vision/augment.py:257 (sample #27) | `super().__init__(**kwargs)` | `Resize#<init> → builtins.super`, medium, direct | spec gap | spec gap | `super()` edge (python/14) |
| fastai/vision/augment.py:52 (sample #35) | `return super().__call__(b, split_idx=split_idx, **kwargs) if self.do else b` | `RandTransform#__call__ → builtins.super`, medium, direct | spec gap | spec gap | `super()` edge (python/14) |

The other 26 stored-attribute edges are listed by `python3 s-fastai_r5_census.py P1`.

## Systematic patterns (scripted counts; union = 42)
1. **Stored callable attribute called through `self.` → `Type#attr`, medium, method: 33 edges.** SPEC wants `attr`, callback, unknown. The tool does produce callbacks when an attribute is assigned with a plain `self.x = …` (34 such edges are correct, for example `ResBlock#forward → convpath`). It fails in three cases:
   - Tuple or multi-target assignment, including a class-level tuple: 18 edges (EmbeddingDotBias ×4, SelfAttention ×3, PooledSelfAttention2d ×3, MixHandler `old_lf`, CSVLogger `old_logger`, TrackerCallback `comp`, FilteredBase `_dbunch_type`, Learner `model`, Tabular `procs`, SpacyTokenizer `pipe`, WeightDropout `module`). This is CAPABILITIES open defect python/13.
   - Attributes stored through fastcore `store_attr(...)`: 15 edges (Hook `hook_func`, _Annealer `f`, TimeDistributed `module` ×2, Learner `opt_func`/`splitter`/`loss_func`, ValueMetric `func`, AccumMetric `func` ×2, Tokenizer `tok`, SentenceEncoder `module`, GANLoss ×2, XResNet `block`).
   - In 6 of the 33, the class's whole ancestry is in the scan (`_Annealer`, `Hook`, `FilteredBase`, `ValueMetric`, `AccumMetric` ×2). There the medium `Type#attr` is also an invented ID (C2).
2. **Module-level class alias called → bare `WordTokenizer`, callback/unknown: 4 edges.** Target is `SpacyTokenizer#<init>` per C1.
3. **`random.Random(...)` → direct instead of `random.Random#<init>` constructor: 3 edges.**
4. **`with … as lf` local called → bare `lf` low/direct instead of a callback: 2 edges.**
5. **Nested class through `self.NGram(...)` → `Type#NGram` medium/method: 1 edge.**
6. **Lambda bound to a local called → callback (open defect python/03): 1 edge.**

Checks that found nothing:
- All 1302 high edges name a definition my AST index finds.
- Every high/method `self.m()` names the nearest defining class in the scanned MRO.
- No callback names a nested def.
- No high constructor targets a non-class.
- Line numbers match the callee's name everywhere. The 23 apparent misses are the aliased imports `t0`/`t1` → `torch.zeros_like`/`torch.ones_like`, which are correct.

## Missed-call patterns (recall)
I checked every call in three functions: `fastai.learner.Learner#get_preds` (learner.py:291–326, 28 calls), `fastai.vision.augment.aug_transforms` (augment.py:1238–1268, 19 calls) and `fastai.text.core._tokenize_files` (text/core.py:187–206, 22 calls). The tool emits an edge for all 69, with no non-calls. One more invocation is not counted because it is spec gap G9 below: learner.py:323 `getcallable(self.loss_func, 'decodes')(res[pred_i])`, which calls a call result and gets no edge.

## Spec gaps (counted separately, not wrong)
- **G1 `super()` itself: 111 edges `→ builtins.super`, medium, direct** (e.g. augment.py:257 `super().__init__(**kwargs)`). The constructor/method edge beside it is emitted as SPEC requires. Superclass in the scan gives `Parent#<init>`/`Parent#m` high. Otherwise you get `torch.nn.Module#<init>` medium, or `.__init__` low for fastcore bases reached only through star imports. Open question (CAPABILITIES python/14): does `super()` emit its own `builtins.super` edge besides the `Parent#<init>` / `.m` edge?
- **G2 Decorators: 120 edges on decorator lines** (`@delegates(Learner.__init__)` 96, `@use_kwargs_dict(...)` 8, `@patch` 7, `@module(...)` 6, and others). Open question (python/15): is a decorator application a call edge, what is its caller (the module/class, or the decorated function), and which line does it go on?
- **G3 Python type annotations and constructor-bound locals as typed receivers: 45 edges.**
  - 39 calls on a parameter annotated with a scanned class whose method is defined there. 36 of these are `self:Learner` in `@patch` functions, e.g. schedule.py:117 `self.create_opt()` → `self.create_opt` low.
  - 6 calls on a local bound to a scanned constructor, e.g. learner.py:319 `cb.all_tensors()` with `cb = GatherPredsCallback(...)` → `cb.all_tensors` low.
  - The tool never types a receiver from these. Open question: Decision A names "all statically typed languages and typed PHP/Groovy declarations", and the JS/TS note adds `= new Foo()`. Does Decision A, and the let-bound call-result rule, apply to Python annotations `def f(x: T)` and to `x = T(...)`?
- **G4 Lowercase builtin and stdlib classes: 582 edges as `builtins.X`/`mod.X`, direct.** 535 are builtins (`range`, `zip`, `list`, `int`, `dict`, `type`, …). 47 are stdlib (`functools.partial` 32, `collections.defaultdict` 10, `itertools.*`, `operator.*`). Also `threading.Lock` ×2, which is a class only from Python 3.13. Open question: the Python ruling says a builtin or stdlib class is "known to be a class" when it decides a *capitalized* call, and the per-language note gives the builtin form as `builtins.len`. Does the constructor form `T#<init>` also apply to lowercase class names such as `dict(...)` or `partial(...)`?
- **G5 Classes generated by a decorator: 12 edges.**
  - 11 calls of functions decorated `@module(...)` in layers.py are emitted as direct calls of the function, e.g. `fastai.layers.Flatten`, `SigmoidRange`, `Lambda`. `module()` returns an `nn.Module` subclass whose `__init__` `setattr`s the fields.
  - 1 edge `PartialLambda#func` (medium, method) is a field that this generated `__init__` sets on the superclass `Lambda`.
  - Open question: is a call of a decorator-produced class a constructor, and is its `setattr` field a stored callable attribute?
- **G6 `@patch` methods: 5 callee edges, plus 583 edges whose caller is one of 100 `@patch` functions.**
  - Callee side: `TextLearner#freeze` ×2, `LMLearner#no_bar`, `TensorPoint#_do_crop_pad`, `TensorImage#affine_coord`, all medium. Each method is defined in the scan as `@patch def freeze(self:Learner)` and installed on the class at runtime.
  - Caller side: the tool names these callers `mod.f` (e.g. `fastai.callback.schedule.fine_tune`). I judged that correct under the free-function ID rule.
  - Open question: does `@patch def f(self: T)` define `mod.f` or `T#f`, and is a call of it `T#f` high?
- **G7 Methods created by `exec` in a class body: 6 edges.** `DataLoader#before_iter`/`after_batch`/`after_iter`/`after_item`/`before_batch` and `TfmdDL#after_batch`, all medium. load.py:90 `for o in _noop_methods: exec(f"def {o}(self, x=None, *args, **kwargs): return x")`, and `__init__` may override them with instance attributes. Open question: what ID and tier does a call of an `exec`-defined method get?
- **G8 `GetAttr.__getattr__` delegation: 2 edges.** `Recorder#logger` (learner.py:599 `self.logger(self.log)`, which reaches `learn.logger`) and `GradientClip#parameters`, both medium. Open question: is a member that is reached only through an external base's `__getattr__` delegation an inherited member `Type#m`, or a stored callable on the delegate?
- **G9 Invoking a call result or subscript: 60 constructs, no edge** (e.g. callback/core.py:63 `getcallable(self, event_name)()`, tabular/data.py:34 `RandomSplitter()(df)`). The inner calls are emitted. Open question: SPEC's callback rule needs a variable name, and C4 needs a name, `recv.m` or `.m`. What ID does an invocation of a call result get, or is it emitted at all?
- **G10 Module-level alias of an external function: 1 edge.** captum.py:20 `_json_clean(o)` with `_json_clean=jsonutil.json_clean` gives callback/unknown `_json_clean`. Open question: SPEC has explicit alias rules for Lua, Zig and JS/TS, and C1 covers aliases of scanned definitions. Does a Python module-level alias of an *external* function resolve to its target (`…jsonutil.json_clean`, medium)?
