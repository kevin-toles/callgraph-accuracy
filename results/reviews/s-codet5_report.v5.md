# s-codet5 call-graph review (round 5, blind)

precision 50/50; census ≈99.38% (17 wrong of 2751 in-scope); recall: 1 missed of 51 real calls; 0 non-calls

(Precision: none of the 50 sampled edges is wrong; 44 are correct and 6 fall under spec gap G1 below, so they are not counted as wrong. Repo-wide, an AST cross-check found 2 missed calls in total; see Missed-call patterns.)

## Scope
Source root `<source-root>/ml/code-understanding/codet5`, tool output `final13-A/s-codet5.v2.json` (`measured_accuracy` ignored). The repo has 32 `.py` files and no test/, tests/, spec/, examples/ or docs/ segments. All 2751 edges are Python and all are in scope, across 29 files (the three `__init__.py` files have no calls). Confidence: medium 1247, low 1134, high 324, unknown 46. call_type: direct 1477, method 1158, constructor 70, callback 46. By pair: medium/direct 1195, low/method 1133, high/direct 281, unknown/callback 46, medium/constructor 39, high/constructor 31, medium/method 13, high/method 12, low/direct 1. Module IDs follow the `__init__.py` rule: `CodeT5/` and `CodeT5+/` have no `__init__.py`, so files there are top-level modules (`run_gen`, `utils`, `data_utils`), and `CodeT5/evaluator/...` is the package `evaluator` (`evaluator.CodeBLEU.parser.DFG`).

## Method
- **Precision sample:** seed 20261113, stratified high 6 / unknown 5 / medium 21 / low 18, over 17 files (script `s-codet5_r5_sample.py`). I opened each edge at its line and checked the call, caller, callee, tier, call_type and line.
- **Recall:** three functions, each listed call by call:
  - `evaluator.CodeBLEU.dataflow_match.get_data_flow` (dataflow_match.py:69–110, 20 calls)
  - `models.CloneModel#get_t5_vec` (models.py:69–81, 10 calls)
  - `utils.load_and_cache_gen_data` (utils.py:14–47, 21 calls)
- **Whole-repo checks**, by script:
  - Every caller ID against AST nesting: 0 mismatches (`s-codet5_r5_callers.py`).
  - Every `ast.Call` against the edges on its line: 2753 calls vs 2751 edges. The only shortfalls are the 2 subscript calls; no line has extra edges (`s-codet5_r5_astcheck.py`).
  - Every bare-name call against local defs, imports and builtins (`s-codet5_r5_names.py`).
  - Every attribute call against the `recv.m` / `.m` / module / `self` forms (`s-codet5_r5_attrs.py`, `s-codet5_r5_attrs2.py`).
  - Census: `s-codet5_r5_census.py`.

## Mismatch table
| file:line | source line | tool said (caller -> callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| CodeT5/evaluator/CodeBLEU/bleu.py:278 | `counts = Counter(ngrams(hypothesis, n)) if len(hypothesis) >= n else Counter()` | evaluator.CodeBLEU.bleu.modified_precision -> CodeT5.evaluator.CodeBLEU.utils.ngrams, medium, direct | evaluator.CodeBLEU.utils.ngrams, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/bleu.py:284 | `Counter(ngrams(reference, n)) if len(reference) >= n else Counter()` | evaluator.CodeBLEU.bleu.modified_precision -> CodeT5.evaluator.CodeBLEU.utils.ngrams, medium, direct | evaluator.CodeBLEU.utils.ngrams, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/bleu.py:576 | `l = sum(1 for _ in ngrams(hypothesis, i + 1))` | evaluator.CodeBLEU.bleu.SmoothingFunction#method6 -> CodeT5.evaluator.CodeBLEU.utils.ngrams, medium, direct | evaluator.CodeBLEU.utils.ngrams, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/calc_code_bleu.py:35 | `ngram_match_score = bleu.corpus_bleu(tokenized_refs, tokenized_hyps)` | evaluator.CodeBLEU.calc_code_bleu.get_codebleu -> CodeT5.evaluator.CodeBLEU.bleu.corpus_bleu, medium, direct | evaluator.CodeBLEU.bleu.corpus_bleu, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/calc_code_bleu.py:47 | `weighted_ngram_match_score = weighted_ngram_match.corpus_bleu(tokenized_refs_with_weights,` | evaluator.CodeBLEU.calc_code_bleu.get_codebleu -> CodeT5.evaluator.CodeBLEU.weighted_ngram_match.corpus_bleu, medium, direct | evaluator.CodeBLEU.weighted_ngram_match.corpus_bleu, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/calc_code_bleu.py:50 | `syntax_match_score = syntax_match.corpus_syntax_match(references, hypothesis, lang)` | evaluator.CodeBLEU.calc_code_bleu.get_codebleu -> CodeT5.evaluator.CodeBLEU.syntax_match.corpus_syntax_match, medium, direct | evaluator.CodeBLEU.syntax_match.corpus_syntax_match, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/calc_code_bleu.py:53 | `dataflow_match_score = dataflow_match.corpus_dataflow_match(references, hypothesis, lang)` | evaluator.CodeBLEU.calc_code_bleu.get_codebleu -> CodeT5.evaluator.CodeBLEU.dataflow_match.corpus_dataflow_match, medium, direct | evaluator.CodeBLEU.dataflow_match.corpus_dataflow_match, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/dataflow_match.py:41 | `candidate = remove_comments_and_docstrings(candidate, 'java')` | evaluator.CodeBLEU.dataflow_match.corpus_dataflow_match -> CodeT5.evaluator.CodeBLEU.parser.remove_comments_and_docstrings, medium, direct | evaluator.CodeBLEU.parser.utils.remove_comments_and_docstrings, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/dataflow_match.py:45 | `reference = remove_comments_and_docstrings(reference, 'java')` | evaluator.CodeBLEU.dataflow_match.corpus_dataflow_match -> CodeT5.evaluator.CodeBLEU.parser.remove_comments_and_docstrings, medium, direct | evaluator.CodeBLEU.parser.utils.remove_comments_and_docstrings, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/dataflow_match.py:73 | `tokens_index = tree_to_token_index(root_node)` | evaluator.CodeBLEU.dataflow_match.get_data_flow -> CodeT5.evaluator.CodeBLEU.parser.tree_to_token_index, medium, direct | evaluator.CodeBLEU.parser.utils.tree_to_token_index, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/dataflow_match.py:75 | `code_tokens = [index_to_code_token(x, code) for x in tokens_index]` | evaluator.CodeBLEU.dataflow_match.get_data_flow -> CodeT5.evaluator.CodeBLEU.parser.index_to_code_token, medium, direct | evaluator.CodeBLEU.parser.utils.index_to_code_token, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/syntax_match.py:37 | `candidate = remove_comments_and_docstrings(candidate, 'java')` | evaluator.CodeBLEU.syntax_match.corpus_syntax_match -> CodeT5.evaluator.CodeBLEU.parser.remove_comments_and_docstrings, medium, direct | evaluator.CodeBLEU.parser.utils.remove_comments_and_docstrings, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/syntax_match.py:41 | `reference = remove_comments_and_docstrings(reference, 'java')` | evaluator.CodeBLEU.syntax_match.corpus_syntax_match -> CodeT5.evaluator.CodeBLEU.parser.remove_comments_and_docstrings, medium, direct | evaluator.CodeBLEU.parser.utils.remove_comments_and_docstrings, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/weighted_ngram_match.py:226 | `counts = Counter(ngrams(hypothesis, n)) if len(hypothesis) >= n else Counter()` | evaluator.CodeBLEU.weighted_ngram_match.modified_recall -> CodeT5.evaluator.CodeBLEU.utils.ngrams, medium, direct | evaluator.CodeBLEU.utils.ngrams, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/weighted_ngram_match.py:234 | `Counter(ngrams(reference, n)) if len(reference) >= n else Counter()` | evaluator.CodeBLEU.weighted_ngram_match.modified_recall -> CodeT5.evaluator.CodeBLEU.utils.ngrams, medium, direct | evaluator.CodeBLEU.utils.ngrams, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/CodeBLEU/weighted_ngram_match.py:544 | `l = sum(1 for _ in ngrams(hypothesis, i + 1))` | evaluator.CodeBLEU.weighted_ngram_match.SmoothingFunction#method6 -> CodeT5.evaluator.CodeBLEU.utils.ngrams, medium, direct | evaluator.CodeBLEU.utils.ngrams, high, direct | wrong callee (and confidence) | `CodeT5.` namespace-package import path kept as the ID instead of the scanned module's ID |
| CodeT5/evaluator/smooth_bleu.py:184 | `sys.stderr.write('Total: ' + str(len(goldMap)) + '\n')` | evaluator.smooth_bleu.computeMaps -> sys.stderr.write, medium, direct | stderr.write, low, method (receiver `sys.stderr` is a module variable of unknown type: last receiver segment, per ID format; typing reaches only scanned declarations, Decisions 2026-11-09) | wrong callee / confidence / call_type | a module attribute (`sys.stderr`) treated as a submodule, inventing a module function `sys.stderr.write` |
| CodeT5/evaluator/CodeBLEU/dataflow_match.py:80 | `DFG, _ = parser[1](root_node, index_to_code, {})` | (no edge) | a call through a value held in a list element (parameter `parser`), emitted at least as a guess (C4) | missed call | call whose callee expression is a subscript is dropped |
| CodeT5/utils.py:227 | `return read_example_dict[task](filename, data_num)` | (no edge) | a call through a dict-held function value, emitted at least as a guess (C4) | missed call | same: subscript callee dropped (outside the recall functions; found by the AST check) |
| CodeT5/run_gen.py etc. (sample #13, #20, #21, #27, #29, #31) | e.g. `for i in range(len(candidates)):` / `minute = int((elapse_time % 3600) // 60)` | builtins.range / builtins.int / builtins.bool / builtins.str / builtins.set, medium, direct | undecided | spec gap (G1) | lowercase builtin class called |

All 16 `CodeT5.` edges come from imports written `from CodeT5.evaluator.CodeBLEU.utils import ngrams` (bleu.py:18, weighted_ngram_match.py:21), `from CodeT5.evaluator.CodeBLEU import weighted_ngram_match, bleu, dataflow_match, syntax_match` (calc_code_bleu.py:8), and `from CodeT5.evaluator.CodeBLEU.parser import (remove_comments_and_docstrings, ...)` (dataflow_match.py:5, syntax_match.py:5). The parser names are re-exported by `parser/__init__.py` from `.utils`. Each import names a scanned file that already has an ID (`evaluator.CodeBLEU.utils.ngrams` and so on, all present in `nodes`). The tool also lists the 8 `CodeT5.evaluator.*` IDs as `nodes`, so each of these definitions has two IDs. That breaks C1 (one definition, one ID) and C2 (a medium callee naming a scanned module's member is invented). It also breaks the Python note that imports, including re-exports through `__init__.py`, resolve to the defining module.

## Systematic patterns (wrong), by count
1. **Namespace-package import path kept as the callee ID: 16 edges** (`CodeT5.evaluator.CodeBLEU.utils.ngrams` 6, `...parser.remove_comments_and_docstrings` 4, one each for `bleu.corpus_bleu`, `weighted_ngram_match.corpus_bleu`, `syntax_match.corpus_syntax_match`, `dataflow_match.corpus_dataflow_match`, `parser.tree_to_token_index`, `parser.index_to_code_token`). Should be the scanned module's ID at high; the re-exported parser names resolve to `evaluator.CodeBLEU.parser.utils.*`. Hand-checked: bleu.py:278, calc_code_bleu.py:35, dataflow_match.py:41/73.
2. **Module attribute treated as a submodule: 1 edge** (`sys.stderr.write`, smooth_bleu.py:184). Hand-checked. No other medium callee has a non-module middle segment: `os.path`, `numpy.random`, `torch.cuda`, `torch.nn.functional`, `xml.sax.saxutils`, `human_eval.data` and `sklearn.metrics` are all modules.

Union: 17 wrong edges. Census precision = 1 − 17/2751 ≈ 99.38%.

Checked and found correct repo-wide (no wrong edges):
- All 2751 caller IDs, including nested functions (`...get_codebleu.make_weights`, `...modified_recall.weighted_sum`, `...corpus_syntax_match.get_all_sub_trees`, `...remove_comments_and_docstrings.replacer`, `...load_tokenize_data.preprocess_function`), `C#<init>`, and lambdas folded into the enclosing function.
- Star import `from _utils import *`: `utils.load_and_cache_multi_gen_data -> _utils.convert_examples_to_features`, high.
- Relative imports in DFG.py: 50 edges to `evaluator.CodeBLEU.parser.utils.tree_to_variable_index`, high.
- `self.m()` edges, high, and inherited `self.register_buffer` as `models.Seq2Seq#register_buffer`, medium.
- `self.encoder(...)` and similar attributes assigned in the class's own `__init__`, plus locals and parameters holding callables: callbacks, unknown. These do not match open defect python/13.
- Capitalized externals:
  - stdlib classes are constructors: `argparse.ArgumentParser#<init>`, `collections.Counter#<init>`, `fractions.Fraction#<init>`, `io.StringIO#<init>`, `builtins.ValueError#<init>`;
  - third-party names and the `multiprocessing.Pool` factory are direct.
- `super().__init__()` gives `torch.nn.Module#<init>`, medium, constructor.
- Bare `modified_precision` in weighted_ngram_match.py:515 is low, direct: it is neither defined nor imported in that file.
- No lambda is bound to a local, so open defect python/03 does not occur.

## Missed-call patterns (recall)
- **Call whose callee is a subscript expression (`x[i](...)`): 2 in the whole repo**, 1 of them inside the recall set (dataflow_match.py:80; also utils.py:227). These are not on CAPABILITIES' unsupported list for Python, so they count as missed calls.
- Recall functions: get_data_flow 19 of 20 (missed line 80); CloneModel#get_t5_vec 10 of 10; load_and_cache_gen_data 21 of 21. No non-calls: function references passed as values (`pool.map(convert_examples_to_features, ...)`, the `dfg_function` dict entries) get no edge, as required.

## Spec gaps (counted separately, not wrong)
- **G1, lowercase builtin or standard-library classes called like functions: 271 edges.**
  - Counts: `builtins.list` 45, `range` 43, `set` 43, `enumerate` 37, `zip` 26, `str` 25, `int` 14, `float` 10, `tuple` 9, `dict` 6, `bool` 3, `bytes` 3, `filter` 2, `type` 1, `itertools.chain` 2, `itertools.cycle` 1, `datetime.timedelta` 1. All are emitted medium, direct.
  - Constructs: `for i in range(len(candidates)):`, `minute = int((elapse_time % 3600) // 60)`, `total_time_str = str(datetime.timedelta(seconds=int(total_time)))`.
  - Open question: the Python decision (2026-10-29, clarified 2026-11-12) says a call of an *external capitalized* name known to be a class (a builtin such as `builtins.ValueError`, or a standard-library class) is a constructor. The per-language note gives only the ID form `builtins.len`. SPEC does not say whether a call of a *lowercase* builtin or standard-library class (`int`, `list`, `range`, `zip`, `itertools.chain`, `datetime.timedelta`) is `direct` to `builtins.int` / `datetime.timedelta`, or `constructor` to `builtins.int#<init>` / `datetime.timedelta#<init>`.
- **G2, `builtins.super` edge beside `Parent#<init>`: 4 edges** (models.py:50, 64, 125, 201).
  - Construct: `super(CloneModel, self).__init__()`. The tool emits both `torch.nn.Module#<init>` (constructor) and `builtins.super` (direct, medium).
  - Open question (CAPABILITIES python/14): does the `super()` call itself get an edge?
- **G3, decorator application: 4 edges** (eval_contrast_retrieval.py:21, 36; eval_match_retrieval.py:21, 57).
  - Construct: `@torch.no_grad()`. The tool emits `<module> -> torch.no_grad`, medium, direct, on the decorator line.
  - Open question (CAPABILITIES python/15): is a decorator call an ordinary call; is its caller the module or the decorated function; and which line does it use?

Gap union: 279 edges. None overlaps the 17 wrong edges.
