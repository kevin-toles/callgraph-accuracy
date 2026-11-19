# Golden call-graph corpus

This corpus is the acceptance oracle for the call-graph builders. Each case's expected output was written from `SPEC.md` alone (`<fanout>/SPEC.md`), by authors who never saw the builders' source, tests or output. The implementation does not get a vote.

## Layout

```
testdata/golden/<language>/<NN-slug>/
  src/            the scan root: every source file of the case
  expected.json   the complete expected output for src/
```

`<language>` is one of: c, cpp, csharp, elixir, go, groovy, haskell, java, javascript, kotlin, lua, objc, ocaml, php, python, ruby, rust, scala, typescript, zig.

## expected.json

```json
{
  "rule": "the SPEC sentence(s) this case tests, quoted exactly",
  "source": "SPEC" | "KNOWN_GAP: <the gap text>" | "ADVERSARIAL: <what it probes>",
  "edges": [
    {"caller": "pkg.mod.f", "callee": "pkg.mod.g", "call_type": "direct",
     "confidence": "high", "file": "pkg/mod.py", "line": 4}
  ],
  "nodes_include": ["pkg.mod.g"],
  "notes": "the reasoning for any expectation that is not obvious from the rule"
}
```

- `edges` is **complete**: it lists every edge the spec requires for the files under `src/`, and nothing else. That includes calls of builtins and the standard library. The harness compares the multiset of `(caller, callee, call_type, confidence, file, line)` exactly. `file` is relative to `src/`. `is_async`, `is_external` and `arguments_count` are not compared.
- `nodes_include` (optional) lists IDs that contract C1 requires in the output's `nodes`.
- A case whose expectation the spec does not decide has `"spec_gap": "<the question>"` and no `edges`. The harness skips it and lists it as a spec ambiguity.

## Running it

```
go test ./internal/wire -run TestGoldenCorpus -v
```

Every case runs through the same language-dispatching builder the service uses, with `include_external` on. The test prints one line per case and a summary. Each failing case shows its missing and unexpected edges.

## Changing a case

An expectation changes only under SPEC.md's change-control rule: a dated ruling, or a recorded disposition showing the case contradicts SPEC (an authoring error). The disposition is logged in `testdata/golden/DISPOSITIONS.md`. Never edit `expected.json` to match the tool's output without a disposition.
