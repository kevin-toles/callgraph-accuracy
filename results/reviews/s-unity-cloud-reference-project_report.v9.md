# Blind call-graph review: s-unity-cloud-reference-project (csharp), round 9

precision 49/50; census ≈99.13% (87 wrong of 10005 in-scope); recall: 0 missed of 30 real calls; 0 non-calls

(49/50 = 47 correct + 2 spec gaps, which are not counted as wrong; 1 wrong.)

## Scope
Tool output `final13-A/s-unity-cloud-reference-project.v2.json`, 10005 edges, all from `.cs` files. No edge's path has a segment named exactly `test`, `tests`, `spec`, `examples` or `docs`. SPEC (Decisions 2026-11-09) names those segments exactly, so the Unity `Tests/` directories (capital T) are in scope like any other code. In-scope edges: **10005** in 431 files.
- Confidence: high 5081, medium 3584, low 1095, unknown 245.
- call_type: method 7178, constructor 1772, implicit 806, callback 245, direct 4.

As instructed, I ignored the `measured_accuracy` field. Helper scripts are in the fanout folder with the prefix `s-unity-cloud-reference-project_r9_`.

## Precision sample
The sample uses seed 9013, stratified as high 24, medium 16, low 5, unknown 5. That is 50 edges in 50 distinct files. For each edge I checked whether it is a real call, the caller, the callee, the tier, the call_type and the line:
- **47 correct.** Examples:
  - field-initializer callers (`Si#Yottameter`, `TestsConvert#GetConvertTime`)
  - `implicit` `<init>`/`<clinit>` edges
  - `: this(...)` argument calls under `#<init>`
  - interface members at high (`IAppMessaging#ShowInfo`, `IRigUIController#ClearMainBar`)
  - inherited-external bare calls named by the calling type (`Teleport#EndLocomotion`, `WorldSpaceAvatarTag#Destroy`, medium)
  - `base.Start()` resolving to the in-scan superclass
  - using-alias expansion (`using Vector3 = UnityEngine.Vector3`)
  - delegate fields, events and parameters as callback/unknown
- **2 spec gaps:** #26 and #36, both extension-method calls (below).
- **1 wrong:** #27.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| DataStreaming/Runtime/Scripts/DataStreamControllerInstaller.cs:25 (sample #27) | `Container.Bind<IDataStreamBound>().To<DataStreamBound>().AsSingle();` | DataStreamControllerInstaller#InstallBindings → `Container#Bind`, medium, method | `Container.Bind`, low, method. `Container` is the `DiContainer` property inherited from Zenject's `MonoInstaller`, which is outside the scan. No type named `Container` exists. | wrong callee + wrong confidence | Capitalized inherited property taken for a type name |
| AssetList/Runtime/Scripts/Controllers/CollectionGridUIController.cs:30 (sample #26) | `m_CollectionGridScrollView = m_CollectionGrid.Q<ScrollView>();` | → `GridView#Q`, medium, method | undecided (`Q` is the extension `UQueryExtensions.Q`) | spec gap | csharp/17 extension methods |
| Tools/Runtime/Scripts/Controllers/Panel.cs:22 (sample #36) | `CloseButton = rootVisualElement.Q<Button>("close-button");` | Panel#<init> → `VisualElement#Q`, medium, method | undecided | spec gap | csharp/17 extension methods |
| Metadata/Runtime/Scripts/MetadataDisplayController.cs:346 | `parameterLabel.text = m_HighlightModule.IsHighlighted(nameof(MetadataList.Key), data.Key).Item2;` | `MetadataDisplayController#SetupList` → HighlightModule#IsHighlighted, high | caller `MetadataDisplayController#SetupList.bindItem` (`Action<VisualElement, int> bindItem = (element, i) => {…}` is a local bound to a lambda) | wrong caller | open defect csharp/09 |
| InputSystem consumers: ObjectSelectionController.cs:80 | `m_InputScheme[k_MouseSelectAction].RegisterValidationPeformedFunc(IsPickingValid);` | → `.RegisterValidationPeformedFunc`, low | `Unity.ReferenceProject.InputSystem.InputActionWrapper#RegisterValidationPeformedFunc`, high. `InputScheme m_InputScheme`, scanned indexer `public InputActionWrapper this[string actionName]`. | wrong callee + confidence | Index receiver not typed (Typed call results) |
| Navigation/Runtime/Scripts/NavigationSwitchTool.cs:61 | `if (navigationModes[i].CheckDeviceCapability())` | → `.CheckDeviceCapability`, low | `…NavigationModeData#CheckDeviceCapability`, high. `var navigationModes = m_NavigationManager.NavigationModes;` and the property is declared `NavigationModeData[] NavigationModes { get; }`. | wrong callee + confidence | Index of a declared array not typed |
| UIPanel/Tests/MainUIPanelEntryTests.cs:158 | `items[i].GetComponent<UIDocument>()` (`params GameObject[] items`) | → `.GetComponent`, low | `GameObject#GetComponent`, medium | wrong callee + confidence | Index of a declared array not typed |
| VRControls/.../Handle.cs:194 | `var targetPosition = new Ray(rayOrigin.position, rayOrigin.forward).GetPoint(targetHoldDistance);` | → `.GetPoint`, low | `Ray#GetPoint`, medium | wrong callee + confidence | `new T(...)` result receiver not typed |
| com.unity.gis.unit/Tests/Runtime/TestsError.cs:115 | `() => { new Length(new UnitNaming("", "")).RegisterAsBaseUnit(); });` | → `.RegisterAsBaseUnit`, low | `Unity.Geospatial.Unit.UnitDef#RegisterAsBaseUnit`, high (defined on the scanned base `UnitDef<T>`) | wrong callee + confidence | `new T(...)` result receiver not typed |
| AssetList/.../TransformationWorkflowUIController.cs:305 | `transformationElement.Refresh(transformation);` (bound by `… is TransformationDataElement transformationElement`) | → `transformationElement.Refresh`, low | `…TransformationWorkflowUIController.TransformationDataElement#Refresh`, high | wrong callee + confidence | open defect csharp/07 (is-pattern binding) |
| VR RigUI Handle.cs:137 | `if (interactor is ILineRenderable lineRenderable && lineRenderable.TryGetHitInfo(out var p…` | → `lineRenderable.TryGetHitInfo`, low | `ILineRenderable#TryGetHitInfo`, medium | wrong callee + confidence | open defect csharp/07 |
| persistence-api/Runtime/CloudServices/Api.cs:293 | `if (data.GetType() == typeof(byte[]))` in `CreateUploadRequest<T>(string uri, T data, …)` | → `T#GetType`, medium | `data.GetType`, low (unconstrained type variable stays low) | wrong callee + confidence | Type parameter used as a type name |
| DataStores/Runtime/Scripts/DataStore.cs:134 | `changed = !value.Equals(oldValue);` in `bool Compare<TValue>(TValue value, TValue oldValue)` | → `TValue#Equals`, medium | `value.Equals`, low | wrong callee + confidence | Type parameter used as a type name |
| _VR/.../AppMessagingVR.cs:262 | `cancelCallback?.Invoke();` with `var cancelCallback = modalMessage.CancelCallback;` (field `public readonly Action CancelCallback;`) | → `cancelCallback.Invoke`, low, method | `cancelCallback`, unknown, callback (a local holding a function) | wrong callee + tier + call_type | Delegate type through `var` from a declared field not used |

## Systematic patterns (scripted census: `s-unity-cloud-reference-project_r9_census.py`), by count
| # | pattern | wrong edges | validation |
|---|---|---|---|
| 1 | Zenject's inherited `Container` property is named as a type: `Container#Bind/Resolve/…`, medium (should be `Container.m`, low) | 69 | All 69 have a bare `Container.` receiver and sit in 27 `MonoInstaller` subclasses. No `class/struct/interface Container` exists in the source root. Checked by hand: DataStreamControllerInstaller.cs:13 and :25, CameraInstaller.cs:19, ServicesInstaller.cs:64. |
| 2 | Lambda bound to a typed local (`Func<VisualElement> makeItem = () => {…}`, `Action<…> bindItem = …`): body calls are folded into the enclosing method instead of `…#SetupList.makeItem/.bindItem` (open defect csharp/09) | 5 | MetadataDisplayController.cs:330, 343, 344, 346, 347. These are the only lambda-bound locals found in scope. |
| 3 | Index receiver typed by scanned declarations left as `.m` low (scanned `InputScheme` indexer ×3, `NavigationModeData[]` ×1, `GameObject[]` ×1) | 5 | Each checked by hand. The other 28 index receivers are generic containers (`Dictionary`/`List`) or library-typed, so low is correct for them. |
| 4 | `new T(...).m()` with T known left as `.m` low | 3 | Ray, GameObject and Length, each checked by hand. `new ServiceHttpClient(...).WithApiSourceHeaders` is left out (probably an external extension, spec gap). |
| 5 | is-pattern binding stays low (open defect csharp/07) | 2 | Both checked by hand. `case AssetType assetType: assetType.GetValueAsString()` is left out because `GetValueAsString` is not defined in the scan (probably an extension). |
| 6 | Unconstrained method type parameter used as a type (`T#GetType`, `TValue#Equals`) | 2 | A script found every callee type that is a type parameter in its file; only these 2 are real. |
| 7 | Delegate-typed `var` local from a declared `Action` field called through `?.Invoke()` and emitted as a low guess | 1 | AppMessagingVR.cs:262. Explicitly typed delegate locals and parameters are correctly callbacks, e.g. PresenceRoomsManager.cs:128. |

Union: 87 edges. 1 − 87/10005 = **99.13%**.

I checked these patterns and found nothing:
- delegate fields emitted as `T#f` methods (csharp/16): 0
- `.m` on scanned call results (csharp/11): 0
- high callee missing from `nodes`: 0
- medium callee naming an undefined member of a scanned type (C2): 0
- `: this(...)` / `: base(...)` without a constructor edge: 0 of 154
- const fields given implicit edges, or a static/instance `<clinit>`/`<init>` mix-up: 0

## Missed-call patterns (recall)
- The 3 recall functions had no misses:
  - `WalkModeInputsController#InitializeInputs` (WalkModeInputsController.cs:157–193): 6 of 6
  - `Unit#To(IUnitDef, IFormula)` (Unit.cs:1142–1177): 10 of 10, including `AbstractFormula?.Invoke` as a callback on a `Func` property
  - `AnnotationController#CreateTopic` (AnnotationController.cs:111–130): 14 of 14
- **Target-typed `new(...)` gets no constructor edge (open defect csharp/15):** 392 occurrences in 83 in-scope files, none emitted. Examples:
  - `public static readonly Length Yottameter = new(new UnitNaming(…), …)` at Si.cs:145, which gets only the `UnitNaming#<init>` edge
  - `readonly Dictionary<string, MeasurementInfo> m_Measurements = new();` at MeasurementViewer.cs:21
- **User-defined operator applications emit no edge.** Example: `Meter * 1E24` at Si.cs:145 runs `UnitDef.op_Multiply`, which is scanned. This is counted as a spec gap below, not a miss.

## Spec gaps (counted separately, never as wrong)
1. **C# extension methods (csharp/17): 250 edges.** `Q` 151, LINQ 71, `RegisterValueChangedCallback`/`UnregisterValueChangedCallback` 22, `Query` 1, scanned extensions 5, plus 2 low edges that may be external extensions (`WithApiSourceHeaders`, `GetValueAsString`). Example construct: `m_CollectionGrid.Q<ScrollView>()` → `GridView#Q`, and scanned `element.GetFirstAncestorWithName(name)` → `element.GetFirstAncestorWithName` low. The open question, as SPEC leaves it: does an extension-method call get the declaring static class's ID (`UQueryExtensions#Q`, `Unity.ReferenceProject.VisualElementExtensions#GetFirstAncestorWithName` high), the receiver's type under decision A (`GridView#Q`), or a low guess?
2. **C# keyword type names: 146 edges.** `string.Join(...)` → `System.String#Join`, `double.Parse` → `System.Double#Parse`, `object arg; arg.ToString()` → `System.Object#ToString`, while `new String('0', n)` → `String#<init>`. The open question: SPEC says external types are "named as written" (not expanded through `using`) and type aliases are expanded to their target. Is a C# built-in keyword (`string`, `int`, `object`) a written name (`string#Join`) or an alias to expand (`System.String#Join`)?
3. **Property and indexer accessors (csharp/18).** No edges are emitted, so nothing is counted. Example: `m_MoveAction = m_InputScheme[k_MoveAction];` calls the scanned indexer getter, and `m_MoveAction.IsEnabled = true;` calls a scanned setter. The open question: is a read or write of a user-defined property or indexer a call edge to `Type#Prop`/`Type#Prop=` (and which ID for an indexer)?
4. **User-defined operators.** No edges are emitted. Example: `Meter * 1E24`, where `UnitDef` defines `operator *` (node `UnitDef#op_Multiply`). The open question: is an application of a scanned C# operator overload an invocation edge, and if so with which ID, call_type and line?
