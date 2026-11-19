# Call-graph accuracy: measuring a static analyzer that AI agents rely on

AI coding agents use call graphs to answer "what does this change touch?". A call graph that looks clean but is wrong is worse than no graph at all: the agent trusts it. This repository is the accuracy program behind the call-graph builder in my structural-analysis service. It holds the specification, the blind-review method, every review report, the scoring script, the acceptance gates and the golden test corpus.

The analyzer itself is closed source. Everything needed to check how its accuracy was measured is here.

## Result

Every one of 80 untouched repositories (four per language, none used during development) scores at least 98% call-edge precision. Two scans of all 80 with the same build are identical.

| Language | Worst repo | Pooled census | Language | Worst repo | Pooled census |
|---|---|---|---|---|---|
| C | 99.20% | 99.68% | Lua | 98.65% | 99.36% |
| C++ | 98.49% | 98.77% | Objective-C | 98.41% | 99.27% |
| C# | 98.75% | 99.10% | OCaml | 98.68% | 99.22% |
| Elixir | 99.96% | 99.99% | PHP | 98.86% | 99.03% |
| Go | 98.72% | 98.99% | Python | 98.75% | 99.37% |
| Groovy | 98.84% | 99.20% | Ruby | 98.19% | 99.06% |
| Haskell | 99.11% | 99.47% | Rust | 98.39% | 99.24% |
| Java | 98.97% | 99.47% | Scala | 98.16% | 98.78% |
| JavaScript | 98.46% | 99.57% | TypeScript | 98.12% | 99.27% |
| Kotlin | 98.93% | 99.58% | Zig | 98.36% | 98.63% |

The target is per repository, so the worst repository is the number that counts. The pooled census is edge-weighted and dominated by large repositories, so it is shown only for context. Full table with every repository, sample sizes and recall: [results/ACCURACY.md](results/ACCURACY.md).

The analyzer embeds these figures in its own responses (`measured_accuracy` per language), together with warnings for any code it could not analyze, so an agent never receives a clean-looking graph with no hint that parts are missing.

## How accuracy is measured

Each repository gets a blind review that follows [method/REVIEW_PROMPT.md](method/REVIEW_PROMPT.md) and the rules in [method/SPEC.md](method/SPEC.md):

1. **Precision sample.** 50 edges, stratified by confidence tier, spread over at least 15 files, drawn with a stated seed. Each edge is checked against the source: is it a real call, with the right caller, callee, confidence, call type and line?
2. **Recall.** Three non-trivial functions in different files. Every call they make is listed by hand and compared with the tool's edges.
3. **Census.** Every wrong pattern found is counted across all in-scope edges by script, and each script is hand-checked. Census precision = 1 − (union of wrong edges) / (in-scope edges).

The reviewers are independent LLM agents. Each sees only the source, the tool output, the spec and the capability matrix: no earlier report and no knowledge of the implementation. Where a reviewer's judgment disagrees with the spec, I rule on it against the spec, and the ruling is recorded in [method/adjudications.md](method/adjudications.md) and applied by the scoring script. The raw figure is always shown next to the ruled one. Ten of the reports used carry a ruling.

## Change control

Accuracy work stopped being an open-ended push once the milestone criteria in [method/MILESTONE.md](method/MILESTONE.md) were met. Every later change to a language builder passes these gates ([harness/gates/README.md](harness/gates/README.md)):

| Gate | Passes when |
|---|---|
| Unit and contract tests | green, each fix written test-first |
| Golden corpus | every case matches, or has a recorded disposition |
| Invariants | no contract violation (a high-confidence callee that is not a node; an empty caller or callee) |
| Baseline diff | every changed edge, compared with the frozen approved baseline, is claimed by a disposition |
| Determinism | two scans give identical edge and node sets for every repository |
| Review | every repository whose output changed is blind re-reviewed, at 98% or above |

The spec carries seven output contracts and dated decisions. A decision is reopened only for a counterexample, a contract violation, an uncovered construct or correctness evidence. A repository's score is never a reason to change the spec.

The golden corpus ([golden/](golden/)) has 339 cases across the 20 languages, written from the spec by authors blind to the implementation: 247 pass, 59 are open defects with a failing case ready as the test for their fix, 2 are accepted limitations, and 31 are questions the spec does not yet decide ([method/GOLDEN_AUTHOR_QUESTIONS.md](method/GOLDEN_AUTHOR_QUESTIONS.md)).

## What went wrong along the way

- **A pooled average hid bad repositories.** Early rounds reported one edge-weighted figure per language. Large clean repositories masked small bad ones, so the target became per repository and the worst repository became the headline.
- **A review queue silently kept stale reports.** One round's queue was built only from repositories with a current scan, and 32 repositories kept reviews made under the previous scope rules. The scoring script now pools the highest-versioned report, and coverage is checked before every pool.
- **Reviewers disagreed with the spec, and once overwrote an existing report.** Reports are versioned, rulings are kept in a file instead of a scratch folder, and the scoring script refuses a ruling whose judged-edge count does not match the report it rules on.

## Limits

- Precision is sampled (50 edges per review) and extended by scripted census; recall is measured on three functions per review, so it is reported, not targeted.
- Reviewers are LLM agents. The spec, the adjudication record and the per-edge mismatch tables in every report are there so their judgments can be checked.
- The 24 development repositories that fixes were tuned on are listed separately in the results and are not part of the accuracy claim.
- The reviewed source repositories and the scan outputs (about 29 GB) are not included. [results/repos.json](results/repos.json) lists every repository and the path reviewed in it.

## Layout

```
method/    SPEC.md, REVIEW_PROMPT.md, MILESTONE.md, adjudications.md, GOLDEN_AUTHOR_QUESTIONS.md
results/   ACCURACY.md/.json, ADJUDICATIONS.json, CAPABILITIES.md, KNOWN_GAPS.json, repos.json
results/reviews/   the latest blind-review report for every repository
harness/   pool.py (scoring), edgediff.py, gates/ (gate, invariants, determinism, freeze, capabilities, dispositions)
golden/    the golden corpus and its dispositions
```

Recompute the accuracy table from the reports (it writes `ACCURACY.md` and `ACCURACY.json` into the folder you give it):

```bash
cp -R results /tmp/callgraph-results && python3 harness/pool.py /tmp/callgraph-results
```

Paths in the reports are shown as `<fanout>`, `<scans>` and `<source-root>` placeholders.

## License

MIT for the scripts and documents in this repository. Quoted source lines in the review reports belong to their projects.
