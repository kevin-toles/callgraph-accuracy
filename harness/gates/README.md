# Call-graph acceptance gates

Every change to a call-graph builder passes these before it is accepted (SPEC.md, Change control).

| Gate | Command | Passes when |
|---|---|---|
| L1 unit/contract tests | `go test ./internal/language/<lang>/...` | green |
| L2 golden corpus | `go test ./internal/wire -run TestGoldenCorpus` | every non-spec-gap case matches, or the case has a recorded disposition in testdata/golden/DISPOSITIONS.md |
| L3 invariants | `python3 gates/invariants.py <scan>.v2.json...` | no contract C1/C7 violation (high callee undefined, empty caller/callee) |
| L4 baseline diff | `python3 gates/gate.py baselines-approved-<date> <scan dir> gates/dispositions-<change>.json` | every changed edge is claimed by a disposition entry |
| L5 determinism | `python3 gates/determinism.py <scan dir A> <scan dir B>` | identical edge and node multisets for every repo |
| Review | blind re-review (REVIEW_PROMPT.md) of every repo whose L4 diff is non-empty | census ≥ 98% |

After a change is accepted and its repos re-reviewed, the new scans are frozen as the next approved baseline (`gates/freeze.py baselines-approved-<date> <commit>`).
Approved baselines: `baselines-approved-2026-11-10` (tool 0da1d8a, the 80 scans behind measured_accuracy.json of 2026-11-10).
