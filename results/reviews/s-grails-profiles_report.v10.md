# s-grails-profiles (groovy) blind call-graph review, round v10

precision 50/50; census ≈99.0% (8 wrong of 801 in-scope); recall: 0 missed of 68 real calls; 0 non-calls

## Scope
Tool output: `s-grails-profiles.v2.json`, 1014 edges in total (801 `.groovy`, 213 `.js`). I judged only `.groovy` edges, excluding any path with a segment named test/tests/spec/examples/docs. No in-scope path has such a segment (`templates/testing/` is not `test`). Templates, skeletons and profile command scripts are all in scope (Decisions 2026-11-09). That leaves **801 in-scope edges in 51 files**.
- Confidence: medium 381, low 347, high 65, unknown 8.
- call_type: method 572, direct 148, implicit 40, constructor 33, callback 8.

Sample: seed `20261109`. Quotas: high 5, unknown 5, medium 21, low 19. That is roughly proportional, with at least 5 per tier, and covers 25 files. Helper scripts are in the fanout folder: `s-grails-profiles_r9_load.py`, `_r9_sample.py`, `_r9_show.py`, `_r9_census.py`, `_r9_recall.py`.

## Precision sample
All 50 sampled edges are correct per the spec, apart from the spec gaps listed below.
- **Script bare calls:** in command scripts, top-level bare calls (`flag(..)`, `file(..)`, `error ..`, `render ..`) resolve as `Script#m` medium, which is inherited from an out-of-scan base.
- **Closures:** bare calls inside DSL closures (`usage`, `flag name:..`, `argument`, `include`) are honest low.
- **Typed receivers:** `= new T()`, typed fields and typed parameters resolve to `T#m` (for example `java.io.PrintWriter#println` and `io.micronaut.http.HttpResponse#body`).
- **Implicit edges:** field-initializer `<init>`/`<clinit>` implicit edges are correct.
- **Body-less interface members:** calls to the scaffolding `${className}Service` interface's body-less members are high.

Six sampled edges are spec gaps rather than errors:
- #5 `plugin-info.groovy:32` `.parseText`
- #36–39 and #50: GString-named UrlMappings calls

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| base/commands/stats.groovy:54 | `loc = match.locmatcher ? match.locmatcher(file) : DEFAULT_LOC_MATCHER(file)` | stats#run → `.DEFAULT_LOC_MATCHER`, high, direct | `stats#run.DEFAULT_LOC_MATCHER`, high, direct | wrong callee | call to a `def f = { }` local closure loses its outer prefix (the definition itself is named `stats#run.DEFAULT_LOC_MATCHER`) |
| base/commands/test-app.groovy:46 | `gradleArgs.addAll handleTestPhase('test')` | test-app#run → `.handleTestPhase`, high, direct | `test-app#run.handleTestPhase`, high, direct | wrong callee | same |
| base/commands/test-app.groovy:52 | `gradleArgs.addAll handleTestPhase('integrationTest')` | test-app#run → `.handleTestPhase`, high, direct | `test-app#run.handleTestPhase`, high, direct | wrong callee | same |
| base/commands/test-app.groovy:81 | `runTests(gradleArgs)` | test-app#run → `test-app#runTests`, medium, method | `runTests`, unknown, callback | wrong callee | `runTests = { List args -> … }` (line 55) is a script binding variable that holds a closure. It is not an inherited method |
| base/commands/test-app.groovy:85 | `runTests(gradleArgs)` | test-app#run → `test-app#runTests`, medium, method | `runTests`, unknown, callback | wrong callee | same |
| base/commands/test-app.groovy:94 | `runTests(gradleArgs)` | test-app#run → `test-app#runTests`, medium, method | `runTests`, unknown, callback | wrong callee | same |
| rest-api/templates/artifacts/RestfulController.groovy:9 | `super(@artifact.name@)` | Artifact_name__Controller#<init> → `RestfulController#<init>`, medium, constructor | `RestfulController#<init>`, low | wrong confidence | the type is reachable only through two wildcard imports (`grails.rest.*`, `grails.converters.*`), so it must stay low. `plugin/.../Application.groovy:10` `GrailsApp#run` gets this right (low) |
| rest-api/templates/artifacts/RestfulController.groovy:8 | `@artifact.name@Controller() {` | Artifact_name__Controller#<init> → `Artifact_name__Controller#artifact_name__Controller`, medium, method | no edge (constructor declaration) | not a call | constructor head with a template placeholder name is parsed as a call |

## Systematic patterns (scripted, `s-grails-profiles_r9_census.py`)
| # | pattern | count |
|---|---|---|
| P1 | call to a `def f = { … }` local closure emitted as `.f` instead of `Script#run.f` | 3 |
| P2 | call to a closure held in a script binding variable (`x = { … }`) emitted as `Script#x` medium method (should be `x` callback unknown) | 3 |
| P3 | unqualified type reachable only through more than one wildcard import given medium (should be low) | 1 |
| P4 | constructor declaration head (template placeholder name) emitted as a call | 1 |

Union of wrong edges: 8 of 801, so census precision is 1 − 8/801 = **99.00%**. I hand-checked every counted edge, and each pattern's script matches exactly the edges listed above.

I also ran these checks and they found nothing: high callees that are not defined in the scan (0), and low bare calls to methods defined in the same file (0).

## Recall
| function | file | real calls | tool edges | missed | non-calls |
|---|---|---|---|---|---|
| `run-app#createSSLCertificate` (155–185) | base/commands/run-app.groovy | 6 | 6 | 0 | 0 |
| `ClassName___FunctionalSpec#Test the save action correctly persists an instance` (55–83) | rest-api/templates/artifacts/scaffolding/FunctionalSpec.groovy | 18 | 18 | 0 | 0 |
| `plugin-info#run` (whole script, 1–71) | base/commands/plugin-info.groovy | 44 | 44 | 0 | 0 |

Total: 0 missed of 68 real calls, 0 non-calls. Property reads (`.text`, `.absolutePath`, `e.response.status`) were correctly not emitted. GString text escaped with `\${…}` in the profile templates was correctly not treated as calls.

## Missed-call patterns (recall, found by looking)
- **Dynamic GString-named method call on a receiver, no edge:** 2 instances.
  - `base/commands/test-app.groovy:62` `gradle."${args.join(' ')}"(*additionalArguments)`
  - `base/commands/dependency-report.groovy:16` `gradle."${command.join(' ')}"(*arguments)`

  The inner `join` call is emitted in both. In the UrlMappings DSL the tool does emit such calls, as unknown callbacks, so behaviour is inconsistent. This is also a spec gap: the spec does not say how to name an interpolated method name.

## Spec gaps (counted separately, not wrong)
| # | gap | count |
|---|---|---|
| G1 | **Method name built at runtime by GString interpolation, called on the closure delegate.** Example: `delete "/$controller/$id(.$format)?"(action:"delete")` in UrlMappings is emitted with the GString literal as callee, unknown/callback. The spec has no ID rule for an interpolated method name. The closure-delegate rule would suggest low, but the callback/unknown rule covers only variables that hold functions. | 8 |
| G2 | **Call on an inline `new T(...)` receiver left as `.m` low.** Example: `new XmlSlurper().parseText(..)`. Decision A types bindings (`= new T(...)`). The spec does not say whether a bare `new T()` expression is a typed receiver or a computed receiver. | 5 |
| G3 | **Template placeholders in package/class names** (`@grails.codegen.defaultPackage@`, `@artifact.name@`, `${className}`) are sanitized into IDs such as `grails_codegen_defaultPackage__.UrlMappings`, `Artifact_name__Controller` and `ClassName___Service`. The spec does not cover non-Groovy template tokens. I judged these edges on their substance under the tool's substitution. The resulting IDs are also inconsistent across files: `${className}` becomes `ClassName___` as a type, `className___.count` as a receiver, and `spock.lang.ClassName___#<init>` through the one wildcard import. | 233 edges carry placeholder IDs |
