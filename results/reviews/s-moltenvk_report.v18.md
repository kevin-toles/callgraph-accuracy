# s-moltenvk (objc): blind call-graph review, round 18

precision 50/50; census ≈98.41% (178 wrong of 11213 in-scope); recall: 1 missed of 31 real calls; 0 non-calls

## Scope
The tool output has 11,653 edges. In scope are 11,213 edges whose `source_file` is `.mm` (10,401), `.h` (742) or `.m` (70), across 93 files. No path has a test/, tests/, spec/, examples/ or docs/ segment. I treated headers as in-language because every `.h` here is compiled into the ObjC/ObjC++ targets. Out of scope: `.cpp` (401), `.swift` (22), `.py` (11) and `.c` (6).

- Confidence split: high 8654, medium 1587, low 946, unknown 26.
- call_type split: method 6642, macro 2299, direct 1858, constructor 388, callback 26.

I ignored the `measured_accuracy` field. Helper scripts are `s-moltenvk_r18_*.py` in the fanout folder.

**Precision sample.** Seed 18, stratified high 33 / medium 7 / low 5 / unknown 5, over 18 files. All 50 have a real call and the correct caller, callee, tier, call_type and line. Three of them are spec gaps, not wrong:
- #41: the `layout->argBufMode()` receiver is an `auto*` taken from a field of a cast-typed `auto*`.
- #45: `[[self alloc] initWithBlock:…]` in a class method.
- #48: a caller in `namespace SPIRV_CROSS_NAMESPACE`.

**Recall.** I checked three functions:
- `MVKDeviceMemory::pullFromDevice` (MVKDeviceMemory.mm:101): 9 calls, 9 found.
- `mvkUpdateDescriptorSetWithTemplate` (MVKDescriptorSet.mm:1797): 9 calls, 9 found.
- `MVKSwapchain::getRefreshCycleDuration` (MVKSwapchain.mm:188): 13 calls, 12 found.

The one miss is the second `_device->getConfigurationResult()` on line 189. Same-line repeats are collapsed (see the recall section).

## Mismatch table
| file:line | source line | tool said (caller → callee, conf, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| Commands/MVKCmdDraw.mm:275 | `atIndex: cmdEncoder->getDevice()->getMetalBufferIndexForVertexAttributeBinding(kMVKTessCtlInputBufferBinding)];` | MVKCmdDraw#encode → `.getMetalBufferIndexForVertexAttributeBinding`, low, method | `MVKDevice#getMetalBufferIndexForVertexAttributeBinding`, high (getDevice() is declared `MVKDevice*` on MVKDeviceTrackingMixin) | wrong callee | typed call result (inherited mixin getter) not propagated |
| Commands/MVKCommandBuffer.h:108 | `MVKInstance* getInstance() override { return _device->getInstance(); }` | MVKCommandBuffer#getInstance → `_device.getInstance`, low | `MVKDevice#getInstance`, high (field `MVKDevice* _device`) | wrong callee | inherited field type not used |
| Commands/MVKCommandEncoderState.mm:405 | `binder.setBytes(encoder, data, size, idx);` | bindImmediateData → `binder.setBytes`, low | `MVKResourceBinder#setBytes`, high (param `const MVKResourceBinder& RESTRICT binder`) | wrong callee | `RESTRICT` macro between type and name drops the parameter type |
| GPUObjects/MVKPipeline.mm:518 | `vtxPLDesc.computeFunction = pVtxFunctions[0].getMTLFunction();` | → `.getMTLFunction`, low | `MVKMTLFunction#getMTLFunction`, high (param `MVKMTLFunction* pVtxFunctions`) | wrong callee | index of a declared pointer not typed |
| GPUObjects/MVKPipeline.h:277 | `…_stageResources[kMVKShaderStageVertex].implicitBuffers.needed.has(MVKImplicitBuffer::DrawId); }` | → `needed.has`, low | `MVKFlagList#has`, high (`typedef MVKFlagList<MVKImplicitBuffer> MVKImplicitBufferList`) | wrong callee | typedef/using alias not expanded (open defect objc/03) |
| GPUObjects/MVKDescriptorSet.mm:935 | `[enc setBuffer:buf offset:static_cast<NSUInteger>(offset) atIndex:base + index];` | → `enc.setBuffer:offset:atIndex:`, low | `MTLArgumentEncoder#setBuffer:offset:atIndex:`, medium (field `id<MTLArgumentEncoder> enc;`) | wrong callee | id<P> field not used (open defect objc/07) |
| GPUObjects/MVKDevice.mm:3816 | `_buffer = [device newBufferWithLength:_halfSize * 2 options:options];` | → `device.newBufferWithLength:options:`, low | `MTLDevice#newBufferWithLength:options:`, medium (param `id<MTLDevice> device`) | wrong callee | id<P> parameter in a C++ constructor not used |
| Commands/MVKCmdTransfer.mm:1649 | `id<MTLRenderCommandEncoder> mtlRendEnc = [cmdEncoder->_mtlCmdBuffer renderCommandEncoderWithDescriptor: mtlRPDesc];` | → `_mtlCmdBuffer.renderCommandEncoderWithDescriptor:`, low | `MTLCommandBuffer#renderCommandEncoderWithDescriptor:`, medium | wrong callee | typed field chain into a message receiver |
| Demos/Cube/iOS/DemoViewController.m:51 | `[_displayLink setFrameInterval: 60 / fps];` | → `_displayLink.setFrameInterval:`, low | `CADisplayLink#setFrameInterval:`, medium (ivar `CADisplayLink* _displayLink`) | wrong callee | @implementation ivar type not used |
| GPUObjects/MVKSwapchain.mm:301 | `[mtlLayer setNeedsDisplay];` (line 299: `auto* mtlLayer = getCAMetalLayer();`) | MVKSwapchain#setLayerNeedsDisplay → `mtlLayer.setNeedsDisplay`, low | `CAMetalLayer#setNeedsDisplay`, medium (let-bound call result, declared `CAMetalLayer* getCAMetalLayer()`) | wrong callee | let-bound declared return type not applied |
| GPUObjects/MVKSync.h:564 | `MVKMetalCompiler(MVKVulkanAPIDeviceObject* owner) : MVKBaseDeviceObject(owner->getDevice()), _owner(owner) {}` | → `MVKVulkanAPIDeviceObject#getDevice`, medium | `MVKDeviceTrackingMixin#getDevice`, high | wrong callee + wrong confidence | ID invented on subclass (C2); tier medium for a scanned definition |
| Utility/MVKBaseObject.h:225 | `return mvkObj ? mvkObj->getMVKConfig() : getGlobalMVKConfig();` | → `MVKBaseObject#getMVKConfig`, medium | same ID, high | wrong confidence | scanned definition reported medium in headers |
| Commands/MVKMTLResourceBindings.h:93 | `MVKPipelineBarrier(const VkMemoryBarrier2& vkBarrier) :` | MoltenVK/MoltenVK/Commands/MVKMTLResourceBindings → `MVKPipelineBarrier`, low, direct | no edge (constructor definition head inside `typedef struct MVKPipelineBarrier {…}`) | not a call | `typedef struct` body not recognised as a type |
| Commands/MVKCommandResourceFactory.h:206 | `} __attribute__((aligned(sizeof(uint64_t)))) MVKImageDescriptorData;` | file → `aligned`, low, direct | no edge | not a call | attribute parsed as call |
| Commands/MVKCommandPool.mm:103 | `_commandBufferPool(device, usePooling),` | MoltenVK/MoltenVK/Commands/MVKCommandPool → `_commandBufferPool`, low, direct | caller `MVKCommandPool#<init>` (member construction) | wrong caller | ctor init list split by `#include "MVKCommandTypePools.def"` |
| Common/MVKStrings.h:92 | `setg(p, p, p + n);` | mvk.membuf#<init> → `setg`, low, direct | `mvk.membuf#setg`, medium, method (inherited from external std::streambuf) | wrong callee | bare inherited external member |
| Commands/MVKCommandBuffer.h:177 | `VkCommandBuffer getVkCommandBuffer() { return (VkCommandBuffer)getVkHandle(); }` | → `getVkHandle`, low, direct | scanned base's `#getVkHandle`, high, method | wrong callee | bare inherited in-scan member missed |
| GPUObjects/MVKImage.mm:744 | `auto xfrBuffer = unique_ptr<char[]>(new char[rgnSizeInBytes]);` | → `unique_ptr`, low, direct | `std.unique_ptr#<init>`, medium, constructor | wrong callee | functional-cast construction treated as a bare call |
| GPUObjects/MVKDescriptorSet.mm:1803 | `if (layout->argBufMode() == MVKArgumentBufferMode::ArgEncoder) {` | → `layout.argBufMode`, low | — | spec gap | `auto* layout = dstSet->layout;` with `auto* dstSet = reinterpret_cast<MVKDescriptorSet*>(set);` |
| Utility/MVKBlockObserver.m:45 | `return [[self alloc] initWithBlock: block forObject: object atKeyPath: keyPath];` | → `.initWithBlock:forObject:atKeyPath:`, low | — | spec gap | `[[self alloc] init…]` in a class method |
| GPUObjects/MVKPipeline.mm:2862 | `archive(rb.stage,` | SPIRV_CROSS_NAMESPACE.serialize → archive, unknown, callback | — | spec gap | namespace name is an out-of-scan macro |
| Swapchain, line 189 (recall) | `if (_device->getConfigurationResult() != VK_SUCCESS) { return _device->getConfigurationResult(); }` | one edge | two edges | missed call | same caller/callee/line collapsed |

## Systematic patterns (scripted counts, union 178, no overlaps)
1. **P1: typed C++ receiver not used (58).** These receivers have a declared type that the tool does not use:
   - an inherited field (`_device->`);
   - a parameter whose declaration has the `RESTRICT` macro (7);
   - an index of a declared raw pointer or array (`pVtxFunctions[0].`, `descriptorSetResourceUse[i].`);
   - a call-result chain through a scanned getter with a declared return type, mostly the mixin getters `getDevice()`, `getPhysicalDevice()` and `getPixelFormats()`.

   The calls are left as `.m` or `recv.m` low. Script: `s-moltenvk_r18_resolve.py` (RESOLVABLE bucket), validated by hand on MVKCmdDraw.mm:275, MVKCommandEncoderState.mm:405/567, MVKPipeline.mm:518 and MVKCommandBuffer.mm:197.
2. **P3: ObjC receiver typed `id<P>` or `Class*` by a declaration but left low (56).** Sources of the type:
   - C++ struct fields: `enc`, 9;
   - parameters: `mtlDev` / `device` / `mtlFunc` / `mtlDevice`, 11;
   - ivars and fields: `_residencySet`, `_displayLink`, `_mtlBuffer`, `_mtlTexture`, `_mtlLibrary`;
   - field chains: `cmdEncoder->_mtlCmdBuffer`, `mvkEncoder._mtlRenderEncoder`, `other._mtlFunction`, `other._debugName`;
   - `auto` locals bound to a scanned call returning `id<P>` or `CAMetalLayer*`.

   This includes open defect objc/07. Script: `s-moltenvk_r18_census.py`. Each receiver's declared type was checked by grep.
3. **P4: medium tier for a method or constructor defined in the scan (41).** These are mostly calls inside header inline bodies. Examples: `MVKSemaphoreImpl#wait`, `MVKVulkanAPIDeviceObject#<init>` (6), `MVKExtensionList#isEnabled` (4). In three of them the ID is also put on the subclass instead of the defining base (C2). Script: `s-moltenvk_r18_c2.py`.
4. **P2: typedef/`using` alias of a scanned class not expanded (9).** `MVKImplicitBufferList` and `MVKRenderStateFlags` both alias `MVKFlagList`. Open defect objc/03.
5. **P5: not a call (8).** Six constructor definition heads inside `typedef struct MVKPipelineBarrier {…}`, plus two `__attribute__((aligned(…)))`.
6. **P7: bare C++ member or constructor call left as a low bare name (5).** `getVkHandle` (2, in-scan base), `setg`/`setp` (2, std::streambuf base), `unique_ptr<char[]>(…)` (1).
7. **P6: wrong caller (1).** The constructor init list at MVKCommandPool.mm:103 is split by `#include`, and the tool gives the file as caller.

## Missed-call patterns (recall)
- **Repeated calls on one line are collapsed.** When a function calls the same callee twice on one line, the tool emits one edge. Examples: `supportsGPUFam(Mac2, …) || supportsGPUFam(MacCatalyst2, …)`, `MTLSizeMake(1,1,1) … MTLSizeMake(1,1,1)`, the `getConfigurationResult` guard idiom. The script counts about 108 missing occurrences on 105 lines (`s-moltenvk_r18_dupline.py`; a few may be definition-head false positives). The three recall functions show 1 such miss.
- No missed calls of any other kind in the three recall functions.

## Spec gaps (counted separately, not wrong)
- **SG6 (504): objc/17, out-of-scan C functions and macros.** Examples: `memcpy`, `MTLSizeMake` (69), `NSSwapHostIntToBig`, `demo_draw` (defined in a cube.c outside the scan) are emitted direct/low. Out-of-scan macros `assert` (134), `va_start`, `MIN` and `CFSTR` are emitted macro/medium, and `VK_VERSION_MAJOR` is emitted direct. Open question (CAPABILITIES objc/17): is the tier low or medium, and is the call_type macro when the `#define` is not visible?
- **SG1 (80): C++ `auto` deduced from a non-call initializer, and cast receivers.** Examples: `auto* mvkImg = (MVKImage*)pInfo->image;`, `auto* image = _imageView->_image;`, `((MVKFence*)pFences[i])->reset();`, `auto enc = static_cast<id<MVKMTLRenderCommandEncoder>>(encoder);`. SPEC types let-bound locals only from call results, and lists computed receivers as call result, index, literal or `super`. Open question: does an `auto` bound to a cast or to a field access, or a cast expression used as a receiver, give its written type?
- **SG2 (32): fields whose type is a `std::conditional_t` alias.** Example: `MVKStaticBitSet<kMVKMaxBufferCount> buffers;` with `using MVKStaticBitSet = std::conditional_t<(Bits > 32), MVKLargeStaticBitSet<Bits>, MVKSmallStaticBitSet<…>>`, in calls such as `exists.buffers.set(index)`. Open question: does alias expansion cover a conditional alias that picks its target from a template constant?
- **SG5 (22): bare call written in a macro argument where the expansion supplies a receiver.** Example: `MVK_ENC_REZ_ACCESS(_cmdClearDepthOnlyDepthStencilState, newMTLDepthStencilState(useDepth, useStencil));`, where the macro body has `rez = _commandPool->getDevice()->getCommandResourceFactory()->rezFactoryFunc;`. Open question: is the argument call judged as written (a bare name) or as expanded (a member call)?
- **SG7 (4): member functions generated by an X-macro `#include`.** `getEnabledPipelineCreationCacheControlFeatures()` is defined through `#define MVK_DEVICE_FEATURE(structName, …) … getEnabled##structName##Features() {…}` followed by `#include "MVKDeviceFeatureStructs.def"`. Open question (like c/12): does the 2026-11-12 generated-functions ruling apply when the invocations come from an included `.def` list?
- **SG3 (4): namespace named by an out-of-scan macro.** `namespace SPIRV_CROSS_NAMESPACE {` gives callers `SPIRV_CROSS_NAMESPACE.serialize`. Open question: is the caller's qualifier the macro name as written or its (unknown) expansion?
- **SG8 (2): namespace-scope lambda variable.** `auto addSat = [](uint32_t a, uint32_t b) {…};` at SPIRVReflection.h:234, called as `addSat(loc, 1)`. Open question: the named-nested-function rule covers locals; is a namespace-scope `auto f = [..]` a named function, a callback, or a bare name?
- **SG4 (2): `[[self alloc] initWith…]` in a class method.** `return [[self alloc] initWithBlock: block];` Open question: does the `[[T alloc] init…]` ruling apply when T is written `self` (the class object)?

Not counted as wrong (my reading):
- `operator[]`, `back()` and range-for over template containers (`MVKSmallVector<T>`, `MVKArrayRef<T>`), whose element type comes only through the template parameter, stay low under "a generic return type leaves the call a low guess".
- Receivers typed only by SDK or Vulkan-header declarations (`pMTLBuffInfo->mtlBuffer`, `[[NSProcessInfo processInfo] …]`) stay low under "typing reaches only declarations in the scan".
