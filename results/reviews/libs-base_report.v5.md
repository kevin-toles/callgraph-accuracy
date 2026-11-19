# libs-base (objc) call-graph review, v5

**precision 48/50; census ≈98.66% (806 wrong of 60,030 in-scope); recall: 0 missed of 83 real calls; 1 non-call**

### Scope
- **In-scope edges:** 60,030 edges in `.m` files outside test/example/docs directories, out of 95,614 in the whole file. v3a had 60,119.
- **Confidence mix:** high 46,674, low 11,567, unknown 918, medium 871. In v3a it was high 30,184, low 27,272, medium 1,745, unknown 918.
- **Call types:** method 36,327, direct 13,900, macro 8,885, callback 918.
- **Decision A applies to Objective-C (accepted).** A receiver declared with a class pointer gives `Class#selector`, resolved to the defining ancestor in the scan. `id`, `Class` and `instancetype` stay `recv.sel` low.

### Where the 89 missing in-scope edges went
- **87 same-line merges.** Two calls on one line with different receivers now resolve to the same callee, so they collapse into one edge. Example: `[name length] + [value length]` becomes a single `NSString#length`. This is the same-line collapse already listed as a spec gap.
- **2 dropped macro edges.** These are `GS_GENERIC_CLASS(...)` invocations in declarations.
- **14 relocated edges.** These NSPredicate.m edges moved to the wrong line (pattern 12).

### Typed-receiver change (decision A), verified
- I classified every message whose receiver is a plain identifier, `self->x` or a class name: 24,857 edges in all.
- **Class-pointer-typed receivers:**
  - 17,442 of 17,537 match the declared type and the defining ancestor, with the correct confidence.
  - 69 are left `recv.sel` low, 24 have the right callee but the wrong confidence, and 2 have the wrong type.
  - After removing script false positives, these residuals become patterns 5, 10, 15, 16 and 17 and the `GS_FOR_IN` spec gap.
- **I hand-checked 36 edges that differ from v3a** (`random.seed(5005)`). All 36 are correct. Specifically:
  - **Ivars inside `#if GS_EXPOSE`:** `_textChars`, `setArrayInvocation`, `_module`, `request`, `_accesses`, `_urlString`, `actions`.
  - **Two classes in one file with same-named ivars:** `setSetInvocation`, resolved to the caller's own class.
  - **Locals shadowing parameters:** NSFileManager.m:1054 `NSString *path` inside the `if` block.
  - **Defining-ancestor resolution:**
    - `NSMutableString` → `NSString#length` and `NSString#dataUsingEncoding:`
    - `NSMutableArray` → `NSArray#objectAtIndex:`
    - `NSMutableData` → `NSData#length`
    - `NSInputStream` → `NSStream#close` (unix/NSStream.m:490)
    - `NSString` param → `NSObject#release`
  - **`[super …]` from NXConstantString:** → `NSString#dataUsingEncoding:allowLossyConversion:`, which matches the header's `@interface NXConstantString : NSString`.
  - **Static declared inside `@implementation`:** `load_lock` → `NSRecursiveLock#unlock` medium. The method is macro-generated, which is a spec gap.
  - **Categories:** `NSDictionary#fileType` comes from `@implementation NSDictionary(NSFileAttributes)` and is high.
- **Other checks:**
  - All 225 receivers declared as file statics inside `@implementation … @end` resolve correctly.
  - All 18 `self->ivar` receivers resolve correctly.
  - No `BLOCK_SCOPE#` callee remains.
  - No case was found where an ivar and a shadowing local of a different type are mixed up.

### Precision sample
- **Seed:** `random.seed(5050)`.
- **Strata:** 30 high, 10 low, 5 medium and 5 unknown edges, from 43 files.
- **Wrong (2):**
  - NSKVOSwizzling.m:277: `[self …]` where `self` is a C-function parameter.
  - NSData.m:1210: `GSPropertyListMake` reported as a callback.
- **Correct, with spec-gap notes:**
  - #17 `NS_DURING` is an object-like macro.
  - #41 `_NSKVOKeypathObserver#observer` is a synthesized property, reported medium.
  - #42–44 `NSRecursiveLock#unlock` and `NSLock#lock` are macro-generated methods, reported medium.
  - #45 `IrunLoops#objectAtIndex:` has a macro receiver.
- **High (30/30 correct):**
  - Typed receivers resolved to the ancestor: `writeInfo` → `NSArray#count`, `attr` → `NSDictionary#objectForKey:`, `dict`, `wm`, `html` → `AGSHtml#setLocalRefs:`, `d` → `NSCalendarDate#dayOfWeek`, `attributes` → `NSDictionary#fileType` (category).
  - `[NSLock new]` → `NSObject#new`, and `[NSString class]` → `NSObject#class`.
  - Macros #defined in the scan: `AUTORELEASE`, `DESTROY`, `OBJECTAT`.
  - Functions defined in the scan: `NSLog`, `NSEndHashTableEnumeration`, `objc_loadWeakRetained` (ObjectiveC2/weak.m).
- **Low (9/10 correct):**
  - Computed receivers: `[[NSRunLoop currentRunLoop] addTimer:…]`, `[[… substringFromIndex:] stringByReplacingString:…]` (on its keyword's line) and `.retain`.
  - `_sibling` is declared `id`, and `obj` is an `(id)` parameter.
  - External libc calls: `strcmp` ×2 and `free` ×2.
- **Unknown (4/5 correct):** `imp`, `get`, `cntImp` and `_eTagImp` are IMP variables.

### Recall functions

| Function | Location | Real calls | Missed | Non-calls | Other issues |
|---|---|---|---|---|---|
| `NSKeyedUnarchiver#initForReadingWithData:` | Source/NSKeyedUnarchiver.m:1049 | 21 | 0 | 1 | 4 `_archive` edges low (pattern 15); `IF_NO_ARC` at line 1067 instead of 1071 (pattern 2) |
| `UserDirsParseXDG` | Source/NSPathUtilities.m:1806 | 35 | 0 | 0 | `key.hasPrefix:`/`key.hasSuffix:` low through `GS_FOR_IN(NSString*, key, keys)` (spec gap); 13 edges come from an `#if 0` block (spec gap) |
| `GSFileHandle#receivedEventRead` | Source/GSFileHandle.m:2197 | 27 | 0 | 0 | none; `readInfo` (ivar) and `item` (local `NSMutableData*` → `NSData#length`) are both typed correctly |

The non-call is the cast `(GSIArrayItem)((id)[NilMarker class])` at line 1082 (pattern 4).

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| Source/NSKVOSwizzling.m:277 | `[self willChange: NSKeyValueChangeInsertion` (in `static void NSKVONotifying$insertObject$inXxxAtIndex$(id self, …)`) | → `.willChange:valuesAtIndexes:forKey:`, low, method | `self.willChange:valuesAtIndexes:forKey:`, low | wrong callee | `self` parameter of a C function treated as a computed receiver |
| Source/Additions/GSObjCRuntime.m:1013 | `sig = [self methodSignatureForSelector: sel];` (`GSObjCGetVal(NSObject *self, …)`) | GSObjCGetVal → `.methodSignatureForSelector:`, low | `NSObject#methodSignatureForSelector:`, high | wrong callee / wrong confidence | same; typed `NSObject *self` parameter ignored |
| Source/NSData.m:1210 | `GSPropertyListMake(self, nil, NO, YES, 0, &result);` | → `GSPropertyListMake`, unknown, callback | `GSPropertyListMake`, direct | wrong confidence / other (call_type) | block-scope function prototype treated as a function variable (unchanged) |
| Source/NSKeyedUnarchiver.m:1073 | `_archiverClass = [_archive objectForKey: @"$archiver"];` (ivar `NSDictionary *_archive;` in NSKeyedArchiver.h:259, inside `#if GS_EXPOSE`) | → `_archive.objectForKey:`, low | `NSDictionary#objectForKey:`, high | wrong callee / wrong confidence | header ivar not typed. Other ivars in the same block (`_keyMap`, `_objects`) are typed |
| Source/NSUnarchiver.m:1576 | `return (cursor >= [data length]);` (ivar `NSData *data;` NSArchiver.h:167) | NSUnarchiver#isAtEnd → `data.length`, low | `NSData#length`, high | wrong callee / wrong confidence | same |
| Source/NSUserNotification.m:177 | `[_scheduledNotifications addObject: un];` (ivar `NSMutableArray *_scheduledNotifications;`, property `NSArray *scheduledNotifications`) | → `NSArray#addObject:`, medium | `NSMutableArray#addObject:`, high | wrong callee / wrong confidence | property-implied `_name` type overrides the explicitly declared ivar |
| Source/NSThread.m:918 | `thread = [[NSThread alloc] initWithTarget: aTarget` | → `NSThread.alloc`, low | `NSObject#alloc`, high (v3a had this) | wrong callee / wrong confidence | explicit class receiver emitted as unknown receiver (regression) |
| config/config.objc.m:21 | `return ([Test testResult] + 1);` (`+(int) testResult` defined at :14) | main → `Test.testResult`, low | `Test#testResult`, high | wrong callee / wrong confidence | same regression (v3a: `Test#testResult` medium) |
| Source/NSLock.m:472 | `GS_COND_BROADCAST(_condition);` (inside `@implementation NSCondition`, `- (void) broadcast`) | `NSRecursiveLock#broadcast` → `GS_COND_BROADCAST` | caller `NSCondition#broadcast` | wrong caller | after `MISLOCKED MLOCK … MUNLOCK @end` (file-scope macro lines with no `;`) the next `@implementation` is not recognized |
| Source/NSLock.m:700 | `[_condition broadcast];` | → `NSCondition#broadcast`, medium | same callee, high (defined at NSLock.m:470) | wrong confidence | same; NSCondition's methods are not registered as definitions |
| Source/GSDictionary.m:192 | `if (nil != (self = [super init]))` (`@interface GSDictionary : NSDictionary` in GSDictionary.m; `- (id) init` at NSDictionary.m:218) | → `NSObject#init`, high | `NSDictionary#init`, high | wrong callee | superclass taken from NSDictionary.m:56 `@interface GSDictionary : NSObject	// Help the compiler` |
| Source/NSPredicate.m:4275 | `return CALL_NON_NULL_BLOCK(_block, object, variables);` | edge at line **4274** (`{`) | line 4275 | wrong line | edges after a two-line `(GS_GENERIC_CLASS(NSDictionary,\n NSString*,id)*)variables` parameter shift up one line, and two lines after the second occurrence |
| Source/NSPredicate.m:4333 | `- (void) dealloc` (real call `DESTROY(_bindings);` is :4335) | → `DESTROY`, macro, at 4333 | line 4335 | wrong line | same shift; it lands on a method-header line |
| Source/NSDateIntervalFormatter.m:161 | `[formatter setDateFormat: format];` (`NSDateFormatter *formatter`) | → `NSDateFormatter#setDateFormat:`, medium | same callee, high (defined in NSDateFormatter.m) | wrong confidence | NSDateFormatter.m methods lost to the `GS_PRIVATE_INTERNAL` breakage are not definitions |
| Source/NSDateFormatter.m:525 | `([date timeIntervalSince1970] * 1000.0),` (parameter `(NSDate*)date`) | `<global>` → `date.timeIntervalSince1970`, low | `NSDateFormatter#…` → `NSDate#timeIntervalSince1970`, high | wrong caller / wrong callee | typed receivers are not resolved inside the `GS_PRIVATE_INTERNAL`-broken region |
| Source/NSCalendar.m:179 | `if ([NSGregorianCalendar isEqualToString: my->identifier])` (`GS_EXPORT NSString * const NSGregorianCalendar;` NSLocale.h:83) | → `NSGregorianCalendar#isEqualToString:`, medium | `NSString#isEqualToString:`, high | wrong callee / wrong confidence | header-declared `NSString*` constant treated as a class name |
| Source/NSKeyedUnarchiver.m:1082 | `GSIArrayAddItem(_objMap, (GSIArrayItem)((id)[NilMarker class]));` | → `GSIArrayItem`, low, direct | no edge (cast) | not a call (recall check) | `(Type)(expr)` cast read as a call (unchanged) |
| Source/NSKeyedUnarchiver.m:1071 | `IF_NO_ARC(RETAIN(_archive);)` | → `IF_NO_ARC`, macro, at line 1067 (`{`) | line 1071 | wrong line (recall check) | macro argument containing `;` (unchanged) |
| Source/NSIndexPath.m:184 | `[aCoder encodeInt: (NSInteger)_length forKey: @"NSIndexPathLength"];` | → `NSCoder#encodeInt:_length:forKey:`, medium | `NSCoder#encodeInt:forKey:`, high | wrong callee | identifier after a cast read as a keyword (unchanged) |
| Source/Additions/GCArray.m:209 | `[NSException raise: NSRangeException` / `format: @"[%@-%@]: index: %"PRIuPTR,` | → `NSException#raise:format:PRIuPTR:`, medium | `NSException#raise:format:`, high | wrong callee | `PRI*` macro read as a keyword (unchanged) |
| Source/NSDateFormatter.m:291 | `- (NSString*) stringForObjectValue: (id)anObject` | `<global>` → `stringForObjectValue`, low, direct | no edge | not a call | `GS_PRIVATE_INTERNAL` breakage (unchanged) |
| Source/NSKVOSwizzling.m:421 | `GENERATE_NSKVOSetDispatchIndividual_IMPL(NSKeyValueUnionSetMutation);` | `<global>` → macro | caller `Source/NSKVOSwizzling` | wrong caller | file-level caller rule not applied (unchanged) |
| Source/inet_ntop.m:154 | `memset(words, '\0', sizeof words);` | `<global>` → `memset` | caller `inet_ntop6` | wrong caller | K&R definition (unchanged) |
| Source/NSException.m:975 | `(optSym)(SYMOPT_UNDNAME \| SYMOPT_DEFERRED_LOADS);` | → `optSym`, low, direct | `optSym`, unknown, callback | wrong confidence / other | parenthesised function-pointer call (unchanged) |
| Source/NSNumberFormatter.m:154 | `static inline UNumberFormatRoundingMode` (head of `NSToICURoundingMode`) | `<global>` → `NSToICURoundingMode`, high, macro | no edge | not a call | function head read as a macro (unchanged) |
| Source/NSPathUtilities.m:1868 | `if ([key hasPrefix: @"XDG_"] && [key hasSuffix: @"_DIR"])` after `GS_FOR_IN(NSString*, key, keys)` | → `key.hasPrefix:`, low | `NSString#hasPrefix:`, high if macro-declared variables count | spec gap | declaration exists only inside a macro argument |
| Source/NSURLSessionTask.m:1205 | `GS_GENERIC_CLASS(NSArray, NSHTTPCookie *)	*cookies;` | (no edge; v3a had a `GS_GENERIC_CLASS` macro edge) | macro edge? | spec gap | macro in type position is now reduced away |

## Systematic patterns (scripted census, ordered by count)

The union of wrong edges is **806 of 60,030**. Patterns overlap: for example, the NSPredicate shift also adds 3 edges to pattern 2 and 2 to pattern 8, and pattern 5 overlaps pattern 1 and pattern 6. Script: `libs-base_v5_census.py`.

1. **`<global>` caller: 316 (unchanged).**
   - NSDateFormatter.m 149 and NSByteCountFormatter.m 43 come from the `GS_PRIVATE_INTERNAL` breakage.
   - About 100 are file-scope code that should get the file-path caller: `GENERATE_*_IMPL`, `CACHE_NSNUMBER_GEN_FUNCS`, `GS_MUTEX_INIT_STATIC` initialisers and `#if OS_API_VERSION(...)`.
   - The rest: 18 in a `#define` body (Unicode.m), 7 K&R (inet_ntop.m), 5 function heads read as macros (NSNumberFormatter.m) and 8 `@implementation`/line-1 macro edges.
2. **Macro on the wrong line: 153.** 150 are the old `;`-in-argument case (`IF_NO_ARC` 137) and 3 come from the NSPredicate shift (pattern 12).
3. **`self` parameter of a C function emitted as a computed receiver `.sel`: 103.**
   - 65 edges have a typed `self`: `NSObject *self` in GSObjCGetVal/GSObjCSetVal (45), KVC SetValueForKey/KVCSetterForPropertyName (11), and `NSUserDefaults *self` in updateCache (9). These should be `NSObject#…`/`NSUserDefaults#…`.
   - 38 have `id self` (NSKVOSwizzling.m) and should be `self.sel` low.
   - This predates v5: v3a had 106. It was found in this review's sample.
4. **C casts `(Type)(expr)` as direct calls: 74 (unchanged).**
5. **Typed receivers left `recv.sel` low inside the `GS_PRIVATE_INTERNAL`-broken methods of NSDateFormatter.m and NSByteCountFormatter.m: 53.** Examples are `coder.encodeBool:forKey:` and `array.objectAtIndex:`. The callers are also wrong (patterns 1 and 6).
6. **Caller loses its class prefix: 40 (unchanged)** (NSDateFormatter.m, NSByteCountFormatter.m).
7. **Selector corrupted by argument contents: 31 (unchanged).** 19 are `PRI*` macros and 12 are an identifier after a cast.
8. **Method-header lines reported as calls: 26.** 24 are unchanged, in the NSDateFormatter.m `<global>` region, and 2 are NSPredicate shift edges that land on header lines.
9. **NSLock.m `@implementation NSCondition` methods attributed to `NSRecursiveLock#…`: 22.** This is new to the report, and v3a had the same callers. Covered lines are NSLock.m:455–520 (allocWithZone:, initialize, broadcast, finalize, init, signal, wait, waitUntilDate:).
10. **Callee defined in the scan but reported medium because its definitions were lost: 21.** These are `NSDateFormatter#…` (19) and `NSByteCountFormatter#…` (2), reached from typed receivers in NSDateIntervalFormatter.m, NSISO8601DateFormatter.m, NSHTTPCookie.m and the formatter files.
11. **Direct calls typed callback/unknown: 15 (unchanged).** These are block-scope prototypes and calls inside VLA size expressions.
12. **Line shift after a multi-line `GS_GENERIC_CLASS(...)` parameter type: 14 (new regression).** NSPredicate.m `GSBlockPredicate`/`GSBoundBlockPredicate` edges are 1, then 2, lines early.
13. **Explicit class receiver emitted as `Class.sel` low: 12 (new regression).**
    - The receivers are `NSThread` 7 (NSThread.m), `NSConnection` 2 (NSConnection.m), `NSByteCountFormatter` 1, `NSTimer` 1 (NSURLSession.m:595) and `Test` 1 (config.objc.m).
    - v3a resolved all of them, for example `NSObject#alloc` high and `NSThread#currentThread` high.
    - The same classes resolve correctly in other files: `[NSThread …]` resolves in NSOperation.m (11).
14. **Ancestor resolution through a "Help the compiler" forward `@interface X : NSObject` instead of the real superclass: 8.**
    - Affected classes: GSDictionary ×4 (`[super init]` → `NSObject#init` instead of `NSDictionary#init`, `[GSDictionary allocWithZone:]`), GSMutableDictionary ×1, GSFTPURLHandle/GSHTTPURLHandle `[super dealloc]` → `NSObject#dealloc` instead of `NSURLHandle#dealloc`, and NSDataMalloc ×1.
    - GSXML.m's `GSXMLDummy` branch (4) is excluded because it sits in an `#if` for builds without libxml.
15. **Header ivar not typed: 6.** These are `_archive` ×4 (NSKeyedUnarchiver.m) and `data` ×2 (NSUnarchiver.m). Both ivar blocks contain `#define GSIArray void*` lines, but NSArchiver's similar block types `_data` correctly, so the cause is unconfirmed.
16. **Property-implied type overrides an explicit ivar: 5.** NSUserNotification.m `_scheduledNotifications`/`_deliveredNotifications` are declared `NSMutableArray*`. `addObject:`, `removeObject:` and `removeAllObjects` come out as `NSArray#…` medium.
17. **NSCondition methods defined in the scan reported medium: 3.** The calls are `[_condition wait]`, `waitUntilDate:` and `broadcast` in NSConditionLock. This is a consequence of pattern 9.
18. **Parenthesised function-pointer calls as direct/low: 3 (unchanged).**
19. **Non-class identifier treated as a class name: 1.** This is `NSGregorianCalendar`; v3 had 193.

## Spec gaps (counted separately, not as wrong)

- **Macro-generated methods reported medium: 552.**
  - These are `NSLock`/`NSRecursiveLock`/`NSCondition`/`NSConditionLock` `#lock`, `unlock`, `tryLock`, `lockBeforeDate:`, `setName:` and `isLockedByCurrentThread`, produced by `MLOCK`/`MUNLOCK`/… lines inside `@implementation`.
  - They exist only after macro expansion.
- **Object-like macros reported as `macro` edges: 654.** These are `NS_DURING`/`NS_HANDLER`/`NS_ENDHANDLER` 177 each, `ENTER_POOL`/`LEAVE_POOL` 42 each and `GS_MUTEX_INIT_STATIC` 39.
- **Receivers that are macros expanding to an expression: 107 `MACRO#sel` medium.** Examples: `HANDLER`, `LOCALE`, `Irequest…`/`IrunLoops`, `this->field`.
- **Same-line repeated calls collapse into one edge.** 87 v3a edges merged this way in v5, plus `_NS_RETURN_HACK` (68 lines).
- **Edges inside `#if 0` blocks: 53.** For example, UserDirsParseXDG lines 1835–1849.
- **Variables declared through `GS_FOR_IN(Type*, var, coll)`: 22** low receivers with a typed declaration inside the macro: NSString 12, GSUTVariable 4, GSAvahiWatcher 3, and others. `GS_FOR_IN(id, …)` correctly stays low.
- **Methods copied in at runtime by `GSObjCAddClassBehavior`, reported medium on the subclass: about 43.** Examples: GSSocketInputStream/GSInet*`#_setSocketAddress:port:family:`, `GSSocketServerStream#_sock`, `GSMutableArray#_raiseRangeExceptionWithIndex:from:`.
- **Synthesized-property accessors reported medium: about 22.** Examples: `NSUserNotification#title`, `_NSKVOKeypathObserver#observer`.
- **Explicit class receiver with an inherited class method: 2,279 edges now resolve to the defining ancestor, high.** Examples: `[NSArray class]` → `NSObject#class`, `[GSLocalServerStream alloc]` → `NSObject#alloc`. The spec's superclass rule names only `self`, but this is consistent with decision A plus ancestor resolution, and there are now 0 medium cases.
- **Alternative `@implementation` heads in `#if`/`#else`.** NSNumberFormatter.m:289/291 has 26 edges, and the tool used the first branch.
- **Classes named through a macro** (`@implementation DATE_CONCRETE_CLASS_NAME` → `NSGDate`): `NSGDate#class` medium, 1 edge.
- **`GS_GENERIC_CLASS(...)` in type position is no longer reported as a macro edge.** 2 in-scope edges disappeared.

## Previous findings

### v3 mismatch-table rows

| v3 row | Status | Now |
|---|---|---|
| NSTimeZone.m:3200 `aDate` (param) | **Fixed** | `NSDate#timeIntervalSince1970` high |
| GSXML.m:2638 `data` (param) | **Fixed** | `NSData#length`, `NSData#bytes` high |
| StringsFile.m:631 `se` (local) | **Fixed** | `StringsEntry#flags` high |
| NSBundle.m:650 `paths` (local) | **Fixed** | `NSArray#objectEnumerator` high |
| GSMime.m:3511 `m` (local) | **Fixed** | `NSMutableString#deleteCharactersInRange:` high |
| GCObject.m:205 `object` (local) | **Fixed** | `GCObject#gcNextObject` high |
| NSFileManager.m:555 `str` (local) | **Fixed** | `NSString#cStringUsingEncoding:` high |
| NSPropertyList.m:407 `value` (ivar) | **Fixed** | `NSString#length` high (ancestor of NSMutableString) |
| GSHTTPURLHandle.m:317 `urlLock` (file static) | **Fixed** | `NSLock#lock` medium. Medium is the macro-generated-method spec gap. |
| NSException.m:1209 `bfi` (local) | **Fixed** | `GSBinaryFileInfo#functionForAddress:` high |
| GSRunLoopCtxt.m:410 `contexts` (param) | **Fixed** | `NSArray#objectAtIndex:` high |
| NSCalendarDate.m:857 `fd` (local) | **Fixed** | `NSMutableData#mutableBytes` high |
| NSSet.m:674 `path` (param) | **Fixed** | `NSString#rangeOfString:` high |
| win32/GSFileHandle.m:2312 `item` (local) | **Fixed** | `NSData#length` high |
| NSIndexPath.m:184 corrupted selector | **Still present** | `NSCoder#encodeInt:_length:forKey:` medium |
| GCArray.m:209 `PRIuPTR` keyword | **Still present** | `NSException#raise:format:PRIuPTR:` medium |
| GCArray.m:61 `[self retain]` not ancestor-resolved | **Fixed** | `NSObject#retain` high |
| NSArray.m:375 `NSArrayClass` Class variable | **Fixed** | `NSArrayClass.arrayWithObjects:count:` low |
| GSMime.m:6300 `Cte8bit` typed constant | **Fixed** | `NSString#caseInsensitiveCompare:` high |
| NSMessagePort.m:1358 `IF_NO_ARC` wrong line | **Still present** | still at 1227 |
| GSXML.m:341 `xmlAttrPtr` cast | **Still present** | `xmlAttrPtr` low direct |
| NSException.m:975 `optSym` | **Still present** | low direct |
| GSObjCRuntime.m:187 `sel_register_name` callback | **Still present** | unknown callback |
| NSObject.m:2298 `strlen`/`GSClassNameFromObject` callback | **Still present** | unknown callback |
| NSDateFormatter.m:291 header as call | **Still present** | `<global>` → `stringForObjectValue` |
| NSByteCountFormatter.m:66 caller without class | **Still present, and worse** | The caller is still `stringFromByteCount:countStyle:`. `[NSByteCountFormatter new]` is now `NSByteCountFormatter.new` low; v3a had `#new` medium (pattern 13). |
| NSKVOSwizzling.m:421 `<global>` | **Still present** | unchanged |
| NSArray.m:87 `GS_MUTEX_INIT_STATIC` `<global>` | **Still present** | unchanged |
| inet_ntop.m:154 K&R | **Still present** | unchanged |
| NSNumberFormatter.m:154 function head as macro | **Still present** | unchanged |

### v3 systematic patterns

| v3 pattern | v3 count | Status | v5 count |
|---|---|---|---|
| 1. Typed receivers not resolved (decision A) | 15,867 | **Fixed, small residue** | 64 wrong: 53 inside the formatter breakage (pattern 5), 6 header ivars (pattern 15), 5 property-over-ivar (pattern 16). Also 22 `GS_FOR_IN` spec gaps. |
| 2. `self`/`super` inherited methods stay medium | 334 | **Fixed** | 0. A new side-effect is 8 edges resolved through a forward-declared fake superclass (pattern 14). |
| 3. `<global>` caller | 316 | **Still present** | 316 |
| 4. Non-class capitalised identifiers as class names | 193 | **Fixed, small residue** | 1 wrong (`NSGregorianCalendar`) and 1 spec gap (`NSGDate`) |
| 5. Macro wrong line | 150 | **Still present** | 150, plus 3 from the new NSPredicate shift |
| 6. Casts as direct calls | 74 | **Still present** | 74 |
| 7. Caller loses class prefix | 40 | **Still present** | 40 |
| 8. Selector corruption (`PRI*`, cast) | 31 | **Still present** | 31 |
| 9. Method-header lines as calls | 24 | **Still present** | 24, plus 2 shifted edges |
| 10. Direct calls typed callback/unknown | 15 | **Still present** | 15 |
| 11. Parenthesised function pointers | 3 | **Still present** | 3 |
| Spec gap: explicit-class inherited methods medium | 995 | **Resolved** | 0 medium; 2,279 resolve to the ancestor, high |
| Spec gap: macro receivers | 107 | Unchanged | 107 |
| Spec gap: object-like macros | 663 (stated) | Unchanged | 654. The same script gives 654 on v3a. |
| Spec gap: same-line collapse | `_NS_RETURN_HACK` 68 lines | **Wider** | Plus 87 merges from typed resolution |

### Interrupted v4 partial findings

| v4 finding | Status | Evidence |
|---|---|---|
| Core Foundation subclasses not resolved to the defining ancestor | **Fixed** | 0 typed edges keep the subclass when only an ancestor in the scan defines the method. Examples: `NSMutableArray` → `NSArray#objectAtIndex:`, `NSMutableString` → `NSString#length`, `NSInputStream` → `NSStream#close`. |
| Ivars inside `#if` in `@interface` braces untyped | **Fixed except 6** | Ivar receivers are now typed (2,356 analysed; examples: `_textChars`, `_urlString`, `writeInfo`, `_keyMap`). The 6 exceptions are pattern 15. |
| Statics between `@implementation`/`@end` untyped | **Fixed** | 225 of 225 |
| `self->ivar` untyped | **Fixed** | 18 of 18 (GSHTTPAuthentication.m `self->_space`, `self->_credential`, `self->_lock`) |
| `BLOCK_SCOPE NSLock *x` typed as `BLOCK_SCOPE` | **Fixed** | 0 `BLOCK_SCOPE#` callees |

### New since v3a (regressions or newly measured)
- **Regressions:**
  - 12 explicit class receivers became `Class.sel` low (pattern 13).
  - 14 NSPredicate.m edges are shifted by the `GS_GENERIC_CLASS` reduction (pattern 12).
  - 2 `GS_GENERIC_CLASS` macro edges were dropped.
  - 87 same-line merges.
- **Exposed by typing:**
  - 21 defined-but-medium formatter callees (pattern 10).
  - 5 property-over-ivar edges (pattern 16).
  - 8 fake-superclass resolutions (pattern 14).
- **Pre-existing but first reported here:**
  - 103 `self`-parameter edges in C functions (pattern 3).
  - 22 NSLock.m NSCondition wrong callers (pattern 9) and the 3 medium edges that follow from them (pattern 17).

Helper scripts are in <fanout>/:
- **Loading and definitions:** `libs-base_v5_load.py`, `libs-base_v5_defs.py`
- **Typed-receiver analysis:** `libs-base_v5_typed.py`, `libs-base_v5_check.py`, `libs-base_v5_cmp.py`, `libs-base_v5_ul.py`
- **Sampling and recall:** `libs-base_v5_sample.py`, `libs-base_v5_diffsample.py`, `libs-base_v5_recall.py`
- **Pattern scripts:** `libs-base_v5_cls.py`, `libs-base_v5_clslow.py`, `libs-base_v5_impl.py`, `libs-base_v5_realsup.py`, `libs-base_v5_supconf.py`, `libs-base_v5_cself.py`, `libs-base_v5_forin.py`, `libs-base_v5_firstivar.py`, `libs-base_v5_shadow.py`, `libs-base_v5_statimpl.py`, `libs-base_v5_line.py`, `libs-base_v5_lost.py`, `libs-base_v5_med.py`
- **Census:** `libs-base_v5_census.py`, `libs-base_v5_on3a.py`
- **Lookup utilities:** `libs-base_v5_at.py`, `libs-base_v5_old.py`, `libs-base_v5_grep.py`, `libs-base_v5_diff.py`
