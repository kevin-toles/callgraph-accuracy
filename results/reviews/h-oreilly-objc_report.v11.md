# Blind call-graph review: h-oreilly-objc (objc), round 11

precision 39/50 (0 wrong, 11 spec gap); census ≈99.66% (79 wrong of 23183 in-scope); recall: 0 missed of 43 real calls; 0 non-calls

## Scope
Tool output: `<scans>/final8-A/h-oreilly-objc.v2.json` (79,779 edges in all: .swift 26,712, .m 23,183, .java 20,599, .js 8,589, .c 438, .kt 258). I judged only Objective-C edges, meaning `source_file` ends in `.m` or `.mm`. There are no `.mm` edges. None of the `.m` edges is under a `test/`, `tests/`, `spec/`, `examples/` or `docs/` segment. Xcode `*Tests/` targets and `Pods/` (CocoaAsyncSocket, FBSnapshotTestCase) are in scope (Decisions 2026-11-09).

- In-scope edges: **23,183**, in 2,102 files.
- By confidence: medium 11,261, low 9,260, high 2,648, unknown 14.
- By call_type: method 16,387, direct 5,773, macro 1,009, callback 14.
- Joint split:

| confidence | call_type | edges |
|---|---|---|
| medium | method | 10,621 |
| low | direct | 5,675 |
| low | method | 3,585 |
| high | method | 2,181 |
| medium | macro | 640 |
| high | macro | 369 |
| high | direct | 98 |
| unknown | callback | 14 |

## Method
- **Sample:** seed 11. Quotas: unknown 5 (the minimum), high 6, medium 22, low 17. The 50 edges span 49 files. Helper: `h-oreilly-objc_r11_sample.py`.
- **Sample results:** 39 edges are correct. 11 are spec gaps (SG1 and SG2 below). None is wrong.
  - The correct edges include the forms below, all checked against source:
    - `[super m]` with an out-of-scan superclass gives `.m`, low.
    - `[[T alloc] init…]` gives `T#alloc` plus `T#init…`.
    - `AppDelegate#class` and `XMLElement#alloc` are medium, because the method is inherited from NSObject, which is outside the scan.
    - Receivers typed by a property, an ivar, a parameter or a local resolve, for example `self.myScrollView` gives `UIScrollView#addSubview:`.
    - The category method `UIImage#fb_diffWithImage:` is high.
    - Calls through a block ivar or parameter (`self->sendFilterBlock(...)`, `completionHandler(...)`, `block()`) are callback, unknown.
    - Multi-line sends are reported on the line of the first selector keyword.
- **Tier cross-check:** I built a source-text index of scanned `@implementation`/`@interface`/`@protocol` selectors (`h-oreilly-objc_r11_defs.py`, `h-oreilly-objc_r11_tiers.py`, `h-oreilly-objc_r11_super.py`).
  - 0 medium `T#m` edges name a selector defined on T in the scan.
  - 0 high edges name a selector that is not defined in the scan.
  - 0 medium edges name a selector inherited from a scanned superclass.
  - 0 low bare C calls have a body or `#define` in the scan (`h-oreilly-objc_r11_cfunc.py`).
- **Other checks:**
  - Block-variable calls (`h-oreilly-objc_r11_blocks.py`): every call through a block parameter, local or global has an edge.
  - Fast-enumeration loop variables and `__block`/`__weak` locals (`h-oreilly-objc_r11_forin.py`): 205 of 205 typed correctly.
  - `@catch` receivers and typedef'd class aliases: none occur in scope.

## Mismatch table
None of the 50 sample edges is wrong. The rows below are the sample's spec gaps, followed by one or two hand-checked instances of each wrong pattern the census found.

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| ios-6-programming-cookbook-source-codes/Chapter 1/Defining Functionality for Classes/Defining Functionality for Classes/main.m:16 | `return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));` | main → UIApplicationMain, low, direct | undecided (objc/17: SDK-header function, low or medium) | spec gap | function declared only in an SDK header |
| ios-7-programming-cookbook-source-codes/Chapter 18/Fetching Data in the Background/Fetching Data in the Background/AppDelegate.m:225 | `NSLog(@"Unresolved error %@, %@", error, [error userInfo]);` | AppDelegate#persistentStoreCoordinator → NSLog, low, direct | undecided (objc/17) | spec gap | same; 8 more sample rows of this kind (#34, 41–45, 47, 49: ABAddressBookAddRecord, CGRectMake, NSLog, ABAddressBookHasUnsavedChanges, ABAddressBookSave) |
| ios-7-programming-cookbook-source-codes/Chapter 14/Creating Folders on Disk/Creating Folders on DiskTests/Creating_Folders_on_DiskTests.m:33 | `XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);` | Creating_Folders_on_DiskTests#testExample → XCTFail, medium, macro | undecided (objc/17: macro whose `#define` is outside the scan) | spec gap | SDK macro |
| ios-7-programming-cookbook-source-codes/Chapter 18/Introduction to Core Data/Introduction to Core Data/AppDelegate.m:107 | `NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Introduction_to_Core_Data.sqlite"];` | AppDelegate#persistentStoreCoordinator → .URLByAppendingPathComponent:, low, method | NSURL#URLByAppendingPathComponent:, medium, method (`- (NSURL *)applicationDocumentsDirectory` at line 145) | wrong callee | receiver is a parameterless message result with a declared return type in the scan (open defect objc/05) |
| ios-6-programming-cookbook-source-codes/Chapter 15/Boosting Data Access in Table Views/Boosting Data Access in Table Views/PersonListViewController.m:146 | `[[self managedObjectContext] deleteObject:personToDelete];` | PersonListViewController#tableView:commitEditingStyle:forRowAtIndexPath: → .deleteObject:, low, method | NSManagedObjectContext#deleteObject:, medium, method | wrong callee | same (objc/05) |
| ios-6-programming-cookbook-source-codes/Chapter 19/Managing the State of Documents in iCloud/Managing the State of Documents in iCloud/CloudDocument.m:59 | `if ([_delegate respondsToSelector:@selector(cloudDocumentChanged:)]){` | CloudDocument#loadFromContents:ofType:error: → _delegate.respondsToSelector:, low, method | CloudDocumentProtocol#respondsToSelector:, medium (inherited from `<NSObject>`, outside the scan) | wrong callee | ivar of a property typed `id<CloudDocumentProtocol>` left untyped (open defect objc/07) |
| same file:60 | `[_delegate cloudDocumentChanged:self];` | → _delegate.cloudDocumentChanged:, low, method | CloudDocumentProtocol#cloudDocumentChanged:, high (body-less protocol method in the scan) | wrong callee / confidence | same (objc/07) |
| ios-6-programming-cookbook-source-codes/Chapter 9/Parsing XML with NSXMLParser/Parsing XML with NSXMLParser/Parsing_XML_with_NSXMLParserAppDelegate.m:91 | `if ([self.currentElementPointer.text length] > 0){` | Parsing_XML_with_NSXMLParserAppDelegate#parser:foundCharacters: → text.length, low, method | NSString#length, medium (`@property … XMLElement *currentElementPointer;`, XMLElement `@property … NSString *text;`) | wrong callee | property chain through a scanned type not typed (decision A, `obj.field` chains) |
| ios-6-programming-cookbook-source-codes/Chapter 19/Handling Conflicts in iCloud Documents/Handling Conflicts in iCloud Documents/ViewController.m:294 | `[self.conflictViewController.tableViewVersions reloadData];` | ViewController#handleDocumentStateChanged: → tableViewVersions.reloadData, low, method | UITableView#reloadData, medium | wrong callee | same |
| telegraph/Pods/CocoaAsyncSocket/Source/GCD/GCDAsyncSocket.m:5877 | `NSUInteger total = [self->currentWrite->buffer length];` | GCDAsyncSocket#progressOfWriteReturningTag:bytesDone:total:.block → buffer.length, low, method | NSData#length, medium (`GCDAsyncWritePacket *currentWrite;` and `@public NSData *buffer;`) | wrong callee | `self->ivar->field` chain not typed. The same chain without `self->` is typed (`[currentSend->buffer length]` gives NSData#length). |

## Systematic patterns (census)
Helper: `h-oreilly-objc_r11_census.py`. The union of all wrong edges is 79. I hand-checked at least two edges per pattern.

1. **Parameterless self-message results left `.m` low** (open defect `objc/05`): **55**. The receiver is `[self X]`, where `X` is declared in the file or its header with a class return type (`- (NSURL *)applicationDocumentsDirectory`, `- (NSManagedObjectContext *)managedObjectContext`, `- (NSString *)cachesDirectory`). The callee should be `T#m`, medium.
   - By callee: `.URLByAppendingPathComponent:` 43, `.stringByAppendingPathComponent:` 3, `.deleteObject:` 3, `.save:` 3, `.path` 3.
   - Script: `h-oreilly-objc_r11_retrecv3.py`.
2. **Ivars of `id<P>` properties left low** (open defect `objc/07`): **12**. `_delegate`, the synthesized ivar of `@property (nonatomic, weak) id<CloudDocumentProtocol> delegate`, in 6 CloudDocument.m copies. Each copy has 2 edges: `cloudDocumentChanged:` should be high and `respondsToSelector:` should be medium.
   - The parameters typed `id<CloudDocumentProtocol>` resolve correctly (7 edges).
   - Script: `h-oreilly-objc_r11_idp.py`.
3. **Property chains through a scanned type left low**: **11**. Examples are `self.currentElementPointer.text`/`.subElements`, where XMLElement is scanned and its properties are typed NSString*/NSMutableArray*, and `self.conflictViewController.tableViewVersions`.
   - Script: `h-oreilly-objc_r11_chain.py`.
4. **`self->ivar->field` receiver left low**: **1**. GCDAsyncSocket.m:5877.
   - Script: `h-oreilly-objc_r11_selfarrow.py`.

Census precision = 1 − 79/23,183 = **99.66%**.

## Missed-call patterns (recall)
| function | file | real calls | tool edges | missed |
|---|---|---|---|---|
| FBSnapshotTestController#compareReferenceImage:toImage:tolerance:error: (lines 127–154) | ios-11-swift-programming-cookbook/snapshot-testing/Testing Table View Cell Snapshots/Pods/FBSnapshotTestCase/FBSnapshotTestCase/FBSnapshotTestController.m | 7 distinct (8 written) | 7 | 0 |
| AppDelegate#doesPersonExistWithFirstName:lastName:inAddressBook: (lines 21–75) | ios-7-programming-cookbook-source-codes/Chapter 13/Searching the Address Book/Searching the Address Book/AppDelegate.m | 10 distinct (12 written) | 10 | 0 |
| GCDAsyncUdpSocket#doPreSend (lines 3845–4005) | telegraph/Pods/CocoaAsyncSocket/Source/GCD/GCDAsyncUdpSocket.m | 26 | 26 | 0 |

- Every call is present with the right caller, callee, tier and line. That includes:
  - the macros `LogTrace` and `LogVerbose` (high);
  - `sendFilterBlock` (callback, unknown) inside nested dispatch blocks, folded into the method;
  - the `dispatch_*` system calls.
- There are no non-calls. Dot-syntax reads (`referenceImage.size`) correctly emit no edge.
- **Same-line repeats are collapsed.** Three written calls repeat a (caller, callee, line) that is already present, so the tool emits one edge for them:
  - `NSStringFromCGSize(referenceImage.size), NSStringFromCGSize(image.size)` at FBSnapshotTestController.m:140;
  - the two `length` sends at AppDelegate.m:52 and :59.
  - The output has no duplicate (caller, callee, file, line) key anywhere. I count these as spec gap SG5, not as misses.
- **Open-defect recall gaps** (CAPABILITIES): none of my three functions hit them.
  - `objc/13`: a C function call in another .m file is missed.
  - `objc/11`: file-scope macro uses in .m get no edge.
  - My scripted check found every call through a block-typed variable.

## Spec gaps (counted separately, not wrong): 6,339 edges
- **SG1, bare calls to C functions declared only in SDK/system headers: 5,662** (low, direct).
  - Examples: `NSLog(@"Picker was cancelled");` (1,880 in all), `NSStringFromClass(...)` 711, `UIApplicationMain(...)` 677, `CGRectMake(...)` 163, `dispatch_async(...)`, `htons(...)`, `SUN_LEN(...)`.
  - Open question (CAPABILITIES `objc/17`): is such a call direct low ("a bare name not found in the scan") or medium ("an import" / the prototype rule)?
  - Open question: when the SDK implements the name as a function-like macro (`htons`, `SUN_LEN`), is it call_type macro or an ordinary bare call?
- **SG2, out-of-scan function-like macros: 640** (medium, macro).
  - Examples: `XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);` (432), `NSAssert(...)` 105, `NSAssert1` 36, `MIN`, `MAX`, `NSLocalizedString`, `UI_USER_INTERFACE_IDIOM`.
  - Open question (`objc/17`): is a macro whose `#define` is not visible to the scan reported as call_type macro at medium, or as an ordinary bare call?
- **SG3, file-scope globals bound to block literals: 21** (10 callee edges, 11 body edges).
  - Example: `NSString *(^trimString)(NSString *) = ^(NSString *inputString){ … };` at file scope inside `@implementation`, called as `return trimString(inputString);`. The others are `trimWithOtherBlock`, `intToString`, `simpleBlock` and `executedOnlyOnce`.
  - The tool emits the call as `trimString`, low, direct. It gives the block body's calls the file's module ID as caller.
  - Open question: the named-nested-function rule covers locals bound to function literals, and the callback rule covers "a parameter, local variable or stored property holding a function". Neither names a C/ObjC file-scope global bound to a block literal. Is such a global a named function (with what ID, and is its body's caller that ID), or a variable holding a function (callback, unknown)?
- **SG4, a declaration whose initializer is an Xcode editor placeholder: 16.**
  - Example: `NSString *urlAsString = <# Place the URL of the web server here #>;` followed by `urlAsString = [urlAsString stringByAppendingString:@"?param1=First"];`. The tool emits `urlAsString.stringByAppendingString:`, low. It types the other locals in the same method normally.
  - Open question: SPEC judges code by what it does at runtime. It does not say how to judge a file that cannot compile because it contains `<#…#>` tokens. Should a declaration whose type is written but whose initializer is a placeholder still type its receiver under decision A?
- **SG5, repeated identical calls on one line (recall only, no edge count): 3 seen in the recall functions.**
  - Example: `NSStringFromCGSize(referenceImage.size), NSStringFromCGSize(image.size)`.
  - Open question: C6 speaks of an "edge multiset", but SPEC does not say whether two written invocations with the same caller, callee and line are two edges or one.

## Helper scripts
All are in `<fanout>/`:
- `h-oreilly-objc_r11_load.py`
- `h-oreilly-objc_r11_sample.py`
- `h-oreilly-objc_r11_defs.py`
- `h-oreilly-objc_r11_tiers.py`
- `h-oreilly-objc_r11_super.py`
- `h-oreilly-objc_r11_typedrecv.py`
- `h-oreilly-objc_r11_retrecv.py`
- `h-oreilly-objc_r11_retrecv2.py`
- `h-oreilly-objc_r11_retrecv3.py`
- `h-oreilly-objc_r11_idp.py`
- `h-oreilly-objc_r11_chain.py`
- `h-oreilly-objc_r11_selfarrow.py`
- `h-oreilly-objc_r11_blocks.py`
- `h-oreilly-objc_r11_forin.py`
- `h-oreilly-objc_r11_cfunc.py`
- `h-oreilly-objc_r11_recall.py`
- `h-oreilly-objc_r11_census.py`

Intermediate pickles are in the session scratchpad.
