# s-chaosmonkey (Go) blind call-graph review, round v2

precision 48/50; census ≈100.0% (0 wrong of 204 in-scope); recall: 16 missed of 25 real calls; 0 non-calls

(The 2 sample edges not counted as correct are spec gaps, not errors. The precision sample has 0 wrong edges.)

## Scope
Tool output is `<fanout>/s-chaosmonkey.v2.json`, and the source root is `<source-root>/testing/chaosmonkey`. Every edge is Go, and no edge's `source_file` has a test/, tests/, spec/, examples/ or docs/ segment. That makes all **204 edges in scope**: confidence high 142, medium 54, low 6, unknown 2; call_type direct 160, method 42, callback 2. The edges come from only 9 files: migration/migrations.go 49, grp/grp.go 45, deploy/eligible_instance_groups.go 38, deploy/deployment.go 28, eligible/eligible.go 23, deploy/asg.go 9, chaosmonkey.go 7, cal/cal.go 4, clock/clock.go 1. The tool's own coverage block lists 16 package locations with 42 files as `not_analyzed` (`go_package_load_error`: "dependency github.com/spf13/afero failed to load"). That covers config, schedule, deps, schedstore, mysql, spinnaker, term, command, constrainer, decryptor, env, errorcounter, outage, tracker, cmd/chaosmonkey and mock. None of the 22 `_test.go` files got an edge either. These files are in scope under the path rule because a `_test.go` file name is not a path segment. They do not appear in the coverage block.

Since there are only 204 edges, I judged every one by hand against its source line, on top of the stratified sample. The census is therefore exhaustive, not extrapolated.

## Method
- **Precision sample:** `s-chaosmonkey_r1_sample.py`, seed 20261110. It takes 50 edges stratified high 31 / medium 12 / low 5 / unknown 2 (all unknown edges that exist) and covers all 9 files that have edges (fewer than 15 exist). For each edge I checked whether it is a real call, the caller, the callee, the tier, the call_type and the line. Result: 48 correct, 0 wrong, 2 spec gaps (edges 171 and 173 in sorted order, see Spec gaps).
- **Census:** `s-chaosmonkey_r1_dump.py` prints all 204 edges with their source lines, and I judged each one. `s-chaosmonkey_r1_linecheck.py` compares each line's call-token count with its edge count across all 10 analyzed non-test files (including deploy/app.go, which only calls builtins). Every difference falls into one of two benign classes:
  - interface method declarations and `import (` / `type (` lines, which are not calls;
  - the interface-call expansion, where an interface call plus its VTA low edges gives more edges than tokens: migrations.go:111, 208 and 212.

  No real call in the analyzed files is missing, and no edge is on a non-call or on the wrong line.
- **Recall:** `s-chaosmonkey_r1_recallpick.py`, seed 20261110. Functions of 8+ lines were split into three strata: analyzed non-test files, non-analyzed non-test files, and `_test.go` files. I drew one function from each stratum.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| config/monkey.go:475 | `return -1, errors.Errorf("%d is not in cron range(0-23)", startHour)` | no edge | `…/config.calculateDefaultCronRunHour → github.com/pkg/errors.Errorf`, medium, direct | missed call | package not analyzed (go_package_load_error) |
| spinnaker/terminator_test.go:37 | `payload := killJSONPayload(ins, otherID, "user@example.com")` | no edge | `…/spinnaker.TestKillJSONPayload → …/spinnaker.killJSONPayload`, high | missed call | package not analyzed; `_test.go` files get no edges |
| spinnaker/terminator_test.go:59 | `err := json.Unmarshal(payload, &f)` | no edge | `→ encoding/json.Unmarshal`, medium | missed call | same |
| spinnaker/terminator_test.go:61 | `t.Log(string(payload))` | no edge | `→ testing.T#Log`, medium | missed call | same |
| spinnaker/terminator_test.go:62 | `t.Fatal(err)` | no edge | `→ testing.T#Fatal`, medium | missed call | same |
| spinnaker/terminator_test.go:67, 79, 91, 95, 101, 122, 126, 131, 135 | e.g. `t.Fatalf("payload is not a JSON object: %s", payload)` | no edge (9 calls) | `→ testing.T#Fatalf`, medium | missed call | same |
| spinnaker/terminator_test.go:83, 116 | e.g. `t.Errorf("got ['%s']=%s, want %s", tt.name, got, want)` | no edge (2 calls) | `→ testing.T#Errorf`, medium | missed call | same |
| migration/migrations.go:111 | `panic("asset: Asset(" + name + "): " + err.Error())` | `…/migration.MustAsset → fmt.wrapError#Error`, `fmt.wrapErrors#Error`, `errors.errorString#Error`, low, method | allowed only if the run used include_external, which the JSON does not record | spec gap | VTA low edges to implementations outside the scan |

There are no wrong-caller, wrong-callee, wrong-confidence, not-a-call or wrong-line rows. I hand-checked the conventions the edges rely on:
- Interface calls give `Interface#Method` high/method: `grp.InstanceGroup#App`, `deploy.Deployment#GetClusterNames`.
- The `os.FileInfo` alias is expanded to `io/fs.FileInfo#Mode` medium, and the in-scan VTA implementation `migration.bindataFileInfo#Mode` is low.
- The builtin interface gives `error#Error` medium.
- The named closure `writeString := func…` is `grp.String.writeString`, and calls to it are high.
- The map-lookup function value `f()` is a single edge `f`, unknown/callback.
- Type conversions (`deploy.AccountName(...)`, `os.FileMode(420)`, `string(x)`) and builtins (`append`, `make`, `panic`, `len`) correctly get no edge.
- Multi-line expressions (chaosmonkey.go:196–199, deployment.go:194–195, grp.go:229–233) put each call on its own line.

## Systematic patterns (precision), by scripted count
None. Census: 0 wrong of 204.

## Missed-call patterns (recall)
Recall is complete in the analyzed packages. Calls are missed only where the tool produced no graph at all.

| function | real calls | tool edges | missed |
|---|---|---|---|
| deploy.App#EligibleInstanceGroups (deploy/eligible_instance_groups.go:41) | 9 (`app.Name`, `log.Fatalf`, `appIndep`, `appDep`, `stackIndep`, `stackDep`, `clusterIndep`, `clusterDep`, `fmt.Sprintf`) | 9 | 0 |
| config.calculateDefaultCronRunHour (config/monkey.go:473) | 1 | 0 | 1 |
| spinnaker.TestKillJSONPayload (spinnaker/terminator_test.go:24) | 15 | 0 | 15 |
| **total** | **25** | **9** | **16** |

I also checked grp.String (16 of 16) and eligible.clusters (9 of 9) outside the seeded draw. Neither missed anything, and both are left out of the totals above.

Scale of the gap. These figures come from `s-chaosmonkey_r1_gap.py`, a rough count of `name(` tokens that includes some conversions and interface method declarations, so treat them as approximate:
1. **Packages that fail to load** (`go_package_load_error`, the afero → golang.org/x/text/transform dependency failure): 43 non-test files with about 843 call tokens and no edges. The coverage block reports this one.
2. **`_test.go` files**: 22 files with about 931 call tokens and no edges. This includes test files in packages that were analyzed (cal_test.go, deploy_test.go, grp_test.go, eligible/*_test.go, chaosmonkey_test.go). The coverage block does not mention these files.
3. **Interface calls with no low implementation edges**: for example, `grp.InstanceGroup#App` gets no low edge to `grp.group#App`. This matches the spec ("low edge per concrete implementation that type-flow analysis (VTA) shows can reach it"). The callers that would pass `grp.New` values are in packages that were not analyzed, so I do not count this as a miss.

## Spec gaps
- **3 edges**: migrations.go:111 `err.Error()` → `fmt.wrapError#Error`, `fmt.wrapErrors#Error` and `errors.errorString#Error` (low, method). The Go note allows implementation edges outside the scan "only with include_external". The output JSON does not record whether include_external was on, so I cannot rule on these edges either way. The type flow itself is plausible: `err` comes only from `fmt.Errorf`, which returns those three types. Two of the three are in the sample.
- **Not counted (convention)**: the spec does not define `direct` vs `method` for Go. The tool consistently uses `direct` for statically dispatched calls, including concrete-type methods like `deploy.ASG#Name`, `bytes.Buffer#WriteString` and `gzip.Reader#Close`, and `method` for interface dispatch. I accepted this and did not count it as a gap.

Helper scripts (all in <fanout>):
- s-chaosmonkey_r1_dump.py
- s-chaosmonkey_r1_linecheck.py
- s-chaosmonkey_r1_sample.py
- s-chaosmonkey_r1_recallpick.py
- s-chaosmonkey_r1_gap.py
