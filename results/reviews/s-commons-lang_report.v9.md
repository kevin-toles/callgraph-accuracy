# Blind call-graph review: s-commons-lang (java), round 9

precision 48/50; census ≈99.40% (68 wrong of 11248 in-scope); recall: 0 missed of 101 real calls; 0 non-calls

## Scope
The tool JSON has 85,770 edges, all from `.java` files. In scope are the 11,248 edges whose `source_file` is under `src/main/java`. The 74,522 edges under `src/test/` are out of scope (path segment `test`). The in-scope edges come from 214 files. By confidence: high 5,902, medium 4,826, low 520, unknown 0. By call_type: method 9,581, constructor 1,169, implicit 498. There are no direct, callback or macro edges. I ignored `measured_accuracy`.

Precision sample: seed 9, stratified high 25 / medium 20 / low 5, spread over 32 files. 48 edges are correct, 0 are wrong and 2 are spec gaps (#1 `after.accept(t)`, FailableConsumer.java:89; #48 `((String) cs).indexOf(...)`, CharSequenceUtils.java:135). The scripted census found no sampled edge in any wrong pattern.

Recall used three functions in different files:
- `math.Fraction#addSub` (Fraction.java:520–558): 27 calls.
- `reflect.MethodUtils#getMatchingMethod` (MethodUtils.java:415–452): 53 calls.
- `ClassUtils#hierarchy(Class, Interfaces)` (ClassUtils.java:1208–1274, including the folded lambda and anonymous `Iterator` bodies): 21 calls.

All 101 calls have an edge. Four of them have the wrong callee: Fraction 546/549/553, pattern P5. Two are spec gaps: ClassUtils 1254/1269. No edge is a non-call. A separate check of the 125 `this(...)`/`super(...)` constructor-chain lines found an edge on every one.

Helper scripts are in the fanout folder, all prefixed `s-commons-lang_r9_`: `common`, `sample`, `implicit`, `const`, `low`, `dot`, `super`, `med`, `anon`, `fi`, `decl`, `recall`, `ctorchain`, `census`, `gaps`. `s-commons-lang_r9_census.py` prints every wrong edge and the union.

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| AnnotationUtils.java:57 | `setDefaultFullDetail(true);` (instance initializer of `new ToStringStyle() {…}`) | AnnotationUtils#TO_STRING_STYLE → AnnotationUtils#setDefaultFullDetail, medium, method | → builder.ToStringStyle#setDefaultFullDetail, high, method | wrong callee / wrong confidence | bare call in an anonymous subclass resolved against the enclosing class, not the anonymous class's scanned superclass; ID invented (C2) |
| AnnotationUtils.java:77 | `super.appendDetail(buffer, fieldName, value);` | AnnotationUtils#TO_STRING_STYLE → .appendDetail, low, method | → builder.ToStringStyle#appendDetail, high, method | wrong callee / wrong confidence | `super` in an anonymous subclass of a scanned class treated as out-of-scan |
| concurrent/AtomicInitializer.java:89 | `return (I) new AtomicInitializer(getInitializer(), getCloser());` | AtomicInitializer.Builder#get → concurrent.AtomicInitializer.Builder#getInitializer, medium, method | → concurrent.AbstractConcurrentInitializer.AbstractBuilder#getInitializer, high, method | wrong callee / wrong confidence | superclass `AbstractBuilder` is a member type inherited from `AbstractConcurrentInitializer` (not imported); ancestry not followed, ID invented |
| concurrent/BackgroundInitializer.java:126 | `return asThis();` | BackgroundInitializer.Builder#setExternalExecutor → concurrent.BackgroundInitializer.Builder#asThis, medium, method | → builder.AbstractSupplier#asThis, high, method | wrong callee / wrong confidence | same; the same call in AbstractConcurrentInitializer.java:90 resolves to AbstractSupplier#asThis, high |
| concurrent/locks/LockingVisitors.java:499 | `setReadLockSupplier(readWriteLock::readLock);` | ReadWriteLockVisitor.Builder#setLock → …ReadWriteLockVisitor.Builder#setReadLockSupplier, medium, method | → concurrent.locks.LockingVisitors.LockVisitor.LVBuilder#setReadLockSupplier, high, method | wrong callee / wrong confidence | superclass `LVBuilder` is a member type of the inherited `LockVisitor`; ancestry not followed |
| concurrent/locks/LockingVisitors.java:501 | `return super.setLock(readWriteLock);` | ReadWriteLockVisitor.Builder#setLock → .setLock, low, method | → concurrent.locks.LockingVisitors.LockVisitor.LVBuilder#setLock, high, method | wrong callee / wrong confidence | same root cause, `super` form |
| ArrayUtils.java:216 | `public static final int SAFE_MAX_ARRAY_LENGTH = Integer.MAX_VALUE - 8;` | ArrayUtils#<clinit> → ArrayUtils#SAFE_MAX_ARRAY_LENGTH, high, implicit | no edge (compile-time constant) | not a call | constant expression built from a qualified constant name not recognised |
| SystemUtils.java:2058 | `public static final String USER_HOME_KEY = SystemProperties.USER_HOME;` | SystemUtils#<clinit> → SystemUtils#USER_HOME_KEY, high, implicit | no edge (`SystemProperties.USER_HOME = "user.home"`) | not a call | same |
| time/FastDateFormat.java:90 | `public static final int FULL = DateFormat.FULL;` | FastDateFormat#<clinit> → FastDateFormat#FULL, high, implicit | no edge (`java.text.DateFormat.FULL` is a constant variable) | not a call | same |
| Range.java:321 | `return minimum.equals(range.minimum) &&` (`private final T minimum;`, `class Range<T>`) | Range#equals → T#equals, medium, method | → minimum.equals, low, method | wrong callee / wrong confidence | unbounded type variable used as a type name (SPEC decision A: "otherwise unconstrained, stays low") |
| ObjectUtils.java:1313 | `return obj == null ? Suppliers.get(supplier) : obj.toString();` (`<T> … final T obj`) | ObjectUtils#toString → T#toString, medium, method | → obj.toString, low, method | wrong callee / wrong confidence | same |
| text/StrBuilder.java:236 | `StrBuilder.this.append(cbuf);` | StrBuilder.StrBuilderWriter#write → this.append, low, method | → text.StrBuilder#append, high, method | wrong callee / wrong confidence | qualified `Outer.this` not resolved to the named enclosing type |
| math/Fraction.java:546 | `final BigInteger t = isAdd ? uvp.add(upv) : uvp.subtract(upv);` (`final BigInteger uvp = …` at 544) | Fraction#addSub → uvp.add, low, method | → java.math.BigInteger#add, medium, method | wrong callee / wrong confidence | `uvp`/`t` were declared `long` in the earlier `if` block (536–538); the second declaration in the sibling scope is not used, so the receiver stays untyped (`w.bitLength()` at 554, declared once, resolves) |
| math/Fraction.java:549 | `final int tmodd1 = t.mod(BigInteger.valueOf(d1)).intValue();` | Fraction#addSub → t.mod, low, method | → java.math.BigInteger#mod, medium, method | wrong callee / wrong confidence | same |
| function/FailableConsumer.java:89 | `after.accept(t);` (`final FailableConsumer<? super T, E> after`) | FailableConsumer#andThen → function.FailableConsumer#accept, high, method | undecided (CAPABILITIES java/18) | spec gap | functional-interface call |
| CharSequenceUtils.java:135 | `return ((String) cs).indexOf(searchChar, start);` | CharSequenceUtils#indexOf → .indexOf, low, method | undecided | spec gap | cast-expression receiver |
| ClassUtils.java:1254 | `walkInterfaces(currentInterfaces, nextSuperclass);` (method of an anonymous `Iterator`) | ClassUtils#hierarchy → ClassUtils#walkInterfaces, medium, method | undecided | spec gap | callee declared in an anonymous class body |

## Systematic patterns (scripted counts, `s-commons-lang_r9_census.py`; union 68)
1. **P2: compile-time constants get an implicit `<clinit>` edge: 19.** These are `static final` primitive or `String` fields whose initializer is a constant expression that uses a qualified constant name: `Integer.MAX_VALUE - 8`, `Integer.MAX_VALUE >> 3`, `SystemProperties.USER_HOME` (×5 keys), `StringUtils.EMPTY` (×2), `Modifier.PUBLIC | Modifier.PROTECTED | Modifier.PRIVATE`, `DateFormat.FULL/LONG/MEDIUM/SHORT` (×4 in FastDateFormat, ×4 in FastDatePrinter), and `TimeZones.GMT_ID + "[+-]\\d{1,2}:\\d{2}"`.
   - Every referenced field was checked by hand as a literal-initialized `static final`, or is a JDK constant variable. Pure-literal constants correctly have no edge.
   - **Reading applied:** the 2026-11-16 ruling's parenthetical lists "simple names of such fields". But it defines the constant expression by JLS 15.29, which also includes qualified names `TypeName.Identifier`, and javac inlines these through `ConstantValue` with no `<clinit>` code. So I counted these edges as wrong.
   - The excluded `IS_OS_UNIX = IS_OS_AIX || …` names fields initialized by calls, so its edge is correct.
2. **P1b: a member inherited through a scanned superclass that is an inherited member type gets an invented ID: 18.**
   - 15 are medium edges that name the calling type: `AtomicInitializer`/`AtomicSafeInitializer`/`BackgroundInitializer`/`LazyInitializer` `.Builder#getInitializer`/`#getCloser` (8), `BackgroundInitializer.Builder#asThis` (1), and the `LockingVisitors.*.Builder#setReadLockSupplier`/`#setWriteLockSupplier` (6).
   - 3 are `super.setLock(...)` calls left as `.setLock`, low.
   - The superclass is written as a simple name (`AbstractBuilder`, `LVBuilder`) that is visible only as a member type inherited from the outer class's superclass.
3. **P1a: anonymous subclass of a scanned class: 11.** These are in `AnnotationUtils#TO_STRING_STYLE = new ToStringStyle() {…}`.
   - The 10 instance-initializer setter calls are named `AnnotationUtils#set…`, medium. They should be `builder.ToStringStyle#set…`, high.
   - `super.appendDetail` is left as `.appendDetail`, low.
4. **P3: an unbounded type variable is used as a type name: 8.**
   - `T#getClass` ×5, `T#toString` ×2 and `T#equals` ×2, all medium. Sites: ArrayUtils:844, ObjectUtils:235/605/1313, Range:321/322, HashCodeBuilder:435 and TypeUtils:327.
   - Bounded type variables resolve correctly: `E extends Enum<E>` gives `java.lang.Enum#ordinal`, and `A extends Appendable` gives `java.lang.Appendable#append`.
5. **P4: qualified `Outer.this.m()` is left as `this.m`, low: 8.** All are in StrBuilder.java: 148, 195, 204 and 236/242/248/254/260. Each should be `text.StrBuilder#m`, high.
6. **P5: a local re-declared with a different type in a sibling block is left untyped: 4.** These are Fraction.java:546 (×2), 549 and 553.

## Missed-call patterns (recall)
- None in the three recall functions: 0 of 101 calls are missed.
- All 125 `this(...)`/`super(...)` lines have constructor edges.
- Anonymous subclasses of interfaces (`new Iterator<…>() {…}`) correctly have no constructor edge. Anonymous subclasses of classes (`new NumberStrategy(…) {…}`, `new ToStringStyle() {…}`, `new AbstractFormatCache<…>() {…}`) have one.

## Spec gaps (counted separately, not wrong; total 193)
1. **Functional-interface SAM call through a typed parameter, local or field: 119.** That is 80 high and 39 medium, from `s-commons-lang_r9_fi.py` (117) plus the 2 `DiffBuilder.SerializableSupplier#get` edges in `s-commons-lang_r9_gaps.py`.
   - Example: `after.accept(t);` with `final FailableConsumer<? super T, E> after`, given as `function.FailableConsumer#accept`, high. Another: `comparator.compare(element, minimum)` given as `java.util.Comparator#compare`, medium.
   - Question SPEC leaves open (CAPABILITIES `java/18`): is this the decision-A typed call `T#sam` (high or medium), or a call through a function value (`after`, callback, unknown)?
2. **Cast-expression receiver: 51.**
   - Examples: `((String) cs).indexOf(searchChar, start)`, `((MutableInt) obj).intValue()` and `((GenericArrayType) type).getGenericComponentType()`. The tool gives each as `.m`, low.
   - Question: "Typed call results" covers receivers that are a call result, an index or a literal, and decision A covers declarations. Does a cast expression `(T) x` type its receiver as `T`?
3. **Literal receiver: 19.**
   - Examples: `"Z".equals(pattern)`, `" \t\n\r\f".toCharArray()`, `String.class.equals(type)` and `TypeLiteral.class.getTypeParameters()`. The tool gives each as `.m`, low.
   - Question: "Typed call results" types a literal receiver "when its static type can be determined from declarations". A string or class literal's type comes from the language, not from a declaration. Is the call `java.lang.String#m` / `java.lang.Class#m` (medium), or `.m` (low)?
4. **Call of a method declared in an anonymous class body: 2.**
   - Example: `walkInterfaces(currentInterfaces, nextSuperclass);` and its recursive call. `walkInterfaces` is a private method of `new Iterator<Class<?>>() {…}` inside `ClassUtils#hierarchy`. The tool gives `ClassUtils#walkInterfaces`, medium.
   - Question: anonymous-class members fold into the enclosing function, so the method has no ID of its own. What is the callee of a call to it?
5. **`super.m()` where the scanned superclass inherits m from outside the scan: 1.**
   - Example: `return super.toString() + ' ' + Arrays.toString(chars);` in `StrMatcher.StringMatcher`. The superclass `StrMatcher` is scanned and does not define `toString`. The tool gives `.toString`, low.
   - Question: is the callee `.toString` (the `super` rule covers only a superclass that is not in the scan), or `StrMatcher#toString`, medium (the rule for members inherited from outside the scan)?
6. **Multi-catch (union-typed) parameter receiver: 1.**
   - Example: `catch (final ClassNotFoundException | IOException ex)` followed by `ex.getClass()`. The tool gives `ex.getClass`, low.
   - Question: decision A types a catch parameter by its declared type. Which type names the receiver when the declared type is a union?
