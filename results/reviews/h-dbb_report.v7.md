# h-dbb (groovy) blind call-graph review, v7

precision 48/50; census ≈99.2% (24 wrong of 2966 in-scope); recall: 0 missed of 24 real calls; 0 non-calls

(The 48 includes 4 spec-gap edges, which are not counted as wrong. 44 sample edges are plainly correct, 2 are wrong.)

## Scope
The tool JSON has 2995 edges: 2969 from `.groovy` files and 26 from `.java` files (DTLScanner). The Java edges are out of scope because Java is not the main language. 3 Groovy edges are under `Scanners/DTLScanner/src/test/` and are excluded. **That leaves 2966 in-scope edges** from 25 Groovy files.
- Confidence: low 1475, medium 1260, high 223, unknown 8.
- call_type: method 2521, constructor 336, direct 65, implicit 36, callback 8.

No Groovy file declares a `package`, so the bare IDs (`PackageBuildOutputs#run`, `ConcertBuildManifest#<init>`) are the correct form. Nearly every Groovy file has two or more on-demand imports (`groovy.transform.*`, `groovy.cli.commons.*`, `java.net.http.*` and others). Under SPEC, a simple type name reachable only through those imports is correctly unqualified and low (`CliBuilder#parse`, `HttpRequest#newBuilder`, `Bom#<init>`). The tool does this consistently: a script found 0 low `T#m` edges whose type was singly imported or came from a file with exactly one on-demand import.

## Method
- **Precision sample.** Seed 20261109. Stratified as 22 low, 18 medium, 5 high and 5 unknown, with at most 4 edges per file (the cap was not applied to the unknown tier, which has only 8 edges). The 50 edges come from 18 files. Each one was read at its source line.
- **Recall.** I hand-listed every call in three functions:
  - `tools#writeReport` in Utilities/ReadSMFRecords/tools.groovy, lines 180–204
  - `sbomGenerator#getGitHash` in Pipeline/PackageBuildOutputs/utilities/sbomGenerator.groovy, lines 208–223
  - `ArtifactRepositoryHelpers#computeArchiveUrl` in Pipeline/PackageBuildOutputs/ArtifactRepositoryHelpers.groovy, lines 166–170
- **Census.** The patterns are counted by `h-dbb_r6_census.py`. Supporting scripts: `h-dbb_r6_scope.py` (brace-scoped caller check), `h-dbb_r6_typed2.py` (typed receivers left as guesses), `h-dbb_r6_nocall.py` (callee name not called on its line), `h-dbb_r6_imports.py` and `h-dbb_r6_medq.py` (import and qualification checks), and `h-dbb_r6_fields.py` (`@Field` initializers). Every pattern was checked by hand at each of its sites.

## Mismatch table (sample and census)
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| Utilities/ReadSMFRecords/tools.groovy:151 (sample #18) | `return "0x"+newBytes.encodeHex().toString().toUpperCase()` (`byte[] newBytes = new byte[length];`) | tools#bytesToHex → byte#encodeHex, low, method | typed receiver (decision A), external → medium | wrong confidence | primitive-array declared type not treated as a typed receiver |
| Pipeline/CreateUCDComponentVersion/dbb-ucd-packaging.groovy:189 (sample #46) | `zFSFilesCount++` | dbb-ucd-packaging#run → zFSFilesCount, unknown, callback | no edge (increment of a local int) | not a call | postfix increment read as a call through a variable |
| Pipeline/PackageBuildOutputs/utilities/sbomGenerator.groovy:125 | `if (record.getType()=="USS_RECORD") {` (`Record` from `import com.ibm.dbb.build.report.records.*`) | sbomGenerator#addEntryToSBOM → java.lang.Record#getType, medium | `Record#getType`, low (several on-demand imports; Groovy resolves star imports before default imports, so this is the DBB Record, not java.lang.Record) | wrong callee | default-import `java.lang.Record` beats an explicit star import |
| Pipeline/PackageBuildOutputs/utilities/WaziDeployManifestGenerator.groovy:187 | `deleted_artifact.description = (record.getAttribute("file")) ? record.getAttribute("file") : ...` | …#appendArtifactDeletionToManifest → java.lang.Record#getAttribute, medium (×2) | `Record#getAttribute`, low | wrong callee | same |
| Pipeline/PackageBuildOutputs/ArtifactRepositoryHelpers.groovy:70 | `HttpClient httpClient = httpClientBuilder.build();` (`HttpClient.Builder httpClientBuilder`, `java.net.http.*` plus 2 other on-demand imports) | ArtifactRepositoryHelpers#upload → HttpClient.Builder#build, medium | `HttpClient.Builder#build`, low | wrong confidence | nested type reached through several on-demand imports given medium (its outer type `HttpClient#newBuilder` is correctly low) |
| Pipeline/DeployUCDComponentVersion/ucd-deploy.groovy:86 | `httpClientBuilder.sslContext(sc)` | ucd-deploy#requestDeployment → HttpClient.Builder#sslContext, medium | low | wrong confidence | same |
| Pipeline/CreateUCDComponentVersion/dbb-ucd-packaging.groovy:713 | `def elements =  fullname.split("[\\(\\)]");` inside `def getDatasetAndMember(String fullname) {` | dbb-ucd-packaging#run → fullname.split, low | dbb-ucd-packaging#getDatasetAndMember → java.lang.String#split, medium | wrong caller (+ wrong callee) | function body whose first statement is `def ds,member;` attributed to the script body; the typed parameter is lost too |
| Pipeline/PackageBuildOutputs/PackageBuildOutputs.groovy:945 | `member = elements.size()>1? elements[1] : "";` inside `def getDatasetName(String fullname){` | PackageBuildOutputs#run → elements.size, low | caller PackageBuildOutputs#getDatasetName | wrong caller | same |
| Migration/jclToZBuilder/groovy/JCLtoYAML.groovy:533 | `newDD.DSNs.add(generateDSN(concat, configuration))` (`DD newDD`; `ArrayList<DSN> DSNs`) | JCLtoYAML#run → newDD.DSNs#add, medium | java.util.ArrayList#add, medium | wrong callee | capitalized field name taken as a type name |
| Migration/jclToZBuilder/groovy/JCLtoYAML.groovy:535 | `configstep.DDs.add(newDD)` | JCLtoYAML#run → configstep.DDs#add, medium | java.util.ArrayList#add, medium | wrong callee | same |
| Migration/jclToZBuilder/groovy/JCLtoYAML.groovy:456 | `return writeBlockStringYaml(new StringReader(JsonOutput.DEFAULT_GENERATOR.toJson(getContent())))` | JCLtoYAML#run → groovy.json.JsonOutput.DEFAULT_GENERATOR#toJson, medium | groovy.json.JsonGenerator#toJson (static field's declared type), medium | wrong callee | static field taken as a nested type |
| Migration/jclToZBuilder/groovy/JCLtoYAML.groovy:456 | same line, inside `def YAMLoutput = new YamlBuilder() { … }` | JCLtoYAML#run → JCLtoYAML#getContent, medium | groovy.yaml.YamlBuilder#getContent, medium (inherited by the anonymous subclass) | wrong callee | bare call in an anonymous-subclass body resolved against the enclosing script |
| Pipeline/DeployUCDComponentVersion/ucd-deploy.groovy:241 | `TrustManager[] trustAllCerts = new TrustManager[] { new X509TrustManager() {` | ucd-deploy#trustAllCertsTrustManager → javax.net.ssl.X509TrustManager#<init>, medium, constructor | no edge (anonymous implementation of an interface) | not a call | interface vs class not distinguished for `new I() {…}` |
| Pipeline/DeployUCDComponentVersion/ucd-deploy.groovy:22 | `@Field DEFAULT_SSL_PROTOCOLS = "TLSv1.2"` | ucd-deploy#<init> → ucd-deploy#timeout, high, implicit | ucd-deploy#<init> → ucd-deploy#DEFAULT_SSL_PROTOCOLS (line 22) | wrong callee | untyped `@Field x = …` merged with the next line's `@Field int timeout = 60000` |
| Pipeline/PackageBuildOutputs/utilities/WaziDeployManifestGenerator.groovy:264 (sample #50; also #47 :272, #49 applicationDescriptorUtils:95) | `yamlBuilder {` (`def yamlBuilder = new YamlBuilder()`) | …#writeApplicationManifest → yamlBuilder, unknown, callback | this is `yamlBuilder.call(Closure)` on a receiver typed by `= new YamlBuilder()`; SPEC only defines callbacks for variables that hold functions | spec gap | implicit `call()` on a typed object |
| Migration/jclToZBuilder/groovy/JCLtoYAML.groovy:543 (sample #48) | `YAMLoutput(yaml)` (`def YAMLoutput = new YamlBuilder() {…}`) | JCLtoYAML#run → YAMLoutput, unknown, callback | same question | spec gap | same |

## Systematic patterns (scripted counts; union = 24 wrong edges)
1. **Nested type reached through several on-demand imports given medium (should be low): 6.** These are `HttpClient.Builder#build` ×3, `HttpClient.Builder#sslContext`, `HttpRequest.Builder#version` and `HttpRequest.Builder#build`, in ArtifactRepositoryHelpers and ucd-deploy. Simple names from the same imports are correctly low.
2. **`java.lang.Record` chosen over a star-imported `Record`: 5.** These are in sbomGenerator (3) and WaziDeployManifestGenerator (2). Both files import `com.ibm.dbb.build.report.records.*`, and java.lang.Record has no `getAttribute`, `getType` or `getFile`.
3. **Function body attributed to `Script#run`: 4.** Only the bodies of `getDatasetAndMember` (dbb-ucd-packaging) and `getDatasetName` (PackageBuildOutputs) are affected. Both are short functions that start with `def ds,member;`. The functions themselves are recognized: calls to them are high. The brace-scoped caller check found no other caller errors.
4. **Capitalized field or static field used as a type in the callee ID: 3.** These are `newDD.DSNs#add`, `configstep.DDs#add` and `groovy.json.JsonOutput.DEFAULT_GENERATOR#toJson`.
5. **Primitive-array typed receiver left low: 2.** Both are `byte#encodeHex` in tools.groovy, at lines 138 and 151.
6. **Increment emitted as a callback: 1.** This is `zFSFilesCount++`. The same variable's `+=` and the other `x++` sites (`bomRef++`, `stepCount++`) produce no edge.
7. **Untyped `@Field` implicit edge names the wrong field: 1.** This is ucd-deploy:22.
8. **Constructor edge for an anonymous interface implementation: 1.** This is `X509TrustManager`. The 3 anonymous `Authenticator` edges, an abstract class, are correct.
9. **Bare call inside an anonymous-subclass body resolved to the script: 1.** This is `getContent()` at JCLtoYAML:456.

## Missed-call patterns (recall)
- **Recall functions: 0 missed of 24 real calls, 0 non-calls.**
  - writeReport: 14 of 14.
  - getGitHash: 3 of 3.
  - computeArchiveUrl: 7 of 7, including the `props.get` inside a GString `${}`.
- **Implicit `<init>` → field edges missing for untyped `@Field name = value`: 3.** These are:
  - `@Field int timeout = 60000` at ucd-deploy:23 (its edge was mislabeled onto line 22, see pattern 7)
  - `@Field validStatusCodes = [200, 201]` at ArtifactRepositoryHelpers:33
  - `@Field bomRef = 0` at sbomGenerator:30

  Typed `@Field` initializers all have their implicit edge (21 of 21), and the calls inside them have caller `Script#field`.

## Spec gaps (not counted as wrong)
- **Implicit `call()` on a typed object: 7 edges.** These are 6 × `yamlBuilder {…}` / `yamlBuilder externalDependencies`, plus 1 × `YAMLoutput(yaml)`. The tool emits a callback to the variable name, unknown. SPEC covers variables holding functions, not objects whose `call` method Groovy invokes. The alternative reading is `groovy.yaml.YamlBuilder#call`, medium.
- **Bare call to an undefined name in a plain class: 2 edges.** These are `throw IllegalStateException(...)`, written without `new`, at JCLtoYAML:105 and :136. The tool says `DD#IllegalStateException` / `Step#IllegalStateException`, medium. SPEC does not settle whether the implicit `Object` base counts as "a base outside the scan" (medium) or the name is "not found in the scan" (low). At runtime this is a MissingMethodException.
- **Groovy enum constants: 4 constants, 0 edges.** These are in `enum Status { PENDING, EXECUTING, SUCCEEDED, FAULTED }` at ucd-deploy:18. SPEC's `Enum#<clinit>` → `Enum#<init>` rule is written for Java enums only.
- **ID shape for array types: 2 edges.** These overlap pattern 5. SPEC does not say whether a `byte[]` receiver is written `byte#m` or `byte[]#m`. Only the confidence is counted as wrong.
