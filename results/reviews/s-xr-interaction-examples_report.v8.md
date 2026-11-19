# Blind call-graph review: s-xr-interaction-examples (csharp), round 8

precision 49/50; census ≈99.6% (10 wrong of 2510 in-scope); recall: 0 missed of 31 real calls; 0 non-calls

(Precision 49/50 = 48 correct + 1 spec gap (#17, `string` named `System.String`), 1 wrong (#44).)

## Scope
Tool output `<scans>/final13-A/s-xr-interaction-examples.v2.json`, 2510 edges, all with a `.cs` source_file under `.../xr-interaction-examples/Assets`. No path has a segment named exactly test/tests/spec/examples/docs (`XRI_Examples/` and `Samples/` are not those names), so all **2510 edges are in scope** across 103 files. Confidence: high 957, medium 1146, low 400, unknown 7. call_type: method 1941, implicit 323, constructor 239, callback 7 (no direct/macro edges, which is expected for C#). Every high callee and every caller is listed in `nodes`. The `measured_accuracy` field was ignored.

Method: stratified sample of 50 edges (seed 20261113; medium 20, high 17, low 8, unknown 5; 31 files), recall on 3 functions, scripted census. Helper scripts are in the fanout folder with the prefix `s-xr-interaction-examples_r8_` (`load`, `sample`, `lowdecl`, `lowtyped`, `ids`, `high`, `implicit`, `noimpl`, `medrecv`, `base`, `lines`, `recall`, `census`).

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| InputMediator.cs:132 (sample #44) | `InputSystem.InputSystem.RegisterProcessor<ConsumeFloat>(nameof(ConsumeFloat));` | InputMediator#Initialize → `InputSystem.RegisterProcessor`, low, method | static call on the external type `UnityEngine.InputSystem.InputSystem`: `InputSystem#RegisterProcessor` (named as written), medium, method | wrong callee / wrong confidence | a namespace-qualified type receiver (`Ns.Type.m()`) is treated as a variable of unknown type |
| InputMediator.cs:133, 134, 135 | `InputSystem.InputSystem.RegisterProcessor<ConsumeVector2>(…)` etc. | → `InputSystem.RegisterProcessor`, low | `InputSystem#RegisterProcessor`, medium | wrong callee / wrong confidence | same as above |
| InputMediator.cs:238 | `var actionList = InputSystem.InputSystem.ListEnabledActions();` | → `InputSystem.ListEnabledActions`, low | `InputSystem#ListEnabledActions`, medium | wrong callee / wrong confidence | same as above |
| InputMediator.cs:313 | `var control = InputSystem.InputSystem.FindControl(bindingPath);` | → `InputSystem.FindControl`, low | `InputSystem#FindControl`, medium | wrong callee / wrong confidence | same as above |
| Walkthrough.cs:78 | `m_Steps[currentStep].CancelStep();` (`WalkthroughStep[] m_Steps;`) | Walkthrough#SkipToStep → `.CancelStep`, low, method | `UnityEngine.XR.Content.Walkthrough.WalkthroughStep#CancelStep`, high (Typed call results: an index whose static type comes from a declaration) | wrong callee / wrong confidence | an index into an array of a scanned type is left untyped |
| Walkthrough.cs:81 | `m_Steps[currentStep].StartStep(OnStepComplete, autoProgressIfComplete);` | Walkthrough#SkipToStep → `.StartStep`, low | `…WalkthroughStep#StartStep`, high | wrong callee / wrong confidence | same as above |
| Walkthrough.cs:119 | `m_Steps[currentStep].StartStep(OnStepComplete);` | Walkthrough#Awake → `.StartStep`, low | `…WalkthroughStep#StartStep`, high | wrong callee / wrong confidence | same as above |
| Walkthrough.cs:142 | `m_Steps[currentStep].StartStep(OnStepComplete);` | Walkthrough#OnStepComplete → `.StartStep`, low | `…WalkthroughStep#StartStep`, high | wrong callee / wrong confidence | same as above |
| XRInteractionSimulatorInputFeedbackUI.cs:833 (sample #17) | `if (string.IsNullOrEmpty(handExpressionName))` | → `System.String#IsNullOrEmpty`, medium, method | undecided: `string#…` as written, or `System.String#…` as an expanded alias | spec gap | see Spec gaps, G6 |

The other 48 sampled edges are correct on every field: real call, caller, callee, tier, call_type and line. They cover static calls on external types, members inherited from Unity bases (`T#GetComponent` medium), scanned UnityEvent subclasses (`KeyboardTextEvent#RemoveListener` medium), field-initializer callers (`Type#field`), implicit `<init>`/`<clinit>` edges, `base.X()` to out-of-scan bases as `.X` low, unknown-type chains as low guesses, and `Action` field invocations as callback/unknown.

## Systematic patterns (scripted, `s-xr-interaction-examples_r8_census.py`)
1. **W2: namespace-qualified static call `InputSystem.InputSystem.m()` emitted as a receiver guess: 6 edges.** All are in InputMediator.cs (lines 132–135, 238, 313). The script matches a low `R.m` whose written receiver is `Ns.R` with a capitalized `R` that no declaration in the file names. Each match was checked by hand: the file has `using UnityEngine.InputSystem;` and namespace `UnityEngine.XR.Content.Interaction`, so `InputSystem.InputSystem` is the type. In the same build, `UnityEditor.Unsupported.IsDeveloperMode()` does get a statically named medium edge.
2. **W1: in-place index into an array of a scanned type left `.m` low: 4 edges.** All are in Walkthrough.cs (78, 81, 119, 142). The script matches a low `.m` whose receiver is `x[...]`, where `x` is declared `T[]` and T is a scanned type. Checked by hand: `WalkthroughStep[] m_Steps;` (Walkthrough.cs:17), and `StartStep` / `CancelStep` are defined at WalkthroughStep.cs:116/165.

Union: 10 wrong edges. Census precision = 1 − 10/2510 = 99.60%.

Checks that found no problem:
- Every high method callee is declared in the named type (scripted).
- `base.X()` resolves correctly: 36 edges to out-of-scan bases are `.X` low, and 5 edges to scanned bases are high `Base#X`.
- All 323 implicit edges are correct: the `<init>`/`<clinit>` side matches static or instance, the line is the field's line, and none points at a `const`.
- Every edge's line contains the callee name.
- No medium edge names a scanned type for a method defined in the scan.
- No explicitly typed local, parameter or field is left as a low guess.
- No CAPABILITIES open-defect output occurs. There are no target-typed `new()`, no is-pattern receivers with calls, no where-bounds, no local lambdas, and delegate fields are already callbacks.

## Missed-call patterns (recall)
- Walkthrough#Awake (Walkthrough.cs:91–122): 8 real calls, 8 edges, 0 missed.
- XRKnob#UpdateRotation (XRKnob.cs:247–332): 19 real calls, 19 edges, 0 missed.
- XRKeyboard#UpdateText (XRKeyboard.cs:505–530): 4 real calls, 4 edges, 0 missed.

Total: 0 missed of 31, 0 non-calls. Outside the three functions: the field `s_MinimumUIPackageVersion`, declared twice in `#if UNITY_6000_0_OR_NEWER` / `#else` branches in SpatialKeyboardSampleProjectValidation.cs:32/39 and StarterAssetsSampleProjectValidation.cs, has its constructor edges but no `<clinit>` → field implicit edge (2 field IDs). This is not counted as a miss because the spec does not cover preprocessor branches (see S8).

## Spec gaps (counted separately, not wrong): 47 edges
- **G6: C# keyword types: 21 edges** (`System.String#IsNullOrEmpty` ×13, `#Remove`, `#ToUpper`, `#ToLower`, `#Equals`, `System.Int32#ToString`). Construct: `string.IsNullOrEmpty(x)`, `m_Count.ToString()` with `int m_Count`. Open question: is a predefined-type keyword "named as written" (`string#IsNullOrEmpty`, per the 2026-11-10 C# external-types ruling), or expanded as a type alias to its target (`System.String#IsNullOrEmpty`)?
- **G1: cast-expression receivers: 10 edges.** Constructs: `((KeyboardOptimizer)target).Optimize();`, `var handler = (MaterialPipelineHandler)t; handler.SetPipelineShaders();`, `var sceneAnalytics = target as XrcSceneAnalytics;`, `((BuildTargetGroup[])Enum.GetValues(…)).Distinct().ToArray()`. Open question: does a cast or `as` expression type its receiver (or a `var` bound to it) under decision A / "Typed call results", which list declarations, `= new T(...)`, call results, indexes and literals but not casts?
- **G3: `foreach (var x in arr)` over a declared array: 6 edges** (Walkthrough.cs:97 `step.Initialize()`, PerlerMachineController.cs:31/37, KeyboardOptimizer.cs:188, OnAnimationEvent.cs:34/47 via `currentAction.m_Action.Invoke()`). Open question: decision A lists "for-loop variable" as a typing declaration, but this loop variable is `var` with no written type. Does a non-generic array element type (`WalkthroughStep[]`, `Material[]`, `ActionEvent[]`) type it?
- **G7: extension method (CAPABILITIES csharp/17, undecided): 4 edges.** `m_HeadTransform.GetWorldPose()` gives `Transform#GetWorldPose`, medium (DynamicMoveProvider.cs:139/145/159/165). Open question: is the callee the extending static class's method or the receiver type's `T#m`?
- **G2: `out var` bound by a scanned method's out-parameter: 3 edges.** `if (TryFindSample(…, out var sample)) sample.Import(…)` with `static bool TryFindSample(…, out Sample sample)` gives `sample.Import`, low. Open question: does an `out var` take the declared type of the scanned method's out-parameter, as a local bound to a call result takes its declared return type?
- **G5: `var` bound to a typed variable or property with no call: 2 edges.** `var updatedText = text; updatedText.Insert(…)`, where `text` is the `string` property XRKeyboard#text or a `string` parameter. Open question: the let-bound ruling covers locals bound to call results. Does it cover a local bound to a plain variable or property read?
- **G4: `var` bound to an index of a declared array: 1 edge.** `var key = m_Keys[i]; key.SetButtonInteractable(…)` with `XRKeyboardKey [] m_Keys;` (XRKeyboardLayout.cs:107). Open question: "Typed call results" types an index in place. Does a `var` bound to that index inherit the type, as the let-bound ruling gives for call results?
- **S8: preprocessor-duplicated field (recall side, 2 field IDs).** `#if … static readonly PackageVersion s_MinimumUIPackageVersion = new PackageVersion("2.0.0"); #else … = new PackageVersion("3.0.8"); #endif`. Open question: SPEC does not say whether both conditional branches are analyzed, or whether their implicit `<clinit>` edge is required.
