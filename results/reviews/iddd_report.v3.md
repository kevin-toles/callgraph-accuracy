# iddd (C#) call-graph review, v3

precision 50/50; census ≈99.5% (7 wrong of 1487 in-scope); recall: 0 missed of 32 real calls; 0 non-calls

**Scope.** All 1487 edges are in scope: they come from `.cs` files, and the repo has no test, vendor or generated directories. They span 113 of 269 `.cs` files.
- By confidence: 1050 high, 308 medium, 129 low, 0 unknown.
- By call type: 1057 method, 420 constructor, 10 implicit.

**Sample.** I drew 50 edges with `random.seed(20261028)`, stratified as 30 high, 11 medium and 9 low. The sample covers 32 files. Scripts are in the fanout folder with the `iddd_v3_` prefix.

**Sample result.** All 50 edges are correct per spec. Two of them (PasswordService.cs:31 and DiscussionDescriptor.cs:19) are `<clinit>` → `const` implicit edges. That case is a spec gap (see Spec gaps), so I did not count those two as errors.

**Census.** I checked the whole repo by script (scripts `iddd_v3_census*.py`, `iddd_v3_missed.py`, `iddd_v3_spurious.py`, `iddd_v3_callers2.py`, `iddd_v3_typecheck.py`, `iddd_v3_typevar.py`, `iddd_v3_gaps.py`):
- No edge lacks its callee name on its line.
- There are no duplicate edges, no empty callers and no generic arguments in any ID.
- 1284 edges could be matched to their enclosing member by brace scan, and none has a wrong caller.
- A repo-wide scan of call sites found no call without an edge. The scan's only 11 hits are declarations.

**Recall.** I checked three functions:
- `PasswordService#GenerateStrongPassword`: 12 of 12 calls.
- `TenantProvisioningService#ProvisionTenant`: 8 of 8 calls, including the chained `.Publish` reported on its own line, 155.
- `ResultSetObjectMapper#MapResultToType`: 12 of 12 calls. `typeof(T)` and `default(T)` are correctly not reported.

## Mismatch table

| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| iddd_identityaccess/Domain.Model/Identity/Group.cs:104 | `if (this.GroupMembers.Add(group.ToGroupMember()) && (!this.IsInternalGroup))` | `…Identity.Group#AddGroup` → `.ToGroupMember`, low, method | `SaaSOvation.IdentityAccess.Domain.Model.Identity.Group#ToGroupMember`, high. The parameter is declared `Group group` (line 98), and the method is defined at line 228. | wrong callee / wrong confidence | Receiver named `group` (a C# contextual keyword) is treated as computed |
| iddd_identityaccess/Domain.Model/Identity/Group.cs:138 | `if (this.GroupMembers.Remove(group.ToGroupMember()) && (!this.IsInternalGroup))` | `…Group#RemoveGroup` → `.ToGroupMember`, low, method | `…Identity.Group#ToGroupMember`, high. The parameter is declared `Group group` (line 132). | wrong callee / wrong confidence | same |
| iddd_identityaccess/Application/IdentityApplicationService.cs:38 | `group.AddUser(user);` | `…IdentityApplicationService#AddUserToGroup` → `.AddUser`, low, method | `group.AddUser`, low. The receiver is `var group = GetExistingGroup(...)`, a named receiver of unknown type. | wrong callee | same |
| iddd_identityaccess/Application/IdentityApplicationService.cs:127 | `return group.IsMember(user, this.groupMemberService);` | → `.IsMember`, low | `group.IsMember`, low | wrong callee | same |
| iddd_identityaccess/Application/IdentityApplicationService.cs:196 | `group.RemoveUser(user);` | → `.RemoveUser`, low | `group.RemoveUser`, low | wrong callee | same |
| iddd_common/Domain.Model/ValueObject.cs:114 | `return base.CompareTo(other);` | `SaaSOvation.Common.Domain.Model.ComparableValueObject#CompareTo` → `.CompareTo`, low, method | `SaaSOvation.Common.Domain.Model.ComparableValueObject#CompareTo`, high. The base class `ComparableValueObject` is in the scan and defines `protected int CompareTo(ComparableValueObject other)` at line 71. `.m` is only for a `super` whose class is outside the scan. | wrong callee / wrong confidence | `base.` is always treated as an out-of-scan super |
| iddd_common/Domain.Model/DomainEventPublisher.cs:70 | `var eventType = domainEvent.GetType();` | `…DomainEventPublisher#Publish` → `T#GetType`, medium, method | `SaaSOvation.Common.Domain.Model.IDomainEvent#GetType`, medium. The method is `Publish<T>(T domainEvent) where T : IDomainEvent`, and the spec says "A type variable resolves to its declared bound". | wrong callee | Type parameter not replaced by its bound |

## Systematic patterns

1. **A receiver named `group` becomes a computed receiver (`.m`).** 5 edges. These are all the `group.<m>(` call sites in the repo: Group.cs:104 and :138, and IdentityApplicationService.cs:38, :127 and :196.
   - On the two typed parameters in Group.cs, the callee also loses its high resolution.
   - No other contextual-keyword receiver is affected. I scanned for `value`, `select`, `from`, `where`, `var`, `add`, `get`, `set` and others, and found 0 other call sites.
2. **A `base.m()` call on an in-scan base class gives `.m` low.** 1 edge (ValueObject.cs:114). This is the only `base.<m>(` call in the repo.
3. **A receiver typed by a generic type parameter keeps the parameter name (`T#m`) instead of its bound.** 1 edge (DomainEventPublisher.cs:70). It is the only edge whose callee type is a type parameter.

Census total: 7 wrong of 1487, so census precision = 1 − 7/1487 ≈ 99.53%.

## Spec gaps (not counted as wrong)

1. **Class-level `const` fields get `Type#<clinit>` → `Type#FIELD` implicit edges.** 9 edges: PasswordService ×5, DiscussionDescriptor, NotificationLogFactory, Group and GroupMemberService. C# constants are compile-time literals with no runtime initializer. The spec's "Non-lazy initializers also get an implicit edge" does not say whether `const` counts. Method-local `const string Format = …` lines correctly get no edge. The one non-const field initializer (EventSerializer.cs:14, a static `Lazy<T>` field) gets its implicit edge plus constructor edges with caller `EventSerializer#instance`.
2. **A receiver whose type is written but not as a declaration gives `recv.m` / `.m` low.** The spec's decision A names declarations and `= new T(...)`. It does not cover:
   - `new T(...).m()`: 7 edges. Examples: `new PasswordService().GenerateStrongPassword()` → `.GenerateStrongPassword`, and `new NotificationLogFactory(this.eventStore)` followed by `.CreateCurrentNotificationLog()` on the next line.
   - `var x = obj as T;`: 2 edges (Entity.cs:36 `other.GetIdentityComponents`, ValueObject.cs:35 `vo.GetEqualityComponents`).
   - `foreach (var x in typedCollection)`: 7 edges. The spec lists "for-loop variable", but here the type is inferred, not declared.
   - A static property chain on an external type: 1 edge (MD5EncryptionService.cs:47 `Encoding.Default.GetBytes` → `Default.GetBytes`).

   Locals declared `var x = someCall()` (68 low edges) have no written type, and the tool's `x.m` low is consistent with the spec.
3. **How external C# types are qualified (carried over).** Of the 308 medium edges:
   - 95 are `System.`-qualified: the keyword types String, Object, Char, Int64 and Byte.
   - 202 name a bare BCL or library type: `InvalidOperationException` 50, `HashSet` 30, `List` 19, `IDataReader` 19, `ISet` 14, and others.

   LINQ extension methods are attributed to the receiver type: `ISet#Where`, `List#FirstOrDefault`, `HashSet#ToArray` and others, about 20 edges. The spec does not cover namespace `using`s or extension methods.
4. **A generic and a non-generic class with the same name share one ID.** Because generic arguments are dropped, `ComparableValueObject<T>` and `ComparableValueObject` (both in ValueObject.cs) are both `SaaSOvation.Common.Domain.Model.ComparableValueObject`. The caller of ValueObject.cs:114 is therefore indistinguishable from its correct callee.

## Previous findings

Mismatch table rows of v2:

| v2 row | status | evidence |
|---|---|---|
| AbstractQueryService.cs:33 `new ResultSetObjectMapper<T>(…)` → `ResultSetObjectMapper<T>#<init>`, medium | **Fixed** | Now `SaaSOvation.Common.Port.Adapters.Persistence.ResultSetObjectMapper#<init>`, high. The same holds at :51 and at ResultSetObjectMapper.cs:91, where the following `mapper.MapResultToType()` (line 93) also resolves high through `var mapper = new …`. |
| DomainEventPublisher.cs:114 `new DomainEventSubscriber<IDomainEvent>(handle)` → unqualified, medium | **Fixed** | Now `SaaSOvation.Common.Domain.Model.DomainEventPublisher.DomainEventSubscriber#<init>`, high. Likewise ValueObject.cs:50 → `…ComparableValueObject.NonGenericComparable#<init>`, high. |
| BacklogItem.cs:49 `new List<Task>()` → `List<Task>#<init>` | **Fixed** | Now `List#<init>`, medium. 0 edges have `<…>` in any caller or callee ID. |
| ProductOwnerId.cs:31 `this.Id.Split(':')` → `Id.Split`, low | **Fixed** | Now `System.String#Split`, medium, at :31 and :39. |

Systematic patterns of v2:

1. **Generic type arguments kept in constructor IDs.** Fixed. 34 → 0. The 5 in-scan generic types now resolve to qualified high IDs. The 93 medium constructor edges all use bare generic-free IDs (`HashSet#<init>` 12, `List#<init>` 9, …).
2. **`this.Prop.m()` on a property inherited from an in-scan base keeps the unknown-receiver form.** Fixed. 2 → 0. Only 1 `.`-prefixed callee remains on a `this.<x>.<m>(` line: Identity.cs:49 `this.GetType().GetHashCode()`, which is a correct computed receiver. There are 36 `.`-prefixed callees in total, the same as in v2.
3. **Spec gap: qualifying external C# types and LINQ extension methods.** Still present and unchanged in kind: 95 `System.`-qualified versus 202 bare-typed medium edges. It is still not covered by the current spec, so it is not counted (Spec gaps item 3).

The fixes carried from v1 have not regressed:
- 0 `direct` edges.
- 0 empty callers.
- 52 constructor edges on `: base(…)` / `: this(…)` lines.
- Keyword static calls are all `System.*`, medium.
- All 22 `#GetType` callees are medium. One of them is the `T#GetType` error above. The single low `GetType` edge is `argument.GetType`, which is correct.

The 3 wrong patterns in this report (`group` receiver, `base.m` on an in-scan base, type-parameter receiver) were not reported in v2. I could not check whether they were present in v2's input: that JSON predates the current `iddd.v2.json` and is not separately kept. The tier counts moved from 1045/311/131 to 1050/308/129 because of the fixes above.
