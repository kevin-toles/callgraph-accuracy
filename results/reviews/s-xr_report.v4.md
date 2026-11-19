# s-xr-interaction-examples (C#) call-graph review, round 4 (blind)

precision 49/50; census ≈98.96% (27 wrong of 2588 in-scope); recall: 0 missed of 29 real calls; 0 non-calls

## Scope
The tool output has 2588 edges, all from `.cs` files. None sit under test/, tests/, spec/, examples/, docs/, vendor/, third_party/ or generated paths below the scan root (`Assets/Samples/...` and `Assets/XRI_Examples/...` are not excluded directories), so all **2588 edges in 103 files are in scope**.
- Confidence: high 1031, medium 1144, low 406, unknown 7.
- call_type: method 1941, implicit 401, constructor 239, callback 7.

Sample: seed 20261029, stratified medium 20 / high 18 / low 7 / unknown 5, spread over 30 files. Of the 50, 49 are correct per spec. 25 of the correct ones fall in spec-gap classes: 18 G1, 5 G2, 2 G4. Line numbers were right for every sampled edge. A script checked all 2588 edges: every non-implicit edge's callee name appears on its line, except one correct `: base(...)` constructor edge, and every implicit edge's field name appears on its line.

Recall functions:
- `Walkthrough#Awake` (Walkthrough.cs:91–122): 8 calls, 8 edges.
- `XRKnob#UpdateRotation` (XRKnob.cs:247–332): 18 calls, 18 edges.
- `XRKeyboardDisplay#SetKeyboard` (XRKeyboardDisplay.cs:257–272): 3 calls, 3 edges.

All callers, callees, tiers and lines match. There are no missed calls and no non-calls. Calls inside lambdas fold correctly into the enclosing method, for example `XrcAnalyticsUtils#Register` → `XrcAnalyticsUtils#Send`.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| LocomotionSetup.cs:188 (sample #8) | `m_SnapTurnKnob.onValueChange.AddListener(SetSnapTurnAmount);` | `LocomotionSetup#ConnectControlEvents` → `ValueChangeEvent#AddListener`, medium, method | `UnityEngine.XR.Content.Interaction.XRKnob.ValueChangeEvent#AddListener`, medium | wrong callee | in-scan nested type name defined 4 times left as a bare simple name |
| XRKnob.cs:121 | `ValueChangeEvent m_OnValueChange = new ValueChangeEvent();` | `XRKnob#m_OnValueChange` → `ValueChangeEvent#&lt;init&gt;`, medium, constructor | `UnityEngine.XR.Content.Interaction.XRKnob.ValueChangeEvent#&lt;init&gt;` | wrong callee | same: ambiguous nested-type simple name not qualified |
| InputMediator.cs:132 | `InputSystem.InputSystem.RegisterProcessor&lt;ConsumeFloat&gt;(nameof(ConsumeFloat));` | `InputMediator#Initialize` → `InputSystem.RegisterProcessor`, low, method | `UnityEngine.InputSystem.InputSystem#RegisterProcessor`, medium | wrong callee / wrong confidence | namespace-qualified type read as an unknown-type receiver |
| ClimbTeleportDestinationIndicator.cs:64 | `if (!ComponentLocatorUtility&lt;ClimbTeleportInteractor&gt;.TryFindComponent(out m_ClimbTeleportInteractor))` | `ClimbTeleportDestinationIndicator#OnEnable` → `.TryFindComponent`, low, method | `ComponentLocatorUtility#TryFindComponent`, medium | wrong callee / wrong confidence | static call on a generic type `Name&lt;T&gt;.M()` treated as a computed receiver |
| XRKeyboardKey.cs:396 | `value = value.ToUpper();` (local declared `string value;` at :380) | `XRKeyboardKey#GetEffectiveDisplayCharacter` → `.ToUpper`, low, method | `System.String#ToUpper`, medium (decision A) | wrong callee / wrong confidence | local named `value` handled like the setter keyword |
| SpatialKeyboardSampleProjectValidation.cs:32 (also StarterAssetsSampleProjectValidation.cs:48) | `static readonly PackageVersion s_MinimumUIPackageVersion = new PackageVersion("2.0.0");` | no implicit `#&lt;clinit&gt;` → `#s_MinimumUIPackageVersion` edge (the constructor edge exists) | implicit edge, high | missed call | field declared inside `#if/#else` gets no implicit initializer edge |

## Systematic patterns (wrong, scripted counts)
1. **W1, in-scan nested type `ValueChangeEvent` left unqualified: 17 edges.** These are 8 `AddListener`/`RemoveListener` calls in LocomotionSetup.cs, 5 `Invoke` calls and 4 `&lt;init&gt;` calls. The type is defined in XRJoystick, XRKnob, XRPushButton and XRSlider. Every other in-scan nested type is qualified correctly (`XRKnob.TrackedRotation`, `OnTrigger.TriggerEvent`, `OnCollision.CollisionEvent`).
2. **W2, `InputSystem.InputSystem.M()` emitted as low `InputSystem.M`: 6 edges**, all in InputMediator.cs (132–135, 238, 313).
3. **W3, `Generic&lt;T&gt;.StaticM()` emitted as low `.M`: 3 edges.** These are the `ComponentLocatorUtility&lt;...&gt;.TryFindComponent` calls at ClimbTeleportDestinationIndicator.cs:64 and XRInteractionSimulatorPlayModeMenu.cs:232 and :244.
4. **W4, declared local `string value` emitted as `.ToUpper`: 1 edge.** This is the only call on an identifier named `value` in the scan.

Union: 27 wrong edges out of 2588, so the census is about 98.96%. I hand-checked every W2 and W3 edge, the W4 edge, and 6 of the 17 W1 edges.

## Missed-call patterns (recall)
- The three recall functions had 0 missed calls out of 29.
- Found by looking: 2 static fields declared inside `#if UNITY_6000_0_OR_NEWER … #else … #endif` (`s_MinimumUIPackageVersion` in 2 files) have no implicit `&lt;clinit&gt;` edge. That is 2 missed edges. Every other initialized field has one.

## Spec gaps (not counted as wrong)
- **G1, 1004 edges: external types named by simple name** (`Mathf#InverseLerp`, `GameObject#SetActive`, `List#&lt;init&gt;`, medium). C# `using UnityEngine;` imports a namespace, not a type. The spec's on-demand-import rule is written only for Java/Scala/Groovy, so it does not say whether C# simple names should be qualified.
- **G2, 284 edges: low `recv.m` where the receiver is an inherited or external member** whose type is declared only outside the scan (`transform.*`, `gameObject.SetActive`, `serializedObject.FindProperty`, `selectEntered.AddListener`, `m_Simulator.*Input.*`). Decision A does not say whether declarations in external libraries count.
- **G4, 78 edges: `const` fields get an implicit `&lt;clinit&gt;` → field edge.** A C# `const` is a compile-time constant, so no initializer runs; the spec does not address constants. The 88 static-readonly and 235 instance initializer edges are correct, with no static/instance mismatches.
- **G3, 20 edges: `foreach (var x in m_Arr)` or `var x = m_Arr[i]`**, where only the declared collection gives the element type. The spec does not say whether an implicitly typed `var` loop variable counts as declared.
- **G6, 4 edges in inactive `#else/#elif` branches.** The tool emits edges from both preprocessor branches; the spec does not cover conditional compilation.
- **G5, 2 edges: receiver typed only by a cast**, `((KeyboardOptimizer)target).Optimize()` → `.Optimize`, low.
- **Also undecided, judged correct:** `var x = Call()` receivers stay low as `x.m` (41 edges). Generic factory returns (`GetComponent&lt;T&gt;()`) do not type the variable.

Correct low and unknown classes confirmed:
- `base.M()` on an external superclass → `.M` (36 edges).
- Index or call-result receivers → `.M` (13 edges).
- Delegate fields → callback, unknown (all 7 edges).

Files are in `<fanout>/`:
- s-xr-interaction-examples_report.v4.md
- s-xr-interaction-examples_r3_load.py
- s-xr-interaction-examples_r3_sample.py
- s-xr-interaction-examples_r3_types.py
- s-xr-interaction-examples_r3_lowdecl.py
- s-xr-interaction-examples_r3_implicit.py
- s-xr-interaction-examples_r3_census.py
- s-xr-interaction-examples_r3_ifelse.py
- s-xr-interaction-examples_r3_recall.py

<!-- Recovered  from the reviewer's final message in the session transcript; the report file was removed by /tmp cleanup. -->
