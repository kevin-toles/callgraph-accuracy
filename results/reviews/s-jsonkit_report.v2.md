# s-jsonkit (objc) blind call-graph review, v2

precision 49/50; census ≈99.8% (2 wrong of 965 in-scope); recall: 0 missed of 33 real calls; 0 non-calls

## Scope
The tool output holds 965 edges, all with `source_file` = `JSONKit.m`. That is the repo's only ObjC implementation file; `JSONKit.h` has declarations only and no edges. No path has a test/tests/spec/examples/docs segment, so all 965 edges are in scope.
- By confidence: high 531, medium 210, low 224, unknown 4.
- By call_type: macro 356 (high 261, medium 95), direct 380 (high 220, low 160), method 225 (high 50, medium 115, low 60), callback 4 (unknown).

Precision sample: seed 20261109, stratified high 26 / medium 10 / low 10 / unknown 4. It covers 1 file because only one file has edges (the "all files if fewer" case). The script is `s-jsonkit_r1_sample.py`.

Recall functions: `jk_error` (JSONKit.m:1119), `JKDictionary#setObject:forKey:` (JSONKit.m:1069) and `JSONDecoder#initWithParseOptions:` (JSONKit.m:2095). They come from the same file because only one file exists.

Other scripted checks:
- `s-jsonkit_r1_ccalls.py` compares every `name(` token, with comments and strings stripped, against the direct/macro/callback edges on the same line. Result: no C or macro call is missing from a line, and every extra edge is a function-pointer callback.
- `s-jsonkit_r1_msgs.py` compares bracket message sends with method edges per line.
- `s-jsonkit_r1_tiers.py` checks that every direct callee defined in the scan is high and every other one is low, and that every macro `#define`d in the scan is high and every other one is medium. 0 deviations.
- `s-jsonkit_r1_census.py` counts the patterns below.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| JSONKit.m:2831 (sample #38) | `return([[[[self alloc] init] autorelease] serializeObject:object ...]);` | `JKSerializer#serializeObject:options:encodeOption:block:delegate:selector:error:` → `.init`, low, method | `JKSerializer#init`, medium (in the class method `self` is JKSerializer and the tool itself emits `JKSerializer#alloc`; per the ObjC decision `[[T alloc] init…]` the init runs on a T; JKSerializer defines no `init`, and it is inherited from NSObject outside the scan) | wrong callee / wrong confidence | `[[self alloc] init…]` in a class method is not treated as `[[T alloc] init…]` |
| JSONKit.m:2087 | `return([[[self alloc] initWithParseOptions:parseOptionFlags] autorelease]);` | `JSONDecoder#decoderWithParseOptions:` → `.initWithParseOptions:`, low, method | `JSONDecoder#initWithParseOptions:`, high (defined at JSONKit.m:2095) | wrong callee / wrong confidence | same as above |
| JSONKit.m:2340 | `returnObject = [(decoder = [JSONDecoder decoderWithParseOptions:parseOptionFlags]) objectWithUTF8String:... length:... error:error];` | `_NSStringObjectFromJSONString` → `.objectWithUTF8String:length:error:`, low | the receiver is an assignment to the local `JSONDecoder *decoder` (L2328); the spec does not say whether an assignment expression carries the declared type | spec gap | assignment-expression receiver |
| JSONKit.m:810 | `[(NSArray *)[NSArray allocWithZone:zone] initWithObjects:objects count:count]` | `JKArray#copyWithZone:` → `.initWithObjects:count:`, low | the spec decides neither cast-typed receivers nor `allocWithZone:` as `alloc`. The tool does resolve the uncast `[[NSDictionary allocWithZone:zone] initWithDictionary:self]` at L1098 to `NSDictionary#initWithDictionary:` | spec gap | cast before the receiver |
| JSONKit.m:853 | `NSUInteger count = [(NSDictionary *)collection count], atObject = 0UL;` | `JKDictionaryEnumerator#allObjects` → `.count`, low | `collection` is an `id` ivar cast to `NSDictionary *`; the spec does not decide cast typing | spec gap | cast-typed receiver |
| JSONKit.m:1132–1137 | `#if 0` … `if(jk_parse_is_newline(parseState, atCharacterPtr))` … `[NSString stringWithFormat:...]` | 7 edges from `jk_error` (JK_END_STRING_PTR ×2, jk_parse_is_newline, NSString#alloc, NSString#initWithBytes:length:encoding:, .autorelease, NSString#stringWithFormat:) | this code is disabled by `#if 0` (L1127–1139); the spec has no rule for preprocessor-dead code | spec gap | `#if 0` region scanned |
| JSONKit.m:2758 | `isfinite(...)` | → `isfinite`, low, direct | `isfinite` is a function-like macro in `<math.h>`, which is outside the scan; nothing in the scan marks it as a macro | spec gap | system macro not knowable from scanned source |

No other sample edge was wrong. Every sampled caller, callee, tier, call_type and line matched the source and spec, including:
- function-pointer struct fields (`parseState->objCImpCache.NSNumberAlloc(...)`, `encodeState->classFormatterBlock(object)`) as callback/unknown under the field name;
- `[super dealloc]` / `[super init]` as `.dealloc` / `.init` low (the superclass is outside the scan);
- `id`-typed receivers (`anObject.retain`, `object.isKindOfClass:`) as low;
- system C functions (`CFRelease`, `NSStringFromClass`) as low, as a bare name not found in the scan;
- Foundation macros (`NSCParameterAssert`, `va_start`) as macro medium.

## Systematic patterns (wrong), by scripted count
1. **`[[self alloc] init…]` in a class method left as a computed-receiver guess**: 2 edges (L2087 `.initWithParseOptions:`, L2831 `.init`). Script: `.init*` callee on a line matching `\[\[self alloc\]\s*init`. Both were checked by hand. In both, the tool resolved `[self alloc]` to `T#alloc` on the same line but did not carry T into the init.

Union of wrong edges: 2. Census precision = 1 − 2/965 = 99.79%.

## Missed-call patterns (recall)
- Recall functions: 33 real calls; all 33 are present with the correct callee, tier and line.
  - `jk_error`: 10 live calls.
  - `JKDictionary#setObject:forKey:`: 17 calls.
  - `JSONDecoder#initWithParseOptions:`: 6 calls.
- 0 missed calls.
- 0 non-calls, apart from the 7 `#if 0` edges in `jk_error` listed under spec gaps.
- The whole-file token scan found no line where a C function or macro call has no edge.

## Spec gaps (not counted as wrong)
1. **Same callee called several times on one line is reported once**: 85 call occurrences collapsed on 56 lines.
   - 82 are C/macro occurrences, e.g. L1810 has five `JK_EXPECT_T(`.
   - 3 are message sends: the second `[self class]` at L672 and L887, and the second `isKindOfClass:` at L2873.
   - The spec does not say whether repeated identical calls on one line need separate edges.
2. **`#if 0` dead code produces edges**: 7 (L1132–1137 in `jk_error`).
3. **Assignment-expression receiver** `[(decoder = …) sel]` where `decoder` is declared `JSONDecoder *`: 4 (L2340, L2341, L2398, L2416). Left as `.sel` low. If the assignment counted as typed, the four would be `JSONDecoder#objectWithUTF8String:length:error:`, `JSONDecoder#mutableObjectWithUTF8String:length:error:`, `JSONDecoder#objectWithData:error:` and `JSONDecoder#mutableObjectWithData:error:`, all high.
4. **Cast-typed receivers** `[(NSArray *)… sel]`: 3 (L810, L816, L853). L810/L816 also involve `allocWithZone:` rather than `alloc`.
5. **System function-like macro emitted as direct**: 1 (`isfinite`, L2758).
