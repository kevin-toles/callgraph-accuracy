# s-nvidia-streamline (cpp): blind call-graph review, round 16

precision 49/50; census ≈99.10% (160 wrong of 17791 in-scope); recall: 3 missed of 52 real calls; 1 non-calls

(49/50 = 46 correct plus 3 spec gaps. The census's 160 wrong edges are the union of 15 scripted patterns. Spec gaps are counted separately: 744 edges.)

## Scope
The tool JSON has 18276 edges. 485 of them are in other languages (.lua 344, .py 141) and are ignored. No edge path has a test/, tests/, spec/, examples/ or docs/ segment, so **17791 in-scope C++ edges** (.cpp 9313, .h 4493, .hpp 3985) over 153 files remain. The external/ SDK headers (dx-agility, json, ngx, nsight) are in scope per Decisions 2026-11-09.
- Confidence: high 8401, medium 5649, low 3298, unknown 443.
- call_type: method 8682, direct 3880, macro 3586, constructor 1200, callback 443.

Sample: seed 16, stratified 22 high / 15 medium / 8 low / 5 unknown, over 37 files. I ignored `measured_accuracy`. Helper scripts are `s-nvidia-streamline_r16_*.py` in the fanout folder.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| source/plugins/sl.common/commonInterface.h:144 (sample #9) | `chi::Resource buffer{};` | sl.SwapChainContext#resizeProxyBuffers → sl.Resource#<init>, high, constructor | no edge: `using Resource = sl::Resource*;` (sl.chi/compute.h:58), so this value-initialises a pointer | not a call | alias expanded but the pointer was dropped |
| source/platforms/sl.chi/generic.cpp:169 (recall) | `Resource res{};` (inside `sl::chi`) | sl.chi.ResourcePool#allocate → sl.Resource#<init>, high, constructor | no edge (same pointer alias) | not a call | same as above |
| source/core/sl.interposer/dxgi/dxgi.cpp:163 (recall) | `hr = ((PFunCreateSwapChainForHwndBefore*)hook)(pFactory, …);` | (no edge) | sl.interposer.IDXGIFactory2_CreateSwapChainForHwnd → hook, unknown, callback | missed call | call through a cast of a local fn pointer is not emitted |
| source/core/sl.interposer/dxgi/dxgi.cpp:183 (recall) | `for (auto [hook, feature] : hooks) ((PFunCreateSwapChainForHwndAfter*)hook)(…);` | (no edge) | … → hook, unknown, callback | missed call | same |
| external/json/include/nlohmann/detail/json_pointer.hpp:327 (recall) | `JSON_THROW(detail::type_error::create(313, …));` | (no edge; only the `type_error#create` edge) | → JSON_THROW, high, macro (`#define JSON_THROW(exception) throw exception`, macro_scope.hpp:157) | missed call | JSON_THROW invocations get no edge (it is also redefined object-like under `JSON_THROW_USER`) |
| external/json/include/nlohmann/detail/json_pointer.hpp:302 (recall) | `result = &result->operator[](reference_token);` | nlohmann.json_pointer#get_and_create → result, unknown, callback | → result.operator[], low, method (receiver is a template-parameter pointer) | wrong callee | explicit `x->operator[](…)` read as a call through variable `x` |
| external/json/include/nlohmann/json.hpp:4083 | `detail::binary_reader<basic_json, decltype(ia), SAX>(std::move(ia), format).sax_parse(format, sax, strict);` | nlohmann.basic_json#sax_parse → .sax_parse, low, method | → nlohmann.detail.binary_reader#sax_parse, high, method | wrong callee | constructor-expression receiver not typed (Typed call results / `new T` rule) |
| source/core/sl.file/file.h:302 | `return fs::path(path).is_relative();` | → .is_relative, low | → std.filesystem.path#is_relative, medium | wrong callee | same |
| source/plugins/sl.common/commonEntry.cpp:1363 | `parameters->set(param::global::kPFunGetConsts, getCommonConstants);` with `auto parameters = api::getContext()->parameters;` at 1360 | sl.slOnPluginStartup → parameters.set, low, method | → sl.param.IParameters#set, high, method (`Context *getContext();` in plugin.h:116; field `sl::param::IParameters *parameters{}` in plugin.h:110) | wrong callee | local bound to a field of a typed call result left untyped |
| source/core/sl.file/file.h:68 | `fs::path p(fname);` (`namespace fs = std::filesystem;`, file.h:49) | → fs.path#<init>, medium | → std.filesystem.path#<init>, medium (the tool itself emits that ID at file.h:302) | wrong callee | namespace alias not expanded for declarations; C1/C2 split |
| external/json/include/nlohmann/ordered_map.hpp:58 | `if (m_compare(it->first, key))` | nlohmann.ordered_map#emplace → m_compare, low, direct | → std.equal_to#operator(), medium, method (field typed `key_compare` = `std::equal_to<Key>`) | wrong callee | functor field call; matches open defect cpp/16 |
| external/json/include/nlohmann/detail/output/binary_writer.hpp:1831 | `const bool is_little_endian = little_endianness();` (class member) | external/…/binary_writer → nlohmann.detail.little_endianness | caller nlohmann.detail.binary_writer#is_little_endian | wrong caller | open defect cpp/10 (field initialisers) |
| source/plugins/sl.imgui/imgui_impl_dx12.cpp:589 | `vertexShaderBlob->Release();` | source/plugins/sl.imgui/imgui_impl_dx12 → vertexShaderBlob.Release | caller ImGui_ImplDX12_CreateDeviceObjects | wrong caller | caller lost after a multi-line HLSL string with `\` continuations (lines 520–535) |
| source/plugins/sl.imgui/imgui_impl_dx12.cpp:501 | `output.pos = mul( ProjectionMatrix, float4(input.pos.xy, 0.f, 1.f));\` (inside a string literal) | main → mul, low, direct | no edge | not a call | HLSL text inside a C++ string literal parsed as code |
| source/plugins/sl.common/commonEntry.cpp:527 | `if (!(*common::getContext()).constants.set(frame, viewport, &consts))` | source/plugins/sl.common/commonEntry → constants.set | caller slSetConstants (namespace-qualified as elsewhere) | wrong caller | caller lost after `SL_RUN_ONCE { … }` |
| external/nsight-sdk/SystemsGraphics/include/Impl/NGFX_Core.h:457 | `void* proc = (void*)GetProcAddress((HMODULE)lib, name);` | external/…/NGFX_Core → GetProcAddress | caller NGFX_GetProc | wrong caller | function head prefixed by the `NGFX_FUNCTION` macro not recognised |
| source/plugins/sl.dlss/dlssEntry.cpp:994 | `imgui::Float4 greenColor{ 0,1,0,1 };` | → imgui.Float4#<init>, medium | → sl.type.Float4#<init>, high (`using namespace type;` in sl.imgui/imgui.h:17; struct in sl.imgui/types.h) | wrong callee | type not resolved through the header's using-directive |
| external/json/include/nlohmann/detail/iterators/json_reverse_iterator.hpp:99 | `return static_cast<json_reverse_iterator>(base_iterator::operator-(i));` | → std.reverse_iterator.operator-, medium, direct | → std.reverse_iterator#operator-, medium, method | wrong callee | qualified base-member call formatted as a namespace function |
| source/platforms/sl.chi/d3d12.cpp:97 | `wchar_t name[128] = {};` | → wchar_t#<init>, medium, constructor | no edge | not a call | fundamental-type array initialiser treated as a constructor |
| external/dx-agility-sdk-headers-1.714.0-preview/include/d3dx12/d3dx12_core.h:54 | `: D3D12_RECT( o )` | → D3D12_RECT#<init>, medium | → RECT#<init>, medium (`typedef RECT D3D12_RECT;` d3d12.h:1519; the tool emits RECT#<init> elsewhere) | wrong callee | type alias not expanded |
| external/json/include/nlohmann/ordered_map.hpp:172 | `new (&*it) value_type{std::move(*next)};` | → value_type#<init>, medium | alias target `typename Container::value_type` (std::vector member type) | wrong callee | alias not expanded |
| source/platforms/sl.chi/generic.cpp:446 | `ResourceTrackingMap::const_iterator resourceMapIt{};` | → ResourceTrackingMap.const_iterator#<init> | → std.map.const_iterator#<init> (`using ResourceTrackingMap = std::map<…>`, generic.h:133) | wrong callee | alias not expanded |
| external/nsight-sdk/SystemsGraphics/include/Impl/NGFX_Core.h:1554 (sample #38) | `strcpy(installationPath, defaultDestinationPath);` | NGFX_Do_EnumerateInstallationsFromDefaultDestination → strcpy, low, direct | open: medium or low | spec gap | C runtime call (see Spec gaps) |
| external/json/include/nlohmann/json.hpp:240 (sample #45) | `return allocator_type();` | nlohmann.basic_json#get_allocator → allocator_type, low, direct | open | spec gap | template-parameter type construction (see Spec gaps) |

## Systematic patterns (scripted census, by count; union = 160)
Each pattern was hand-checked on at least two of its edges (script `s-nvidia-streamline_r16_census.py`).
1. **Constructor-expression receiver left as `.m`**: 32. Examples: `binary_reader<…>(…).sax_parse` (17), `binary_writer<…>(o).write_*` (10), `json_pointer(x).get_and_create`, `fs::path(p).is_relative`, `std::wstring(…).c_str`, `std::filesystem::path(…).remove_filename`, `std::chrono::duration<float>(…).count`. The receiver's type is the constructed type.
2. **`auto parameters = api::getContext()->parameters` receiver untyped**: 27 `parameters.set` edges in 8 plugin entry files. These should be `sl.param.IParameters#set` (high), as the tool already gives 31 times where the local is declared `IParameters*`.
3. **Namespace alias `fs::` not expanded**: 18 `fs.path#…` / `fs.directory_iterator#<init>` edges. The tool emits `std.filesystem.path#…` for the same type 17 times, which breaks C1 and C2.
4. **Functor field `m_compare(…)` as low direct bare name**: 14 (ordered_map.hpp). This is the open defect cpp/16 (operator() on typed objects).
5. **Explicit `p->operator[](…)` / `it.operator*()` as a callback through the receiver**: 12 (json_pointer.hpp 11, json_reverse_iterator.hpp 1).
6. **Caller lost after a multi-line string literal** (imgui_impl_dx12.cpp:538–594): 11. The rest of `ImGui_ImplDX12_CreateDeviceObjects` gets the file as caller.
7. **Type aliases not expanded in constructor IDs**: 10. `D3D12_RECT` (2), `value_type` (3), `make_integer_sequence` (4; `make_index_sequence`/`index_sequence_for` → alias → dependent type), `ResourceTrackingMap::const_iterator` (1).
8. **Type reached through a using-directive not resolved** (`imgui::Float2/Float4` → `sl.type.FloatN`): 9.
9. **Qualified base-class operator call given a dotted, direct ID** (`std.reverse_iterator.operator++`): 7.
10. **Field initialiser caller is the file** (binary_reader.hpp:2957/2963, lexer.hpp:1605, binary_writer.hpp:1831, ordered_map.hpp:356): 5. This is open defect cpp/10.
11. **Pointer alias `chi::Resource` (= `sl::Resource*`) value-init as a constructor**: 5. The `sl::Resource r{}` lines, where the real struct is constructed, are correctly excluded.
12. **Fundamental-type array initialiser as a constructor** (`wchar_t#<init>`): 3.
13. **Calls inside a string literal** (HLSL in imgui_impl_dx12.cpp:501/534: `mul`, `float4`, `texture0.Sample`, caller `main`): 3.
14. **Caller lost after `SL_RUN_ONCE { … }`** (commonEntry.cpp:527): 2.
15. **Caller lost for an `NGFX_FUNCTION`-prefixed definition** (NGFX_Core.h:457/464): 2.

## Recall
Functions checked:
- `sl.interposer.IDXGIFactory2_CreateSwapChainForHwnd`, dxgi.cpp:123–189: 24 real calls, 22 found, **2 missed**.
- `sl.chi.ResourcePool#allocate`, generic.cpp:145–183: 20 real calls, 20 found. 1 non-call: the line 169 `Resource res{}` (pattern 11).
- `nlohmann.json_pointer#get_and_create`, json_pointer.hpp:274–331: 8 real calls, 7 emitted, **1 missed** (JSON_THROW). Four of the 7 are emitted with the wrong callee (pattern 5).

Missed-call patterns, counted over the source:
- **Call through a cast of a local function pointer** `((PFun…*)hook)(…)`: 33 occurrences in source/, 0 `hook` edges.
- **`JSON_THROW(…)` invocations**: 141 occurrences in external/json, 0 edges. `JSON_HEDLEY_*` and `JSON_ASSERT` are emitted.
- Open defect cpp/03 (delegating constructor `: ScopedProfilingSection(compute, cmdList)`, generic.cpp:102) was also observed with no edge. That is an open defect, so it counts as recall, not wrong.

## Spec gaps (744 edges, counted separately, never as wrong)
- **C runtime functions from system headers** (`memcpy(…)`, `strcpy(…)`, `free`, `strlen`, `min`/`max`, …), emitted bare, low, direct: 250 (sample #38, #42). For C++, SPEC does not settle whether such a call is medium ("an import", via `#include <cstring>`) or low ("a bare name not found in the scan"). CAPABILITIES lists the same question as undecided for C (c/13).
- **External qualifier of unknown kind** (`::ImGui::TextWrappedV(fmt, args)`, `ImGui::GetIO()`, `ImPlot::…`), emitted `ImGui#m`, medium, method: 424. imgui.h is not in the scan. SPEC does not say whether `X::f()` with an out-of-scan `X` is named as a class member (`X#f`, method) or as a namespace function (`X.f`, direct).
- **Function-pointer variables declared by a macro expansion** (`SL_FEATURE_FUN_IMPORT_STATIC(sl::kFeatureDLSS, slDLSSSetOptions); return s_slDLSSSetOptions(viewport, options);`), emitted low direct bare: 23. The 2026-11-12 generated-functions ruling covers functions a macro defines. It does not cover variables a macro declares, so whether the call is a callback is open.
- **Construction of a template-parameter type, or an alias of one** (`return allocator_type();`, `BasicJsonType k = BasicJsonType(val);`, `const Allocator& alloc = Allocator()`), emitted low, direct, bare: 12 (sample #45). SPEC does not fix the ID (bare alias, `T#<init>`) or the call_type (direct or constructor) for an unconstrained dependent type.
- **Receivers of `auto x = static_cast<T*>(…)`** (`auto unknown = static_cast<IUnknown*>(baseInterface); … unknown->QueryInterface(&d3d12Device)`), left low: 37. The let-bound ruling covers locals bound to call results. SPEC does not say whether a local bound to a cast takes the cast's target type.
- **Calls in unevaluated operands** (`void_t<decltype(begin(std::declval<ContainerType>()), end(std::declval<ContainerType>()))>`, input_adapters.hpp:403): 2. SPEC lists `sizeof` as not a call. It does not say whether calls written inside `decltype`/`sizeof` operands are edges.
- Observed in recall, not census-counted:
  - **Calls in a disabled preprocessor block**: `#if SL_DEBUG_RESOURCE_POOL` with the macro defined 0 (generic.cpp:176–180; `assert`, `SL_LOG_VERBOSE`, `.size` were emitted). SPEC does not say whether code the preprocessor removes yields edges.
  - **Invoking a call result**: `sl::interposer::call(IDXGIFactory2_CreateSwapChainForHwnd, hook…)(pFactory, …)` (dxgi.cpp:151/174). SPEC gives no callee ID for calling a returned function value.
  - **Default-initialising declarations of class type** (`Microsoft::WRL::ComPtr<IUnknown> deviceProxy;`, `ResourceDescription desc;`). SPEC does not say whether the implicit default-constructor run is a `Type#<init>` edge, as `T x{}` is.
  - **Overloaded operators written in operator syntax** (`m_free[hash]`, `reference_token == "0"`). SPEC does not say whether these are edges.
