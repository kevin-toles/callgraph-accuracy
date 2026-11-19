# Blind call-graph review: instructions

You are reviewing a static call-graph tool's output for ONE repository against its real source code. This is a blind review: there is no previous report for this repo and you must not assume the tool is right.

Inputs (given in your task message): repo name, language, source root, tool output JSON (`<fanout>/<name>.v2.json`, edges at `.call_graph.edges`).

The spec is `<fanout>/SPEC.md`. Read it first and follow it exactly, including its Contracts, every Decisions section, and its Method and Report format sections. Judge every edge against the spec and the source; where the spec does not decide a case, call it a spec gap and count it separately, never as wrong.

Also read `<fanout>/CAPABILITIES.md` for your language: calls in constructs it lists as **unsupported** are recall gaps, not wrong edges; output matching an **open defect** is wrong (count it like any other wrong pattern). Do not use it to decide what is correct: SPEC does that.

## Scope
- Only judge edges whose `source_file` is in the repo's main language (the language you are given) and not under a path segment named test/, tests/, spec/, examples/ or docs/. Vendored, third-party, generated and fixture code is IN scope (SPEC.md, Decisions 2026-11-09). Repos may contain other languages: ignore those edges.
- State the in-scope edge count and its confidence / call_type split.

## Method (all three are required)
1. **Precision sample:** 50 edges, stratified by confidence (roughly proportional, at least 5 per tier that exists), spread over at least 15 files (or all files if fewer), random with a stated seed. For each: real call? caller? callee? confidence tier? call_type? line?
2. **Recall:** 3 non-trivial functions (8+ lines, different files). List every call each makes and compare with the tool's edges whose caller is that function. Report missed calls and non-calls.
3. **Census:** for every wrong pattern you find (in the sample, recall, or by looking), count by script how many in-scope edges share it. `census precision = 1 − (union of wrong edges) / in-scope edges`. Validate each scripted pattern with a few hand checks. Missed calls are reported separately (they are recall, not precision).

## Rules
- Read-only on the repo (never modify it). Never print the whole JSON; load it with python3 and sample.
- Do not run the tool or any service. Never import or execute the repo's own code or load ML models; read source as text only.
- Keep helper scripts in the fanout folder with a `<name>_r1_` prefix.

## Report
Write `<fanout>/<name>_report.md` and return the same content as your final message:
- Title line, then the Summary line exactly: `precision X/50; census ≈P% (W wrong of E in-scope); recall: N missed of M real calls; K non-calls`
- Scope paragraph.
- Mismatch table: file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause.
- Systematic patterns, each with its scripted count, ordered by count.
- Missed-call patterns (recall) with counts.
- Spec gaps with counts. For each spec gap, quote the construct and state the question SPEC leaves open; do not propose an answer.

