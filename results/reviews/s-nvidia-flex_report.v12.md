# Blind call-graph review: s-nvidia-flex (cpp), round 12

precision 46/50; census ≈98.5% (246 wrong of 16292 in-scope); recall: 0 missed of 40 real calls; 0 non-calls

## Scope
The tool JSON (`final14-A/s-nvidia-flex.v2.json`) has 26,521 edges. I judged the 16,292 edges whose `source_file` is C++ (`.cpp`, `.h`, `.inl`) across 191 files. None of them sit under test/, tests/, spec/, examples/ or docs/. Vendored code under `external/` is in scope, per Decisions 2026-11-09.

Excluded:
- 4,462 C edges (`external/glad/src/glad.c`).
- 5,767 JS edges (`doc/_static`, `doc/searchindex.js`).

The `.h` files under `external/nvapi/include/nvHLSLExtns*.h` contain HLSL. They are in scope by extension, and I judged them by the C++ rules.

In-scope split:

| | Count |
|---|---|
| **Confidence** | |
| high | 12,449 |
| medium | 2,699 |
| low | 1,063 |
| unknown | 81 |
| **call_type** | |
| direct | 8,563 |
| method | 3,357 |
| macro | 2,831 |
| constructor | 1,460 |
| callback | 81 |
| implicit | 0 |

Precision sample:
- Seed 12, quotas high 32 / medium 8 / low 5 / unknown 5.
- At most 3 edges per file, 33 files in all.
- Result: 41 correct, 5 spec gaps (counted as not wrong), 4 wrong.

Recall functions:
- `appGraphProfilerD3D12Begin` (demo/d3d12/appD3D12Ctx.cpp:1014–1046), 8 calls.
- `AABBTree::BuildRecursive` (core/aabbtree.cpp:316–368), 9 calls.
- `NvFlexExtCreateRigidFromMesh` (extensions/flexExtRigid.cpp:69–173), 23 calls.

I did not use the `measured_accuracy` field.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| external/nvapi/include/nvHLSLExtnsInternal.h:327 (sample) | `uint index = g_NvidiaExt.IncrementCounter();` | __NvAtomicOpFP16x2 → IncrementCounter, unknown, callback | `RWStructuredBuffer#IncrementCounter`, medium, method (`RWStructuredBuffer<NvShaderExtnStruct> g_NvidiaExt` is a file-scope declaration) | wrong callee | member call on a typed global emitted as a callback |
| external/nvapi/include/nvHLSLExtnsInternal.h:378 (sample) | `uint index = g_NvidiaExt.IncrementCounter();` | __NvAtomicOpFP16x2 → IncrementCounter, unknown, callback | `RWStructuredBuffer#IncrementCounter`, medium, method | wrong callee | same |
| external/nvapi/include/nvHLSLExtnsInternal.h:97 (sample) | `uav.Store(index, 0);` | __NvReferenceUAVForOp → Store, unknown, callback | `RWByteAddressBuffer#Store`, medium, method (parameter `RWByteAddressBuffer uav`) | wrong callee | typed parameter receiver emitted as a callback |
| external/nvapi/include/nvHLSLExtns.h:78 (sample) | `uint index = g_NvidiaExt.IncrementCounter();` | NvShflUp → IncrementCounter, unknown, callback | `RWStructuredBuffer#IncrementCounter`, medium, method | wrong callee | same |
| demo/opengl/shadersGL.cpp:2884 (sample) | `glVerify(glColor3fv(color));` | OGL_Renderer.DrawGpuMeshInstances → glColor3fv, high, macro | spec gap G1: `glColor3fv` is `#define glColor3fv glad_glColor3fv`, an object-like macro naming a function pointer | spec gap | object-like macro alias |
| demo/opengl/shadersGL.cpp:856 (sample) | `glEnable(GL_TEXTURE_2D);` | OGL_Renderer.ShadowApply → glEnable, high, macro | spec gap G1 | spec gap | object-like macro alias |
| demo/stb_truetype.h:104 (sample) | `glBindTexture(GL_TEXTURE_2D, ftex);` | my_stbtt_initfont → glBindTexture, high, macro | spec gap G2 (inside `#if 0`) and G1 | spec gap | dead preprocessor branch |
| core/vec2.h:85 (sample) | `{T s(1.0f/scale); …}` | XVector2#operator /= → T#<init>, low, constructor | spec gap G4 | spec gap | construction through a template type parameter |
| demo/d3d12/appD3D12Ctx.cpp:1020 (sample) | `timer.m_cpu.getDeltaTime();` (`auto& timer = p->m_timers[p->m_timersSize++];`) | appGraphProfilerD3D12Begin → m_cpu.getDeltaTime, low, method | spec gap G3 (`TimerCPU#getDeltaTime` high if `auto` takes the indexed element type) | spec gap | `auto` local bound to an index |
| demo/d3d12/fluidSmoothRenderPipelineD3D12.cpp:64 | `ranges[0].Init(D3D12_DESCRIPTOR_RANGE_TYPE_SRV, numSrvs, 0);` (`CD3DX12_DESCRIPTOR_RANGE ranges[2];`) | … → .Init, low, method | `CD3DX12_DESCRIPTOR_RANGE#Init`, high, method | wrong callee | index of a declared raw array not typed |
| demo/d3d11/fluidRenderD3D11.cpp:260 | `deviceContext->RSSetState(m_rasterizerState[params->renderMode][params->cullMode].Get());` | FluidRendererD3D11#drawThickness → .Get, low, method | `Microsoft.WRL.ComPtr#Get`, medium | wrong callee | same |
| demo/d3d12/appD3D12Ctx.cpp:600 | `context->m_commandAllocators[context->m_frameIndex]->Reset();` | AppGraphCtxFrameStartD3D12 → .Reset, low, method | `ID3D12CommandAllocator#Reset`, high (pure-virtual in scanned d3d12.h) | wrong callee | same |
| core/mesh.cpp:48 | `if (m_texcoords[0].size() > i)` (`std::vector<Vector2> m_texcoords[2];`) | Mesh#DuplicateVertex → .size, low, method | `std.vector#size`, medium | wrong callee | same |
| external/regal_static/include/GL/Regal.h:43681 | `REGAL_DECL EGLBoolean REGAL_CALL eglWaitGL(void);` | external/regal_static/include/GL/Regal → eglWaitGL, high, macro | no edge (declaration) | not a call | `(void)` prototype parsed as a call |
| external/SDL2-2.0.4/include/SDL_opengl.h:929 | `GLAPI void GLAPIENTRY glPopMatrix( void );` | …/SDL_opengl → glPopMatrix, high, macro | no edge | not a call | same |
| external/regal_shared/include/GL/Regal.h:40732 | `REGAL_DECL GLXFBConfigSGIX REGAL_CALL plugin_glXGetFBConfigFromVisualSGIX(Display *dpy, XVisualInfo *vis);` | …/Regal → plugin_glXGetFBConfigFromVisualSGIX, medium, direct | no edge | not a call | prototype after calling-convention macros |
| external/D3D11/include/D3DX10tex.h:754 | `D3DX10SHProjectCubeMap(` (previous line `HRESULT WINAPI`) | …/D3DX10tex → D3DX10SHProjectCubeMap, low, direct | no edge | not a call | multi-line prototype |
| demo/d3d11/appD3D11Ctx.h:45 | `AppGraphCtxD3D11();` | demo/d3d11/appD3D11Ctx → AppGraphCtxD3D11, low, direct | no edge (constructor declaration) | not a call | member declaration parsed as a call |
| demo/d3d12/imguiGraphD3D12.h:46 | `ImguiGraphDescD3D12() {}` | demo/d3d12/imguiGraphD3D12 → ImguiGraphDescD3D12, low, direct | no edge (constructor definition) | not a call | same |
| external/SDL2-2.0.4/include/SDL_stdinc.h:514 / 516 | `SDL_FORCE_INLINE void *SDL_memcpy4(SDL_OUT_BYTECAP(dwords*4) void *dst, …)` / `return SDL_memcpy(dst, src, dwords * 4);` | …/SDL_stdinc → SDL_memcpy4, low, direct; …/SDL_stdinc → SDL_memcpy | 514: no edge (definition head); 516: caller `SDL_memcpy4` | not a call / wrong caller | annotation macros in a parameter list break the definition |
| core/cloth.h:228 | `Edge& e1 = const_cast<Edge&>(*edges.insert(Edge(indices[i+0], indices[i+1])).first);` (`typedef std::set<Edge> EdgeSet;` in the function) | ClothMesh#<init> → EdgeSet#insert, medium | `std.set#insert`, medium | wrong callee | function-local typedef not expanded (open defect cpp/18) |
| demo/d3d12/meshRendererD3D12.cpp:206 | `alloc.init(PRIMITIVE_POINT);` (`typedef PointRenderAllocationD3D12 Alloc;` in the function) | FlexSample.MeshRendererD3D12#allocateTransitory → Alloc#init, medium | `FlexSample.PointRenderAllocationD3D12#init`, high | wrong callee | same (open defect cpp/18) |
| core/maths.h:254 | `CUDA_CALLABLE inline Plane(float x, float y, float z, float w) : Vec4(x, y, z, w) {}` | Plane#<init> → Vec4#<init>, medium, constructor | `XVector4#<init>`, high (`typedef XVector4<float> Vec4;`) | wrong callee | alias in a base initializer not expanded |
| external/D3D12/include/d3dx12.h:37 | `D3D12_RECT( o )` (`typedef RECT D3D12_RECT;`) | CD3DX12_RECT#<init> → D3D12_RECT#<init>, medium | `RECT#<init>`, medium | wrong callee | same |
| demo/main.cpp:2009 | `ControllerButtonEvent(e);` (block-scope `void ControllerButtonEvent(SDL_ControllerButtonEvent event);`, defined at main.cpp:2632) | UpdateFrame → ControllerButtonEvent, unknown, callback | `ControllerButtonEvent`, high, direct (line 2756, same callee, is high direct) | wrong callee / C2 | block-scope function declaration treated as a variable |
| demo/main.cpp:2586 | `setStateLeft(false);` (`extern void setStateLeft(bool bLeftDown);`; defined demo/imgui.cpp:177) | MouseFunc → setStateLeft, unknown, callback | `setStateLeft`, high, direct | wrong callee | same |
| demo/main.cpp:2637 | `InputKeyboardDown(GetKeyFromGameControllerButton(SDL_GameControllerButton(event.button)), 0, 0);` | ControllerButtonEvent → SDL_GameControllerButton#<init>, medium, constructor | no edge (functional cast to the scanned `typedef enum … SDL_GameControllerButton`) | not a call | cast as constructor |
| demo/stb_truetype.h:1052 | `v->x = (stbtt_vertex_type)(m * (mtx[0]*x + mtx[2]*y + mtx[4]));` | stbtt_GetGlyphShape → stbtt_vertex_type, low, direct | no edge (C cast; `#define stbtt_vertex_type short`) | not a call | cast as call |
| external/egl_setup/egl_setup.cpp:48 | `EGLConfig* configs = new EGLConfig[count];` | GetBestConfigMatch → EGLConfig#<init>, medium | no edge (`typedef void *EGLConfig;`) | not a call | array new of a pointer type |
| core/platform.cpp:275 | `return string(path, last+1);` (file has `using namespace std;`) | StripFilename → string, low, direct | `std.string#<init>`, medium, constructor | wrong callee | functional construction treated as a bare call |
| external/D3D11/include/D3DX11core.h:122 | `#define MAKE_D3DSTATUS( code )  MAKE_HRESULT( 0, _FACD3D, code )` | MAKE_D3DHRESULT → MAKE_D3DSTATUS, high, macro (+ MAKE_HRESULT) | no edge (a `#define` is a declaration; the tool emits none for other `#define` bodies) | not a call / wrong caller | `#define` line parsed as a function body |
| external/D3D11/include/D3DX10core.h:343 | `HRESULT WINAPI_INLINE PreloadText(LPCWSTR pString, INT Count) { return PreloadTextW(pString, Count); }` | STDMETHOD_ → PreloadTextW, low | caller `PreloadText` (as the tool gives for line 346) | wrong caller | `STDMETHOD_(…)` taken as a function |
| demo/imgui.h:37 | `return (r) \| (g << 8) \| (b << 16) \| (a << 24);` | demo/imgui → return, low, direct | no edge | not a call | keyword as call |
| core/aabbtree.cpp:39 | `_declspec (thread) uint32_t AABBTree::s_traceDepth;` | core/aabbtree → _declspec, low, direct | no edge | not a call | storage-class keyword as call |
| core/platform.h:178 | `else` (after the ObjC line `std::string s = [fullPath cStringUsingEncoding:1];`) | ExpandPath → else#<init>, medium, constructor | no edge | not a call | keyword as constructor |
| external/D3D12/include/pix3.h:124 | `const UINT PIX_COLOR_DEFAULT = PIX_COLOR_INDEX(0);` (`inline UINT PIX_COLOR_INDEX(BYTE i) { return i; }`) | …/pix3 → PIX_COLOR_INDEX, high, macro | `PIX_COLOR_INDEX`, high, direct | wrong call_type | function tagged as macro |
| demo/imgui.h:52 | `bool imguiItem(const char* text, bool enabled = true, unsigned int color = imguiRGBA(255, 255, 255, 200));` | demo/imgui → imguiRGBA, low, direct | callee `imguiRGBA` high (defined imgui.h:35; the 39 other edges to it are high); the caller is spec gap G7 | wrong confidence | default argument in a declaration |

## Systematic patterns (scripted, `s-nvidia-flex_r12_census.py`; union 246 wrong edges)
1. **Declaration or definition heads emitted as calls: 78.**
   - 72 are `(void)` prototypes after a return type and a calling-convention macro: `REGAL_DECL … REGAL_CALL f(void);` in both Regal.h copies (60), and `GLAPI void GLAPIENTRY f( void );` in SDL_opengl.h (12).
   - The rest: the SDL_memcpy4 definition head, 2 multi-line `HRESULT WINAPI\nD3DX1xSHProjectCubeMap(` prototypes, and 3 in-class constructor/destructor declarations or definitions.
   - Tags: 42 high macro, 30 medium direct, 6 low direct.
   - Checked by hand: Regal.h:43681, SDL_opengl.h:929, D3DX10tex.h:754, appD3D11Ctx.h:45/46, imguiGraphD3D12.h:46.
2. **HLSL member calls emitted as callback/unknown: 59.** These are `g_NvidiaExt.IncrementCounter()` (58) and `uav.Store(...)` (1) in nvHLSLExtns.h and nvHLSLExtnsInternal.h. Both receivers have declared types in the file.
3. **Raw-array index receivers left as `.m` low: 49.**

   | Arrays | Element type | Edges |
   |---|---|---|
   | `ranges[]` / `params[]` | `CD3DX12_DESCRIPTOR_RANGE` / `CD3DX12_ROOT_PARAMETER` | 16 |
   | `m_anisotropiesArr[]` / `m_rasterizerState[][]` | `ComPtr` | 17 |
   | `m_backBuffers[]`, `m_renderTargetResources[]`, `m_renderTargets[]` | `Dx12Resource` / `Dx12Resource*` | 8 |
   | `m_commandAllocators[]` | `ID3D12CommandAllocator*` | 1 |
   | `m_texcoords[2]` | `std::vector<Vector2>` | 7 |

   Under "Typed call results" an index receiver is typed when declarations fix its type. Checked by hand: fluidSmoothRenderPipelineD3D12.cpp:49/64, meshRenderD3D11.h:70, appD3D12Ctx.h:71–83, mesh.h:52.
4. **Typedef aliases not expanded: 20.**
   - 16 are function-local typedefs, matching open defect cpp/18: `Alloc` (6), `EdgeSet` (5), `VertexMap` (3), `TriMap` (2).
   - 3 are `Vec4#<init>` in `Plane`'s base initializers (`typedef XVector4<float> Vec4`), which should be `XVector4#<init>`, high.
   - 1 is `D3D12_RECT#<init>`, which should be `RECT#<init>`.
5. **Casts emitted as calls: 10.**
   - `SDL_GameControllerButton(event.button)`, a scanned enum typedef (4).
   - `(stbtt_vertex_type)(…)`, a `#define` for `short` (4).
   - `stbtt_int32(…)`, a typedef of `signed int` (1).
   - `new EGLConfig[count]`, a typedef of `void*` (1).
6. **`string(...)` construction emitted as bare `string`, low, direct: 10.** These are in core/platform.cpp (8; the file has `using namespace std;`, so `std.string#<init>`) and demo/helpers.h (2; `string#<init>`, constructor). Elsewhere the tool emits `std.string#<init>` for the same construct.
7. **Misparse callers in D3DX headers: 9.**
   - 5 edges in D3DX11core.h:121–125, from `#define` lines given caller `MAKE_D3DHRESULT`. One of them is the definition of `MAKE_D3DSTATUS`, emitted as a call to it.
   - 4 edges in D3DX10core.h with caller `STDMETHOD_`.
8. **Calls of block-scope-declared functions emitted as callback/unknown: 5.** These are `ControllerButtonEvent` ×4 and `setStateLeft` ×1 in demo/main.cpp. This also breaks C2: the same function is high direct at main.cpp:2756.
9. **Misc: 4.**
   - `else#<init>` (platform.h:178).
   - `PIX_COLOR_INDEX` tagged macro although it is an inline function.
   - `imguiRGBA` low at imgui.h:52.
   - `SDL_memcpy` at SDL_stdinc.h:516 with the file as caller.
10. **Keywords emitted as calls: 2.** `return` at imgui.h:37 and `_declspec` at aabbtree.cpp:39.

Census precision is 1 − 246/16,292 ≈ 98.49%.

## Missed-call patterns (recall)
- None of the 40 real calls in the three recall functions was missed, and no edge there was a non-call.
- `HeapPropsReadback readbackProps;` (appD3D12Ctx.cpp:1033) runs a user-written default constructor and gets no edge. I treat this as spec gap G6, not a miss.
- Seen while looking, not counted: the Objective-C message sends in core/platform.h's `#if PLATFORM_IOS` block (lines 170–175) get no edges.
- Not met in the recall functions: the open-defect constructs that CAPABILITIES lists as misses (cpp/01, 03, 06, 11, 13).

## Spec gaps (not counted as wrong)
- **G1, object-like macro aliases called like functions: 893 edges.** That is 936 edges whose callee is only an object-like `#define`, minus 43 already counted wrong. Example: `glVerify(glColor3fv(color));` with `#define glColor3fv glad_glColor3fv`, where `glad_glColor3fv` is a `PFNGLCOLOR3FVPROC` variable. Most are in demo/opengl (845), plus egl_setup, the Regal headers, and `snprintf`/`vsnprintf` aliases. The tool tags them macro/high. Open question: SPEC defines `macro` only for function-like macros. When an object-like macro names a function, or a function-pointer variable, and is written with call parentheses, which edge is correct? Is it a macro edge to the macro name, a direct edge to the expansion, or a callback through the pointer it names?
- **G2, code inside `#if 0`: 59 edges.** Most are in demo/stb_truetype.h (39), for example `glBindTexture(GL_TEXTURE_2D, ftex);` inside the `#if 0` sample program. The rest are in NvCoDx12Handle.h, benchmark.h, demoContextD3D11.cpp and appD3D12Ctx.cpp. Open question: does SPEC count calls written in preprocessor branches that can never compile?
- **G3, `auto` locals bound to a field or an index: 20 edges.** Examples: `auto deviceContext = p->m_context->m_deviceContext; … deviceContext->GetData(...)` and `auto& timer = p->m_timers[...]; timer.m_cpu.getDeltaTime();`. Open question: the let-bound ruling covers locals bound to a call result. Does an `auto` local initialized from a declared field, or from an index, take that declared type?
- **G4, construction or casts through a template type parameter: 13 edges.** These are `T s(1.0f/scale);` / `new(ptr + i) T;` emitted as `T#<init>`, constructor (10), and `T(4.0)` / `T()` emitted as bare `T`, direct (3). Open question: when `T` may be a scalar, is `T(x)` a constructor call (`T#<init>`, low), a cast with no edge, or something else? The two ID/call_type forms the tool emits also differ.
- **G5, cast-expression receivers: 2 edges.** These are `((MovingFrame&)(*frame)).Move(...)` and `static_cast< const CD3DX12_HEAP_PROPERTIES* >( &Properties )->IsCPUAccessible()`, both left as `.m` low. Open question: "Typed call results" names call results, indexes and literals. Does a cast expression's written target type type its receiver?
- **G6, default-initialized declarations of scanned classes with a user-written default constructor: up to ≈190 written declarations** (script upper bound; it includes member-field declarations). Examples: `HeapPropsReadback readbackProps;` and `Vec3 meshShift;`. None gets an edge, while `std::vector<uint32_t> voxels(n)` does. Open question: is a declaration without an initializer, which runs a constructor, a `Type#<init>` call?
- **G7, calls in default arguments of declarations: 1 edge** (`unsigned int color = imguiRGBA(255, 255, 255, 200)` at imgui.h:52). Open question: who is the caller of a call in a default argument, which runs at each call site? The file, the declared function, or each caller?
- **G8, repeated calls of one callee on one line: 135 single-edge groups** where the callee's name is written more than once on the line, against 53 groups the tool emits more than once. Examples: `std::max(std::max(edges.x, edges.y), edges.z)` and `Vec3 meshLower(FLT_MAX), meshUpper(-FLT_MAX);` each get one edge. Open question: does each written invocation need its own edge, or is one edge per (caller, callee, line) enough?

Helper scripts are in the fanout folder with the prefix `s-nvidia-flex_r12_`: scope, sample, src, ctx, recall, census, arrayidx, proto, proto2, ctordecl, classes, enumcast, define, objmacro, if0, auto, alias, defs, defaultinit, dupline.
