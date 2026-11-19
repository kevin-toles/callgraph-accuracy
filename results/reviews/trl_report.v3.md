# trl (python) call-graph review (v3)

Summary: precision 50/50; census ≈99.77% (38 wrong of 16737 in-scope); recall: 2 missed of 160 real calls; 0 non-calls

**Scope.** `trl.v2.json` has 31,168 edges, and its edge set is identical to the first-round `trl.json` (0 edges added, 0 removed). 16,737 edges are in scope: `.py` files under `trl/` (15,667) and `scripts/` (1,070), excluding tests/ and examples/.
- By confidence: medium 7,918, low 6,370, high 2,248, unknown 201.
- By call_type: direct 7,960, method 7,133, constructor 1,443, callback 201.

**Precision sample.** I drew 50 edges with seed 3003, stratified as 8 high, 21 medium, 16 low and 5 unknown, across 40 files (script: `trl_v3_sample.py`, edges in `trl_v3_sample.json`). All 50 are correct per the spec. For each one I checked:
- that it is a real call
- the caller, against the enclosing def chain from `ast`
- the callee
- the confidence tier
- the line, on multi-line calls such as rloo_trainer.py:1613 `len(prompts)` inside a wrapped expression

Notable correct cases in the sample:
- **Nested function as caller:** activation_offloading.py:528 has caller `OffloadActivations#__init__.unpack_tensor_with_streams.hook`.
- **Class-body callers:** grpo_config.py:657, dpo_config.py:217 and prm_config.py:80 `field(` have caller `pkg.mod.C`.
- **`cls.` in a classmethod:** modeling_value_head.py:261 → `PreTrainedModelWrapper#add_and_load_reward_modeling_adapter` (high).
- **Module-level code in `scripts/generate_tiny_models`** (a package with `__init__.py`): caller is `generate_tiny_models.for_….<file>`, and calls to `_common.push_to_hub` are high.
- **Callbacks through parameters and getattr locals:** accuracy_rewards.py:111 `log_extra(`, sdft_trainer.py:479 `callback_fn(`, online_dpo_trainer.py:587 `tokenizer(` on a staticmethod parameter, and a2po_trainer.py:202 `model(`.
- **Callback through a stored attribute assigned in the class:** gold_trainer.py:2541 `self.liger_loss(` → `liger_loss` (unknown, callback).

**Census method.** A 50/50 sample only bounds precision at about 94% (rule of three), so I compared every in-scope edge with an independent `ast` walk of the source (`trl_v3_ast.py`, `trl_v3_match.py`).
- **Line and callee name:** 16,732 of the 16,737 edges match an AST call on the same line with the same callee name. The other 5 are aliased imports that the tool resolved correctly, for example `make_vllm_serve_parser(` → `trl.scripts.vllm_serve.make_parser`. No edge lacks a matching call.
- **Callers:** all 16,732 matched edges have exactly the caller ID derived from the AST. There were 0 caller mismatches.
- **Callees:** I classified each callee by the binding of its name or receiver (`trl_v3_names.py`, `trl_v3_recv.py`, `trl_v3_chain.py`), by a class-hierarchy MRO over the scanned classes (`trl_v3_classes.py`, `trl_v3_selfcheck.py`), and by which `self.` attributes are assigned in scanned code (`trl_v3_attrs.py`).
- **Confidence:** every high callee exists as a scanned definition (1,170 import-resolved and 277 module-local), and no medium import edge points at a scanned definition.

**Recall** (3 functions in 3 files, none from v2). 160 real calls in total, 158 found, 2 missed, 0 non-calls.
- `trl.data_utils._pack_bfd` (data_utils.py:739–826): 59 real calls, 59 found, 0 missed, 0 non-calls.
  - The `pyarrow.compute as pc` and `numpy as np` aliases resolve, and `_SegmentTree(` gives `#<init>` (high).
  - Line 760 shows the computed-root chain pattern (pattern 2 below).
- `trl.trainer.grpo_trainer.GRPOTrainer#_tool_call_loop` (grpo_trainer.py:1981–2218): 93 real calls, 91 found, 2 missed, 0 non-calls.
  - The misses are the dict-indexed tool calls on :2018 and :2020.
  - The nested `_run_async_tools(` → `…#_tool_call_loop._run_async_tools` (high).
  - The `del` statements and comprehensions gave no false edges.
- `trl.generation.vllm_client.VLLMClient#get_sequence_logprobs` (vllm_client.py:590–664): 8 real calls, 8 found, 0 missed, 0 non-calls.
  - Its nested `send` has 3 calls: 2 have the wrong callee (pattern 3), and the third, `zip`, is correct.

## Mismatch table

No sampled edge was wrong. These rows come from the census and the recall check. In the "tool said" column, an edge written as `→ X` keeps the caller from the row above, or the caller is the enclosing method (all callers were verified correct).

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| trl/trainer/dpo_trainer.py:328 | `processed_prompts = self.processor(` | `DataCollatorForVisionPreference#torch_call` → `trl.trainer.dpo_trainer.DataCollatorForVisionPreference#processor`, medium, method | `processor` is a dataclass field (`processor: ProcessorMixin`, :299), so this is a call through a stored property holding a callable: `processor`, unknown, callback | wrong callee / confidence / call_type | a class-level annotated field is treated as a method, not as an attribute |
| trl/experimental/utils.py:323 | `message_input_ids_full = self.tokenizer(` | `DataCollatorForChatML#__call__` → `…DataCollatorForChatML#tokenizer`, medium, method | the dataclass field `tokenizer: PreTrainedTokenizerBase` (:276) gives `tokenizer`, unknown, callback. An attribute assigned in `__init__` in iw_opd_trainer.py:249 correctly gives `tokenizer`, unknown, callback | wrong callee / confidence / call_type | same |
| trl/experimental/ppo/modeling_value_head.py:747 | `base_model_output = self.pretrained_model(` | `AutoModelForCausalLMWithValueHead#forward` → `…AutoModelForCausalLMWithValueHead#pretrained_model`, medium, method | the attribute is assigned in the scanned superclass `PreTrainedModelWrapper.__init__` (`self.pretrained_model = pretrained_model`, :83), so it is `pretrained_model`, unknown, callback | wrong callee / confidence / call_type | attribute assignments in a scanned superclass are not seen from the subclass |
| trl/data_utils.py:760 | `offsets = np.arange(np.sum(num_fragments) + 1, dtype=columns[0].offsets.type.to_pandas_dtype()) * seq_length` | `_pack_bfd` → `.to_pandas_dtype`, low, method | the receiver is `….type`, whose last segment is `type`, so `type.to_pandas_dtype` (low). The same expression on a named root at :767 gives `type.to_pandas_dtype` | wrong callee | an attribute chain rooted at an index or call result collapses to `.m` instead of the last receiver segment |
| trl/experimental/a2po/a2po_trainer.py:124 | `self.model_kwarg_keys = inspect.signature(model.forward).parameters.keys()` | `A2POTrainer#__init__` → `.keys`, low, method | `parameters.keys`, low | wrong callee | same |
| trl/generation/vllm_client.py:655 | `choices = self._post(f"{self.base_url}/v1/completions", json=payload)["choices"]` | `VLLMClient#get_sequence_logprobs.send` → `self._post`, low, method | `trl.generation.vllm_client.VLLMClient#_post`, high, method (`def _post` at :251; `self` is the enclosing method's `self`, captured by the closure) | wrong callee + wrong confidence | `self.m()` inside a function nested in a method is not resolved to the class |
| trl/generation/vllm_client.py:657 | `self._format_sequence_logprobs(choice, sequence, prompt_length, top_logprobs)` | → `self._format_sequence_logprobs`, low, method | `…VLLMClient#_format_sequence_logprobs`, high (staticmethod at :667) | wrong callee + wrong confidence | same |
| trl/models/utils.py:364 | `self.on_after_inner_forward(wrapper_module, original_module)` | `_ForwardRedirection#__call__.wrapped_forward` → `self.on_after_inner_forward`, low | `trl.models.utils._ForwardRedirection#on_after_inner_forward`, high (:374) | wrong callee + wrong confidence | same |
| trl/trainer/reward_trainer.py:88 | `f = _Filter()` | `_suppress_seqcls_cross_arch_keys` → `_Filter`, low, direct | the class is defined in the scan at :84 (`class _Filter(logging.Filter):`, local to the function), so the callee is a constructor and high. The ID form for a function-local class is not in the spec (see spec gaps) | wrong confidence + wrong call_type | function-local class not indexed as a definition |
| trl/trainer/grpo_trainer.py:2018 | `tool_call_results.append((name, sync_tool_dict[name](**function["arguments"])))` | (no edge for the outer call; `.append` is present) | a real dynamic call (callback, unknown) | missed call | a call whose callee expression is an index or call result emits nothing. The spec defines no callee ID for it (see spec gaps) |
| trl/trainer/grpo_trainer.py:2020 | `async_coros.append((name, async_tool_dict[name](**function["arguments"])))` | (no edge) | as above | missed call | same |
| trl/experimental/a2po/a2po_trainer.py:231 | `inputs = self.processing_class(` | `A2POTrainer#_estimate_optimal_values` → `…A2POTrainer#processing_class`, medium, method | the attribute is set only by the external `transformers.Trainer`. Two readings fit: "`self.m()` inherited from a base outside the scan" (`Type#m`, medium) or "stored property holding a callable" (callback, unknown) | spec gap | the tool cannot tell an external attribute from an external method |
| trl/trainer/grpo_trainer.py:2123 | `image_inputs = super()._prepare_inputs(image_inputs)` | → `._prepare_inputs`, low, method | the direct superclass `_BaseTrainer` is in the scan but does not define `_prepare_inputs`; it is inherited from `transformers.Trainer`. The spec's `.member` rule covers only "`super` when the superclass is not in the scan" | spec gap | — |
| trl/cli/commands/env.py:24 | `super().__init__(name="env", help_text="Print the environment information")` | `EnvCommand#__init__` → `trl.cli.commands.base.Command#__init__`, high, method | The generic rule "Superclass constructor calls (`super(...)`…) → `Parent#<init>`, constructor" would give `Command#<init>`, constructor. Python is not named, and the spec does not say whether a Python `__init__` definition is `Type#<init>` | spec gap | — |

## Systematic patterns (by census count)

1. **Calls through an attribute chain rooted at an index or call result give `.m` instead of the last receiver segment: 15 edges.**
   - All 15 attribute-chain calls with a computed root behave this way, for example `inspect.signature(model.forward).parameters.keys()` → `.keys` (13 edges across 8 trainer files) and `columns[0].offsets.type.to_pandas_dtype()` → `.to_pandas_dtype` (data_utils.py:760, 836).
   - The spec rule `a.b.c()` → `b.c` gives `parameters.keys` and `type.to_pandas_dtype`.
   - Chains rooted at a name are correct (1,012 `b.c` edges).
2. **Dataclass-field callables become `Type#field` medium/method instead of callback/unknown: 14 edges.**
   - `self.processor(` in 4 dataclass collators: 11 edges (dpo_trainer.py ×3, kto_trainer.py ×3, sft_trainer.py ×3, experimental/utils.py ×2).
   - `self.tokenizer(` in `DataCollatorForChatML`: 3 edges.
   - Attributes assigned through `self.x = …` are handled correctly: all 71 `self.<attr>(` edges whose attribute is assigned in the class's own body give callback/unknown. The 2 edges of pattern 4 are assigned only in a scanned superclass.
3. **`self.m()` inside a function nested in a method gives `self.m` low instead of `Type#m` high: 6 edges.**
   - All 6 such calls in scope are affected: vllm_client.py:325, 445, 572, 655 and 657, and models/utils.py:364.
   - By comparison, `self.m()` directly in a method body resolves correctly in all 564 cases where `m` is defined on the class or a scanned ancestor.
4. **An attribute assigned in a scanned superclass and called from a subclass gives `Type#attr` medium/method: 2 edges** (modeling_value_head.py:747 and :994 `self.pretrained_model(`).
5. **A function-local class gives a bare low/direct edge: 1 edge** (reward_trainer.py:88 `_Filter()`).

Total wrong: 15 + 14 + 6 + 2 + 1 = 38 of 16,737, so census precision is ≈99.77%.

Checked and clean across all in-scope edges:
- All callers.
- All line numbers.
- Every high edge points at a real scanned definition, and no medium import edge points at one.
- All 98 nested-function calls are high, with the right `outer.f` IDs.
- All 70 `super().m()` calls whose `m` is defined on a scanned ancestor resolve to that definer (high).
- All 3,001 receivers that are local variables give `recv.m` (low).
- All 2,027 receivers that are imported modules resolve to module-qualified callees (medium, or high when the callee is a scanned definition).
- All 130 calls through a local or parameter are callbacks.
- No lambda-bound locals exist.

## Spec gaps (counted separately, not as wrong)

- **`self.<attr>()` where the attribute comes only from an external base: 26 edges.** The attributes are `processing_class` (17), `data_collator` (5) and `model` (4). The tool emits `Type#attr`, medium, method, which is consistent with "`self.m()` inherited from a base outside the scan". Another 74 edges in this group are real external methods (`add_callback`, `compute_loss_context_manager`, `_get_dataloader`, …) and are correct. Static analysis cannot tell an external attribute from an external method, and the spec does not say which reading wins.
- **`super().m()` where the direct superclass is in the scan but `m` is defined only on an external ancestor: 81 edges**, emitted as `.m`, low. The spec's `.member` rule covers only a superclass outside the scan. The `self.m()` analogue would be `Superclass#m` or `Type#m`, medium. 15 more `super()` edges have a superclass outside the scan and are correctly `.m`.
- **Python constructors.** There are 52 `super().__init__(...)` edges (41 high to `Parent#__init__`, 11 low `.__init__`), all with call_type method. The spec's generic superclass-constructor rule implies `Parent#<init>`, constructor. Separately, the 181 high `C(...)` → `C#<init>` edges never connect to the 2,199 edges whose caller is a `C#__init__` body: no edge has caller `#<init>`. The spec defines `Type#<init>` for Ruby and PHP initializers but says nothing about Python `__init__`.
- **Calls whose callee expression is computed: 15 sites, no edge.** Examples are `d[k](…)`, `f()(…)`, `getattr(o, n)(…)` and `itemgetter(...)(...)`, at sites such as grpo_trainer.py:2018/2020/2377, distillation_trainer.py:1238, sdft_trainer.py:1180, bco_trainer.py:340 and callbacks.py:698. The spec defines callback naming only for a named variable or property.
- **External `Type.m()`** is written with dots: `datasets.Dataset.from_dict`, `transformers.AutoProcessor.from_pretrained`, and `builtins.dict.fromkeys` (2 edges). Constructors of external types, by contrast, get `#<init>`. The spec's `Type#member` form presumes the tool can tell an external type from an external module, and it does not say what to do when it cannot.
- **A function-local class** (`_Filter` in `_suppress_seqcls_cross_arch_keys`) has no ID form in the spec. Its confidence and call_type are wrong either way, so it is counted in pattern 5.

## Previous findings

The previous report (first round, 20-edge sample) had 1 mismatch row, which was a spec gap, and 1 systematic pattern. The tool output has not changed since then: the edge set of `trl.v2.json` is identical to `trl.json`.

- **Mismatch row, a2po_trainer.py:231 `self.processing_class(` → `A2POTrainer#processing_class` (medium, method): still present.** The edge is unchanged. Under the current spec it remains a spec gap, because the stored-property-callable rule and the "inherited from an external base" rule both apply.
- **Pattern "inconsistent handling of `self.<attr>(...)` callables" (17 edges): still present, and wider than measured before.**
  - The 17 `self.processing_class(` → `Type#processing_class` medium edges are unchanged.
  - Counting every attribute that comes only from an external base, the spec-gap group is 26 edges (17 `processing_class`, 5 `data_collator`, 4 `model`).
  - The census also isolated 16 edges in this family that are wrong under the current spec, not gaps: 14 dataclass-field callables (pattern 2) and 2 attributes assigned in a scanned superclass (pattern 4).
  - The examples given in the previous report (gkd_trainer.py:349, 390 and 425) still correctly give callback/unknown.
- **"No other repeated mistakes" and "all callers matched the enclosing def": callers are still all correct (0 of 16,732 wrong), but this statement no longer holds overall.** The full census found 3 further wrong patterns that the 20-edge sample could not surface: computed-root chains (15), `self.m()` in nested functions (6) and the function-local class (1). It also found the `super()` and `__init__` spec gaps (81 and 52 edges) and 15 computed-callee calls with no edge.
- **Import resolution (relative, function-local, re-exported, and the `scripts/generate_tiny_models` package root): still correct across the whole census.** Every high edge resolves to a scanned definition, every external import is medium, and the 5 aliased-import edges resolve to the defining module.
