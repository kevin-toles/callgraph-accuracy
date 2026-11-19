# s-trlx (python) blind call-graph review, round 5

precision 50/50; census ≈98.8% (37 wrong of 2964 in-scope); recall: 3 missed of 79 real calls; 0 non-calls

## Scope
Tool output `<scans>/final13-A/s-trlx.v2.json` holds 5211 edges, all from `.py` files. 2964 are in scope: 29 files, every one under `trlx/` plus `setup.py`. The rest come from `docs/`, `examples/` and `tests/`, which are excluded. The repo has no other Python outside those folders (`scripts/` holds only shell scripts).
- By confidence: medium 1424, low 1045, high 416, unknown 79.
- By call_type: direct 1469, method 1241, constructor 175, callback 79.
- Combined: medium/direct 1262, low/method 1043, high/direct 205, high/method 114, high/constructor 97, medium/method 84, unknown/callback 79, medium/constructor 78, low/direct 2.

I ignored `measured_accuracy`. All 416 high callees are in `nodes`.

Precision sample: seed 20261113, stratified as medium 22, low 16, high 7, unknown 5, over 20 files (`s-trlx_r5_sample.py`). None of the 50 edges is wrong. One is a spec gap: #10, `super().__init__()` → `builtins.super` (CAPABILITIES python/14). It is counted as not wrong, so the score is 50/50. 49 edges are confirmed correct outright.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| trlx/trainer/accelerate_ppo_trainer.py:157 | `outputs = self.model(` | AcceleratePPOTrainer#loss → `trlx.trainer.accelerate_ppo_trainer.AcceleratePPOTrainer#model`, medium, method | `model`, unknown, callback (`self.model = self.setup_model()` is assigned in the scanned superclass AccelerateRLTrainer) | wrong callee / wrong confidence | open defect python/13: a callable attribute set by a superclass is made a method (recall) |
| trlx/trainer/accelerate_ppo_trainer.py:180 | `outputs = self.model(tokens, attention_mask, return_dict=True, position_ids=position_ids)` | same → `AcceleratePPOTrainer#model`, medium, method | `model`, unknown, callback | wrong callee / wrong confidence | open defect python/13 (recall) |
| trlx/models/modeling_ppo.py:664 | `hidden_states = self.final_norm(hidden_states)` | GPTModelBranch#forward → `trlx.models.modeling_ppo.GPTModelBranch#final_norm`, medium, method | `final_norm`, unknown, callback (`self.final_norm = deepcopy(final_norm)` in ModelBranch.__init__, line 532) | wrong callee / wrong confidence | open defect python/13 (census) |
| trlx/models/modeling_ilql.py:317 | `outputs = self.base_model(**forward_kwargs)` | AutoModelForCausalLMWithILQLHeads#forward → `…AutoModelForCausalLMWithILQLHeads#base_model`, medium, method | `base_model`, unknown, callback (assigned in PreTrainedModelWrapper.__init__, modeling_base.py:71) | wrong callee / wrong confidence | open defect python/13 (census) |
| trlx/trainer/accelerate_base_trainer.py:429 | `rewards = self.reward_fn(` | AccelerateRLTrainer#evaluate → `…AccelerateRLTrainer#reward_fn`, medium, method | `reward_fn`, unknown, callback (assigned in BaseRLTrainer.__init__, trainer/__init__.py:47) | wrong callee / wrong confidence | open defect python/13 (census) |
| trlx/trainer/nemo_ilql_trainer.py:157 | `return flatten_dataclass(ILQLBatch)(batch)` | NeMoILQLTrainer#learn.collate_fn → `trlx.data.ilql_types.flatten_dataclass`, medium, direct | `trlx/data/ilql_types.py` defines no `flatten_dataclass`, since the import names a missing symbol. C2 says an ID is never invented, and C4 says an unresolved call is a low guess. The tool also lists this invented ID in `nodes`. | wrong callee / wrong confidence | import of a name the scanned module does not define is resolved to an invented module member (census) |
| trlx/models/modeling_nemo_ppo.py:949 | `batch = unflatten_dataclass(PPORLBatch)(flat_batch)` | PPOGPT#get_forward_output_and_loss_func.fwd_output_and_loss_func → `trlx.data.ilql_types.unflatten_dataclass`, medium, direct | same as above; `unflatten_dataclass` is not defined in ilql_types.py | wrong callee / wrong confidence | same (census) |
| trlx/utils/loading.py:28 | `_trainers_unavailble(["NeMoILQLTrainer", "NeMoSFTTrainer", "NeMoPPOTrainer"])` | trlx.utils.loading → `_trainers_unavailble`, low, direct | `trlx.utils.loading._trainers_unavailble`, high, direct. It is defined at line 20 inside `except ImportError:` and is already in `nodes`. | wrong callee / wrong confidence | a module-level def inside try/except is not used to resolve a bare call (census) |
| trlx/trlx.py:92 | `trainer = get_trainer(config.train.trainer)(` | only `trlx.utils.loading.get_trainer`, high | a second call, of the returned value | missed call | a call of a call result emits no edge (C4), and how to name it is a spec gap (recall) |
| trlx/trlx.py:110 | `pipeline = get_pipeline(config.train.pipeline)(` | only `get_pipeline` | a second call, of the returned value | missed call | same (recall) |
| trlx/trlx.py:134 | `eval_pipeline = get_pipeline(config.train.pipeline)(` | only `get_pipeline` | a second call, of the returned value | missed call | same (recall) |
| trlx/models/modeling_nemo_ppo.py:83 | `super().__init__()` | ParallelLinear#<init> → `builtins.super`, medium, direct (also emits `torch.nn.Module#<init>`, constructor) | undecided | spec gap | CAPABILITIES python/14 (sample #10) |

## Systematic patterns (wrong; scripted in `s-trlx_r5_census.py`)
1. **32 edges: a callable attribute assigned in a scanned superclass is emitted as a method `Type#attr` (medium, method).** It should be a callback named after the attribute, unknown. This is open defect python/13.
   - Attributes affected: `self.model`, `self.reward_fn`, `self.metric_fn`, `self.tokenizer` (set in AccelerateRLTrainer/BaseRLTrainer); `self.base_model` (set in PreTrainedModelWrapper); `self.final_norm`, `self.lm_head` (set in ModelBranch).
   - The same attributes set in the calling class's own `__init__` are emitted correctly as callbacks, for example `self.v_head`, `self.frozen_head`, and `self.get_head_mask` in GPTBigCodeModelBranch.
   - The tool also lists 14 of these attribute IDs as nodes (for example `GPTModelBranch#final_norm`), as if they were defined methods.
   - The script excludes `get_head_mask` at modeling_ppo.py:610/847. There it is the inherited transformers method (medium `Type#m` is correct), because only GPTBigCodeModelBranch assigns it.
   - Hand-checked: accelerate_ppo_trainer.py:157/180/311/346, modeling_ppo.py:664/674, modeling_ilql.py:317, nemo_ppo_trainer.py:196.
2. **4 edges: invented IDs.** `trlx.data.ilql_types.flatten_dataclass` and `trlx.data.ilql_types.unflatten_dataclass` are medium/direct, but neither is defined in `trlx/data/ilql_types.py` (the import is broken in the source). Both IDs also appear in `nodes`. This violates C2.
3. **1 edge: bare low guess for a scanned module-level def inside `try/except`** (`_trainers_unavailble`, loading.py:28).

Union: 37 wrong of 2964 in-scope edges, so census precision is 1 − 37/2964 = 98.75%.

## Missed-call patterns (recall)
Recall functions:
- `trlx.trlx.train`: 27 real calls, 24 emitted, 3 missed.
- `trlx.pipeline.offline_pipeline.tokenize_dialogue`: 26 real calls, 26 emitted.
- `AcceleratePPOTrainer#loss`: 26 real calls, 26 emitted. Two of them (`self.model`, lines 157/180) are pattern 1 above.

In total, 3 of 79 calls were missed and none of the edges were non-calls.
- **Call of a call result `f(x)(y)`: 8 sites in scope, no edge for the outer call.** Sites: trlx.py:92/110/134, loading.py:26, modeling_nemo_ilql.py:616, modeling_nemo_ppo.py:949, nemo_ilql_trainer.py:157, nemo_ppo_trainer.py:300. The inner call is emitted; the second call is dropped.

## Spec gaps (counted separately, not wrong)
- **`super()` call itself: 44 edges `→ builtins.super`, medium, direct.** Each sits beside the `Parent#<init>` constructor edge, or beside `PreTrainedModelWrapper#post_init` / `.generate` / `.model_provider_func`. Construct: `super().__init__()` / `super().post_init()`. Open question (CAPABILITIES python/14): is the `super()` call itself an edge, in addition to the edge for the method it reaches?
- **Decorators: 18 decorator applications, no edges.** Construct: `@register_trainer`, `@register_method`, `@register_datapipeline` and `@contextmanager`. Open questions (CAPABILITIES python/15): is applying a decorator a call edge? Which caller does it get, and which line?
- **Python type annotations as typed receivers: 27 `logger.*` low edges.** Construct: `logger = logging.get_logger(__name__)` at module level, with `def get_logger(name: Optional[str] = None) -> MultiProcessAdapter:` in the scanned `trlx/utils/logging.py`. Open question: do decision A, "Typed call results" and the let-bound-local ruling apply to Python return annotations, and to module-level (not local) bindings? If they do, `logger.info` would name `MultiProcessAdapter`. SPEC lists statically typed languages and the like, but not Python.
- **Callee naming for a call of a call result: the 8 sites above.** Construct: `get_trainer(config.train.trainer)(config=config, …)`. Open question: SPEC gives `.m` for a method on a computed receiver, but does not say what ID (or call_type) a direct call of a returned value takes.

## Helper scripts
`<fanout>/`:
- `s-trlx_r5_load.py`
- `s-trlx_r5_sample.py`
- `s-trlx_r5_attr.py`
- `s-trlx_r5_misc.py`
- `s-trlx_r5_inherit.py`
- `s-trlx_r5_recall.py`
- `s-trlx_r5_census.py`
