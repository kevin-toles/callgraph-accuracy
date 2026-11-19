# h-framerecorder (csharp) blind call-graph review, round 8

precision 48/50; census ≈98.8% (19 wrong of 1590 in-scope); recall: 0 missed of 43 real calls; 0 non-calls

## Scope
Tool output: `<scans>/final12-A/h-framerecorder.v2.json`, 1590 edges. All 1590 have a `.cs` source file, and none sits under a test/tests/spec/examples/docs segment, so all 1590 are in scope. They span 67 files.
- Confidence: medium 835, high 517, low 230, unknown 8.
- call_type: method 1249, constructor 265, implicit 68, callback 8.
- Pairs: medium/method 615, high/method 404, low/method 230, medium/constructor 220, high/implicit 68, high/constructor 45, unknown/callback 8.

The `measured_accuracy` field was ignored. Helper scripts are in the fanout folder with the prefix `h-framerecorder_r8_`.

**Precision sample.** Seed 20261113, stratified 24 medium / 15 high / 6 low / 5 unknown, spread over 30 files. Result: 48 correct, 0 wrong, 2 spec gaps (#40 `closewriter.Write`, #45 `itr.MoveNext`, both below).

**Recall functions:**
- `UnityEngine.Recorder.RecordingSession#RecordFrame` (RecordingSession.cs:124-177): 11 calls, all present.
- `UnityEngine.Recorder.Input.RenderTextureSampler#NewFrameStarting` (RenderTextureSampler.cs:152-268): 19 calls, all present.
- `UnityEngine.Recorder.Input.GameViewSize#IndexOf` (GameViewSize.cs:91-107): 13 calls, all present. 3 of them carry the wrong `@group.GetType` ID (W1).

Property reads were not counted as calls, because CAPABILITIES csharp/18 leaves that undecided.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| FrameRecorder/Inputs/CBRenderTexture/Engine/GameViewSize.cs:77 | `var customs = @group.GetType().GetField(...)` | GameViewSize#FindRecorderSizeObj → `@group.GetType`, low, method | `System.Object#GetType`, medium (`var group = Group();`, and Group() is declared `static object`) | wrong callee / wrong confidence | verbatim identifier `@group` not matched to its local, so the let-bound call-result typing is skipped and `@` leaks into the ID |
| GameViewSize.cs:94 | `var method = @group.GetType().GetMethod("IndexOf", ...)` | GameViewSize#IndexOf → `@group.GetType`, low | `System.Object#GetType`, medium | wrong callee | same |
| GameViewSize.cs:97 | `var builtinList = @group.GetType().GetField("m_Builtin", ...)` | GameViewSize#IndexOf → `@group.GetType`, low | `System.Object#GetType`, medium | wrong callee | same |
| GameViewSize.cs:103 | `method = @group.GetType().GetMethod("GetBuiltinCount");` | GameViewSize#IndexOf → `@group.GetType`, low | `System.Object#GetType`, medium | wrong callee | same |
| GameViewSize.cs:124 | `var obj = @group.GetType().GetMethod("AddCustomSize", ...)` | GameViewSize#AddSize → `@group.GetType`, low | `System.Object#GetType`, medium | wrong callee | same. Contrast GameViewSize.cs:61, where `var sizeObj = FindRecorderSizeObj(); sizeObj.GetType()` is correctly `System.Object#GetType` |
| FrameRecorder/Recorders/ImageRecorder/Engine/ImageRecorder.cs:15 | `m_Settings.m_DestinationPath.CreateDirectory();` | ImageRecorder#BeginRecording → `m_DestinationPath.CreateDirectory`, low | `UnityEngine.Recorder.OutputPath#CreateDirectory`, high | wrong callee / wrong confidence | typed field chain through the inherited `protected TSettings m_Settings` (`where TSettings : RecorderSettings`) is not followed. `RecorderSettings.m_DestinationPath` is declared `OutputPath` (RecorderSettings.cs:81). Related to open defect csharp/08 (where-bound not used) |
| ImageRecorder.cs:80 | `var fileName = m_Settings.m_BaseFileName.BuildFileName( session, ...)` | ImageRecorder#RecordFrame → `m_BaseFileName.BuildFileName`, low | `UnityEngine.Recorder.FileNameGenerator#BuildFileName`, high (RecorderSettings.cs:80) | wrong callee | same |
| ImageRecorder.cs:81 | `var path = Path.Combine( m_Settings.m_DestinationPath.GetFullPath(), fileName);` | ImageRecorder#RecordFrame → `m_DestinationPath.GetFullPath`, low | `UnityEngine.Recorder.OutputPath#GetFullPath`, high | wrong callee | same |
| Recorder/Editor/MediaRecorder.cs:91 | `m_Settings.m_DestinationPath.CreateDirectory();` | MediaRecorder#BeginRecording → `m_DestinationPath.CreateDirectory`, low | `UnityEngine.Recorder.OutputPath#CreateDirectory`, high | wrong callee | same |
| MediaRecorder.cs:95 | `... could not be created.", m_Settings.m_DestinationPath.GetFullPath()));` | MediaRecorder#BeginRecording → `m_DestinationPath.GetFullPath`, low | `OutputPath#GetFullPath`, high | wrong callee | same |
| MediaRecorder.cs:160 | `videoAttrs.frameRate.denominator, m_Settings.m_DestinationPath.GetFullPath()));` | MediaRecorder#BeginRecording → `m_DestinationPath.GetFullPath`, low | `OutputPath#GetFullPath`, high | wrong callee | same |
| MediaRecorder.cs:200 | `var fileName = m_Settings.m_BaseFileName.BuildFileName( session, ...` | MediaRecorder#BeginRecording → `m_BaseFileName.BuildFileName`, low | `FileNameGenerator#BuildFileName`, high | wrong callee | same |
| MediaRecorder.cs:201 | `var path =  m_Settings.m_DestinationPath.GetFullPath() + "/" + fileName;` | MediaRecorder#BeginRecording → `m_DestinationPath.GetFullPath`, low | `OutputPath#GetFullPath`, high | wrong callee | same |
| MediaRecorder.cs:194 | `m_WavWriters[n].Start(path);` | MediaRecorder#BeginRecording → `.Start`, low | `UnityEditor.Recorder.WavWriter#Start`, high (`private WavWriter[]  m_WavWriters;`, line 80) | wrong callee | an index into a declared array is not typed (Typed call results: "an index … is typed when its static type can be determined from declarations") |
| MediaRecorder.cs:251 | `m_WavWriters[n].Feed(audioInput.mixerGroupAudioBuffer(n));` | MediaRecorder#RecordFrame → `.Feed`, low | `UnityEditor.Recorder.WavWriter#Feed`, high | wrong callee | same |
| FrameRecorder/Inputs/RenderTextureSampler/Engine/RenderTextureSampler.cs:141 | `m_accumulateRTs[i].Create();` | RenderTextureSampler#BeginRecording → `.Create`, low | `RenderTexture#Create`, medium (`RenderTexture[] m_accumulateRTs`) | wrong callee | same |
| FrameRecorder/Core/Engine/FileNameGenerator.cs:128 | `.Replace(tags[(int)ETags.Product], UnityEditor.PlayerSettings.productName )` (line after `#if UNITY_EDITOR`) | FileNameGenerator#BuildFileName → `UnityEngine.Recorder.FileNameGenerator#Replace`, medium | `.Replace`, low, as for the chain's other links (123-126, 132-133) | wrong callee (C2: invented ID; the struct FileNameGenerator defines no Replace) | a chain link that follows a preprocessor directive is read as a bare call of the enclosing type |
| FileNameGenerator.cs:130 | `.Replace(tags[(int)ETags.Product], "(prd-NA)")` (line after `#else`) | same → `FileNameGenerator#Replace`, medium | `.Replace`, low | wrong callee | same |
| Audio/Editor/AudioInput.cs:154 | `AudioRenderer.AddMixerGroupRecorder(group.m_MixerGroup, buffer, group.m_Isolate);` | AudioInput#NewFrameReady → `UnityEditor.Recorder.Input.AudioRenderer#AddMixerGroupRecorder`, medium | low guess (C2/C4). The scanned `class AudioRenderer` (no base) defines only Start/Stop/GetSampleCountForCaptureFrame/Render | wrong confidence (C2 invented ID) | member of a scanned base-less type named medium although not defined there |
| Recorder/Editor/MediaRecorder.cs:44-59 (sample #40, Write at line 47) | `var closewriter = binwriter;` … `closewriter.Write ((byte)'W');` | WavWriter#Stop → `closewriter.Write`, low | not decided (field `BinaryWriter binwriter;`) | spec gap | see SG1 |
| FrameRecorder/Inputs/CBRenderTexture/Engine/GameViewSize.cs:80 (sample #45) | `var itr = (IEnumerator)customs...Invoke(...); while (itr.MoveNext())` | GameViewSize#FindRecorderSizeObj → `itr.MoveNext`, low | not decided | spec gap | see SG2 |
| FrameRecorder/Recorders/ImageRecorder/Engine/ImageRecorderSettings.cs:93 | `new TInputFilter<CBRenderTextureInputSettings>("Camera(s)"),` (line after `#endif`) | no edge | ImageRecorderSettings#GetInputGroups → `UnityEngine.Recorder.TInputFilter#<init>`, high, constructor | missed call | collection-initializer element right after a preprocessor directive dropped |
| ImageRecorderSettings.cs:97 | `new TInputFilter<RenderTextureSamplerSettings>("Sampling"),` (after `#endif`) | no edge | same → `TInputFilter#<init>`, high | missed call | same |
| Recorder/Editor/MediaRecorderSettings.cs:93 | `new TInputFilter<RenderTextureSamplerSettings>("Sampling (off screen)"),` (after `#endif`) | no edge | MediaRecorderSettings#GetInputGroups → `TInputFilter#<init>`, high | missed call | same |
| Recorder/Editor/MediaRecorderSettings.cs:23 | `public UnityEditor.VideoBitrateMode m_VideoBitRateMode = UnityEditor.VideoBitrateMode.High;` (after `#if UNITY_2018_1_OR_NEWER`) | no edge | `UnityEditor.Recorder.MediaRecorderSettings#<init>` → `#m_VideoBitRateMode`, high, implicit | missed call | field declaration right after a preprocessor directive gets no implicit edge (the neighbours at lines 21 and 25 have one) |

## Systematic patterns (wrong edges, scripted counts)
The union is 19 edges and no edge is in two patterns. Census precision = 1 − 19/1590 = 98.8%.

1. **W2, typed field chain through a generic-base field left low: 8.** The receivers are `m_Settings.m_DestinationPath.*` and `m_Settings.m_BaseFileName.*` in ImageRecorder and MediaRecorder.
   - Script: `h-framerecorder_r8_c2.py`, plus a grep of low edges on lines containing `m_Settings.`. All 8 were checked by hand.
   - `m_Settings` is `protected TSettings m_Settings` with `where TSettings : RecorderSettings`. Both fields are declared on RecorderSettings, so the bound reading and the substituted reading give the same target.
2. **W1, verbatim identifier `@group`: 5.** GameViewSize.cs:77, 94, 97, 103, 124.
   - The local is `var group = Group();` and `Group()` is declared `static object`, so per the let-bound ruling it should give `System.Object#GetType`, medium.
   - The same file types `sizeObj = FindRecorderSizeObj()` correctly. The ID also carries the `@` escape.
3. **W3, index into a declared array not typed: 3.** MediaRecorder.cs:194, MediaRecorder.cs:251 and RenderTextureSampler.cs:141.
   - Script: `h-framerecorder_r8_arr.py`. It found every `.m` low edge whose receiver is `ident[...]` with `ident` declared `T[]`.
   - The dictionary/List indexer case (RecordersInventory.cs:126 `m_RecordersByCategory[...].Add`) is correctly low: its type comes only from a library signature.
4. **W4, chain link after `#if`/`#else` resolved as an enclosing-type bare call: 2.** FileNameGenerator.cs:128 and 130.
   - Script: `h-framerecorder_r8_afterpp.py`, which lists every edge on a line that follows a directive. Only these two are mis-resolved.
5. **W5, C2 invented member of a scanned base-less type at medium: 1.** AudioInput.cs:154.
   - Script: `h-framerecorder_r8_c2.py`. Every medium callee on a scanned type was checked against definitions and bases. The other 18 are inherited from an external base and correct: `AboutBox#Close` (EditorWindow), `RecorderWindow#Repaint`/`#GetWindow`, `RecorderComponent#StartCoroutine` (MonoBehaviour), `Recorder#GetType` (ScriptableObject), `RecorderInputSetting#GetType` and `RecorderSettings#GetType` (ScriptableObject).
   - `InputSettingsList#Cast` is an extension-method spec gap (SG6).

Checked and found correct:
- All 68 implicit edges (static fields go to `<clinit>`, instance fields to `<init>`; `const` fields get none).
- All 22 `base.` and `: base(...)` edges.
- All 8 callbacks (Action/delegate fields and parameters).
- C1: every high callee is in `nodes`.
- `string`/`object`/`int` keyword aliases → `System.String`/`System.Object`/`System.Int32`.
- The `using Object = UnityEngine.Object;` alias → `UnityEngine.Object#Destroy`.
- No output matched open defect csharp/11. No `.m` low edge sits on the result of a call to a scanned method with a scanned return type.

## Missed-call patterns (recall)
- **Collection-initializer element on the line right after `#endif`: 3 missed constructor edges.** ImageRecorderSettings.cs:93 and 97, MediaRecorderSettings.cs:93. Elements on lines after `#if` (91, 95) are present.
  - Script: `h-framerecorder_r8_miss.py` (lines with more call tokens than edges) plus `h-framerecorder_r8_afterpp.py`.
- **Field initializer on the line right after `#if`: 1 missed implicit edge.** MediaRecorderSettings.cs:23. Script: `h-framerecorder_r8_fieldinit.py`.
- The 3 recall functions had 0 missed calls out of 43, and 0 non-calls.

## Spec gaps (not counted as wrong)
- **SG1, `var` local bound to a typed identifier: 28 edges.**
  - Construct: MediaRecorder.cs:36, `var closewriter = binwriter;` (field `BinaryWriter binwriter;`), then `closewriter.Write(...)`, `.Seek`, `.Flush`.
  - Open question: decision A lists declarations and `= new T(...)`, and the 2026-11-12 ruling types a local bound to a *call result*. Does a `var` local take the declared type of an identifier, field or property it is initialized from?
- **SG2, cast-typed receivers: 23 edges.**
  - In place (7): `(target as RecorderSettings).ValidityCheck(errors)`, `(input as IDisposable).Dispose()`, `((IEnumerable<RecorderInputSetting>)m_InputsSettings).GetEnumerator()`, `(target as RenderTextureSamplerSettings).m_ColorSpace.ToString()`.
  - Through a `var` (6): `var rs = target as RecorderSettings; rs.BindSceneInputSettings(...)`, `var itr = (IEnumerator)…; itr.MoveNext()`.
  - Through a field chain off such a `var` (10): `aRecorderSettings.inputsSettings.Remove(ais)`, `animImputSetting.gameObject.GetComponent<…>()`, `aInput.m_gameObjectRecorder.SaveToClip(clip)`.
  - Open question: casts are "not calls", and "Typed call results" covers a call result, an index or a literal. Does an `as T` or `(T)x` expression type its value, in place and when bound to `var`, as T?
- **SG3, `foreach (var x in c)` over a collection with a declared type: 9 edges.**
  - Constructs: `foreach (var input in m_Inputs) input.SessionCreated(this)` (`List<RecorderInput> m_Inputs`), `foreach (var a in m_Buffers) a.Dispose()` (`NativeArray<float>[]`), and `var cam = hookedCam.camera; cam.Render()` with `hookedCam` a foreach variable.
  - Open question: decision A names "for-loop variable" declarations. Does an implicitly typed foreach variable take the element type of a declared collection, for arrays (a language construct) and for generic collections (where the element type comes from a library `IEnumerable<T>` signature)?
- **SG4, `var` or in-place operator expressions: 6 edges.**
  - Constructs: AnimationRecorder.cs:28, `var dir = "Assets/" + ars.outputPath; dir.LastIndexOf(...)`; FRPackagerPaths.cs:27, `var path = Application.dataPath + …; path.Replace(...)`; AnimationRecorder.cs:55, `(idx+1).ToString("00")`.
  - Open question: is the static type of a binary-operator expression (string concatenation, int arithmetic) a "type determined from declarations" for a receiver or a `var` local?
- **SG5, generic-base type-argument substitution: 1 edge.**
  - Construct: MediaRecorder.cs:200, `m_Settings.m_OutputFormat.ToString()`, inside `class MediaRecorder : GenericRecorder<MediaRecorderSettings>`. `m_OutputFormat` exists only on MediaRecorderSettings, not on the bound RecorderSettings.
  - Open question: SPEC says a type variable resolves to its declared bound. For a member inherited from a closed generic base, is `m_Settings` typed by the bound or by the subclass's type argument?
- **SG6, extension methods on typed receivers: 6 edges.**
  - Constructs: `inputsSettings.Cast<AnimationInputSettings>()` → `InputSettingsList#Cast`; `m_InputsSettings.ToList()` → `List#ToList`; `bindingType.Any(...)` → `List#Any`; `m_Inputs.Select(...)` → `List#Select`; `RecordersInventory.ListRecorders().GroupBy(...)` → `IEnumerable#GroupBy`; `FileNameGenerator.tagLabels.ToList()` → `tagLabels.ToList` (low).
  - Also present in the scan: the in-scan extensions `SerializableObjHelper.FindProperty(this SerializedObject …)` / `FindPropertyRelative(this SerializedProperty …)`.
  - Open question: this is CAPABILITIES csharp/17, undecided. Is the callee the declaring static class's method (`System.Linq.Enumerable#Select`, `UnityEditor.Recorder.SerializableObjHelper#FindProperty`), the receiver type's `T#m`, or a low guess?
- **SG7, inactive preprocessor branches: 62 edges** (56 inside `#if RECORD_AUDIO_MIXERS`, a symbol never defined in the scan; 6 inside `#else` branches of `UNITY_EDITOR` / `UNITY_2018_*`). They overlap SG1, W3 and W5.
  - Construct: AudioInput.cs:146-156, `#if RECORD_AUDIO_MIXERS … AudioRenderer.AddMixerGroupRecorder(...) #endif`; UnityHelpers.cs:22-23, `#else Object.Destroy(obj);`.
  - Open question: SPEC does not say which conditional-compilation branches are graphed. Should calls in mutually exclusive `#if`/`#else` branches, or under symbols no build defines, be emitted, and judged as written?
- **SG8, invocation of a computed delegate expression: 1 construct, 0 edges.**
  - Construct: AudioInput.cs:103, `m_ChannelCount = new Func<ushort>(() => { … })();`. The tool emits only `Func#<init>`.
  - Open question: the callback rule names the parameter, local or stored property that holds the function. What edge, if any, does an invocation of an unnamed delegate value (the result of `new Func<…>(…)`) produce, and with what callee ID?
