# Blind call-graph review: s-reachability (objc), round 4

precision 48/50; census ≈98.7% (2 wrong of 157 in-scope); recall: 0 missed of 38 real calls; 0 non-calls

## Scope
Tool output `<scans>/final8-A/s-reachability.v2.json` has 163 edges. The 6 edges from `Package.swift` (Swift) are out of scope. No path has a segment named test/, tests/, spec/, examples/ or docs/. The Xcode demo targets `iOSReachabilityTestARC/` and `MacOSReachabilityTestARC/` are in scope (Decisions 2026-11-09). That leaves **157 in-scope edges in 6 files** (`Reachability.m`, two `TMAppDelegate.m`, two `main.m`, `TMViewController.m`). `Reachability.h` has no edges.
- Confidence: high 29, medium 49, low 76, unknown 3.
- call_type: method 90, direct 61, macro 3, callback 3.
- The `measured_accuracy` field was ignored.

Sample: seed 4. I first picked one random edge from each of the 6 files (that is all the files), then filled tier quotas of low 24, medium 15, high 8 and unknown 3 (the only 3 unknown edges). Every high callee is in `nodes` (C1 holds).

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| Reachability.m:100 | `id reachability = [[self alloc] initWithReachabilityRef:ref];` | Reachability#reachabilityWithHostname: → `.initWithReachabilityRef:`, low, method | `Reachability#initWithReachabilityRef:`, high, method. Decisions 2026-10-29 ObjC: `[[T alloc] init…]` is `T#alloc` plus `T#init…`. The tool itself names the inner send `Reachability#alloc`, and `initWithReachabilityRef:` is defined at Reachability.m:179. | wrong callee / wrong confidence | the init is not typed when the alloc receiver is `self` in a class method (in sample) |
| Reachability.m:113 | `id reachability = [[self alloc] initWithReachabilityRef:ref];` | Reachability#reachabilityWithAddress: → `.initWithReachabilityRef:`, low, method | `Reachability#initWithReachabilityRef:`, high, method | wrong callee / wrong confidence | same as above (in sample) |
| Reachability.h:48 | `typedef NS_ENUM(NSInteger, NetworkStatus) {` | no edge | `NS_ENUM`, macro, high (`#define`d at Reachability.h:43), caller `Reachability` (file-scope code) | missed call | file-scope function-like macro use in a header gets no edge (similar to open defect objc/11, which names .m). Found by looking, not in the recall functions. |

## Systematic patterns (scripted, `s-reachability_r4_census.py`)
1. **`[[self alloc] init…]` in a class method leaves the init as a `.init…` low guess: 2 edges.** These are all the `self`-receiver alloc/init sites in scope. I checked both by hand (lines 100 and 113). The two `[[T alloc] init…]` sites with a named class are resolved correctly: `UIWindow#initWithFrame:` and `TMViewController#initWithNibName:bundle:`, both medium. This matches the shape of open defect `objc/11-file-scope-code` ("[[T alloc] init] … gives .init low"). That defect names .mm class methods; this case is a .m file.

Union of wrong edges: 2. Census precision = 1 − 2/157 ≈ 98.7%.

Checked and correct (no wrong edges):
- `[super m]` with an SDK superclass gives `.m` low (7 edges).
- Unknown-type receivers: `scheme.isEqualToString:` and call-result receivers (`.addObserver:selector:name:object:`, `.bounds`, `.addOperationWithBlock:`, `.postNotificationName:object:`) are low guesses. Typing reaches only declarations in the scan.
- Typed locals, params and properties of SDK types (`NSString#UTF8String`, `NSNumber#intValue`, `NSNotification#object`, `UIWindow#makeKeyAndVisible` via `@property UIWindow *window`) are medium.
- Calls on `Reachability`-typed locals and properties are high.
- Inherited SDK class methods (`Reachability#alloc`, `Reachability#class`, `TMAppDelegate#class`) are medium.
- Block-property invocations `self.reachableBlock(self)` give `reachableBlock`, callback, unknown.
- The static C function `reachabilityFlags` is high direct, alongside `Reachability#reachabilityFlags`, high method.
- Calls inside blocks fold into the enclosing method.
- Multi-line sends are reported on the first keyword's line.

## Missed-call patterns (recall)
I listed every call in three functions and compared it with the tool's edges:
- `Reachability#reachabilityWithURL:` (Reachability.m:143–168): 8 calls.
- `TMViewController#reachabilityChanged:` (TMViewController.m:198–260): 22 calls.
- `TMAppDelegate#applicationDidFinishLaunching:` (MacOSReachabilityTestARC/TMAppDelegate.m:34–61): 8 calls.

All 38 calls are present with the right caller and line, and there are no non-calls. The dot-syntax reads `url.host`, `url.port` and `url.scheme` are NSURL properties, so they are not calls (Decisions 2026-10-29).

Outside the recall functions, by looking:
- **File-scope function-like macro use in a header gets no edge: 1 site** (`NS_ENUM`, Reachability.h:48).

## Spec gaps (counted separately, not wrong)
1. **C functions declared only in SDK/system headers: 60 edges, all `low`, `direct`.** Construct: `NSLog(@"%@", temp);`, `dispatch_async(dispatch_get_main_queue(), ^{`, `SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)`, `bzero(&zeroAddress, sizeof(zeroAddress));`, `htonl(IN_LINKLOCALNETNUM)`, `inet_aton(...)`, `CFRelease(...)`, `NSStringFromClass(...)`, `UIApplicationMain(...)` / `NSApplicationMain(...)`.
   - Counts: NSLog 14, dispatch_async 8, dispatch_get_main_queue 8, SCNetworkReachabilityGetFlags 7, SCNetworkReachabilitySetCallback 3, and 20 others.
   - Open question (CAPABILITIES objc/17, undecided): is a bare call to a C function declared only in a header outside the scan a low guess ("a bare name not found in the scan") or medium ("an import" / the prototype rule)? `htonl`/`htons` are function-like macros in the Darwin headers, which raises the same question about call_type.
2. **Foundation macro without a visible `#define`: 3 edges, `NSLocalizedString`, medium, macro.** Construct: `return NSLocalizedString(@"Cellular", @"");` (Reachability.m:452, 456, 459). Open question (CAPABILITIES objc/17, the `MAX` case): is a macro whose `#define` is outside the scan reported as call_type macro at medium, or as an ordinary bare call, and at what tier?
3. **Dot syntax on a method that is not a declared `@property`: 12 sites, no edges emitted.** Construct: `reachability.currentReachabilityString` (TMViewController.m:66, 80, 108, 119, 141, 152, 206, 214, 225, 233, 244, 252). `currentReachabilityString` is declared as a method, `-(NSString*)currentReachabilityString;` (Reachability.h:100), not as a property. Open question: Decisions 2026-10-29 says "Dot-syntax property access is not a call". Does that cover dot syntax that sends a message to a plain method with no `@property` declaration? If not, is it `Reachability#currentReachabilityString`, method, high?
