# grails-core call-graph review v3 (Groovy only)

Summary: precision 49/50; recall: 0 missed of 45 real calls; 0 non-calls

Scope: 1979 edges in non-test `.groovy` files across 66 files. I excluded `src/test*/` and `src/test-cli/`. The JSON has 11234 edges in total, 5553 of them in `.java` files, which are out of scope as callers (but they are used to resolve callees). By confidence: medium 985, high 611, low 383, unknown 0. By call_type: method 1515, constructor 234, implicit 169, direct 61.

**How precise is it?** The sample gives 49/50 = 98%, but a 50-edge sample has a 95% Wilson interval of about 89.5% to 99.6%, so on its own it cannot tell 95% from 99%. To narrow that, I also ran scripted counts over all 1979 edges. They found about 35 wrong edges (listed under Systematic patterns), which gives about **98.2%** (1944/1979). That count is a lower bound: it covers only the patterns I searched for. It excludes the spec-gap edges (99, not counted as errors).

## Precision sample (50 edges in 24 files: 15 high, 25 medium, 10 low; random seed 20261028; there are no unknown edges)

| # | file:line | verdict |
|---|---|---|
| H1 | core/util/IncludeExcludeSupport.groovy:32 | OK (`<clinit>` → static final field, implicit) |
| H2 | plugins/CoreGrailsPlugin.groovy:287 | OK (`RuntimeSpringConfigUtilities#reloadSpringResourcesConfig`, in-scan Java) |
| H3 | cli/ConfigReportCommand.groovy:243 | OK (same-class `#resolveGroup`) |
| H4 | plugins/CoreGrailsPlugin.groovy:209 | OK (constructor inside the registrar closure folds into `#beanRegistrar`) |
| H5 | boot/config/GrailsApplicationPostProcessor.groovy:256 | OK (typed field `GrailsPluginManager pluginManager`) |
| H6 | cli/ConfigReportCommand.groovy:152 | OK |
| H7 | compiler/injection/GlobalGrailsClassInjectorTransformation.groovy:295 | OK (`GrailsASTUtils#addAnnotationOrGetExisting`; same-package Java, line of the method name) |
| H8 | core/exceptions/DefaultErrorsPrinter.groovy:117 | OK |
| H9 | boot/GrailsBanner.groovy:89 | OK (`<init>` → instance field `bannerPaddingTop`, implicit) |
| H10 | boot/config/tools/ProfilingGrailsApplicationPostProcessor.groovy:47 | OK (`super(...)` → `GrailsApplicationPostProcessor#<init>`, constructor) |
| H11 | cli/ApplicationContextCommandRegistry.groovy:46 | OK |
| H12 | compiler/injection/EnhancesTraitTransformation.groovy:58 | OK (`<clinit>` → private static final field) |
| H13 | boot/config/GrailsApplicationPostProcessor.groovy:450 | OK (but only because a field `lifeCycle` of the same type exists; see pattern 1) |
| H14 | validation/ConstraintEvalUtils.groovy:69 | OK (`grails.config.Config#getProperty`; `Config.groovy` declares the overload) |
| H15 | boot/config/GrailsApplicationPostProcessor.groovy:292 | OK |
| M1 | grails/util/GrailsStringUtils.groovy:220 | OK (bare `hasLength`, inherited from Spring `StringUtils`, so `GrailsStringUtils#hasLength` medium) |
| M2 | compiler/injection/ApplicationClassInjector.groovy:124 | OK (`org.codehaus.groovy.ast.ClassNode#getMethod`) |
| M3 | compiler/injection/GlobalGrailsClassInjectorTransformation.groovy:411 | OK (`List<Statement> statements` → `List#every`) |
| M4 | compiler/injection/FactoriesFileWriter.groovy:117 | OK (`Set<String> names` → `Set#join`) |
| M5 | compiler/injection/GlobalGrailsClassInjectorTransformation.groovy:394 | OK (`AnnotationNode#<init>`) |
| M6 | core/util/IncludeExcludeSupport.groovy:48 | OK (typed parameter `List<T> includes`) |
| M7 | cli/ApplicationContextCommandRegistry.groovy:246 | OK (field `Map<String, ApplicationCommand> commands`) |
| M8 | grails/util/TypeConvertingMap.groovy:44 | OK |
| M9 | core/cfg/GroovyConfigPropertySourceLoader.groovy:67 | OK (`org.grails.config.NavigableMap` is imported and not in this scan) |
| M10 | cli/ApplicationCommand.groovy:49 | OK (inner call of the nested chain, on its own line; `GrailsNameUtils` is outside the scan) |
| M11 | cli/template/TemplateRendererImpl.groovy:207 | OK |
| M12 | boot/config/tools/ClassPathScanner.groovy:244 | OK (call inside GString in the constructor; `String urlStr`) |
| M13 | boot/config/GrailsApplicationPostProcessor.groovy:422 | OK |
| M14 | boot/GrailsBanner.groovy:603 | OK (`String itemSeparator` / `String item` → `String#size`, both present) |
| M15 | compiler/injection/CompileStaticArtefactInjector.groovy:74 | OK (caller is the field `#ARTEFACT_CLASS_NODE`) |
| M16 | compiler/injection/ApplicationClassInjector.groovy:129 | OK |
| M17 | cli/template/TemplateRendererImpl.groovy:172 | OK |
| M18 | cli/template/TemplateRendererImpl.groovy:208 | OK |
| M19 | boot/config/tools/ClassPathScanner.groovy:267 | OK (field `final Class applicationClass`) |
| M20 | cli/ConfigReportCommand.groovy:184 | OK |
| M21 | compiler/DynamicFinderTypeCheckingExtension.groovy:42 | OK (bare call outside a closure, inherited from external `TypeCheckingDSL` → `#methodNotFound` medium) |
| M22 | plugins/CoreGrailsPlugin.groovy:279 | OK (`def xmlBeans = new DefaultListableBeanFactory()`) |
| M23 | core/io/support/GrailsFactoriesLoader.groovy:92 | OK |
| M24 | core/cfg/GroovyConfigPropertySourceLoader.groovy:43 | OK (caller is the field `#loadedFiles`) |
| M25 | plugins/CoreGrailsPlugin.groovy:180 | OK (closure parameter `BeanRegistry registry`) |
| L1 | boot/GrailsBanner.groovy:555 | OK (`*.size()?.max()` → `.max`) |
| L2 | cli/ConfigReportCommand.groovy:125 | OK |
| L3 | plugins/CoreGrailsPlugin.groovy:94 | OK (`bean(..).primary()` → `.primary`; the caller is the closure field `#beans`) |
| L4 | cli/template/TemplateRendererImpl.groovy:229 | OK |
| L5 | boot/GrailsBanner.groovy:334 | OK (`def includedVersions`) |
| L6 | compiler/injection/EnhancesTraitTransformation.groovy:112 | OK (`cNode.name.endsWith` → `name.endsWith`) |
| L7 | cli/ConfigReportCommand.groovy:296 | OK (each call in the chain is on its own line) |
| L8 | core/io/support/GrailsFactoriesLoader.groovy:78 | **wrong callee and confidence** (typed for-loop variable) |
| L9 | compiler/injection/GlobalGrailsClassInjectorTransformation.groovy:580 | OK per spec (`new PluginAstReader().readPluginInfo` has a computed receiver → `.readPluginInfo`) |
| L10 | compiler/CriteriaTypeCheckingExtension.groovy:38 | OK per spec (bare `newScope()` inside the `setup {}` closure; closure-delegate spec gap) |

## Mismatch table

| file:line | source line | tool said (caller → callee, conf, type) | correct per spec | category / root cause |
|---|---|---|---|---|
| GrailsFactoriesLoader.groovy:78 (sample L8) | `results.add(clazz.getDeclaredConstructor().newInstance())` (loop head line 77: `for (Class<? extends T> clazz : loadFactoryClasses(...))`) | `...GrailsFactoriesLoader#loadFactories` → `clazz.getDeclaredConstructor`, low, method | `Class#getDeclaredConstructor`, medium | wrong callee + confidence: the declared type of the for-loop variable is ignored |
| GrailsFactoriesLoader.groovy:94 (recall) | `results.add(hasArguments ? clazz.newInstance(arguments) : clazz.getDeclaredConstructor().newInstance())` (line 93: `for (Class<? extends T> clazz : ...)`) | `#loadFactoriesWithArguments` → `clazz.newInstance` and `clazz.getDeclaredConstructor`, low | `Class#newInstance`, `Class#getDeclaredConstructor`, medium | wrong callee + confidence: typed for-loop variable ignored |
| CompileStaticArtefactInjector.groovy:129 / :134 (recall) | `if (!property.isStatic() && property.getInitialExpression() instanceof ClosureExpression)` (line 128: `for (PropertyNode property : classNode.getProperties())`); line 134 likewise with `for (FieldNode field : ...)` | `#hasClosureFieldTag` → `property.isStatic`, `property.getInitialExpression`, `field.isPublic`, `field.isStatic`, `field.getInitialExpression`, low | `org.codehaus.groovy.ast.PropertyNode#isStatic` etc., `org.codehaus.groovy.ast.FieldNode#isPublic` etc., medium | wrong callee + confidence: typed for-loop variable ignored |
| ConfigReportCommand.groovy:214 (recall) | `jsonData = (Map<String, Object>) slurper.parse(stream)` (line 208: `JsonSlurper slurper = new JsonSlurper()`) | `#loadPropertyMetadata` → `.parse`, low | `groovy.json.JsonSlurper#parse`, medium | wrong callee + confidence: a prefix cast `(T) recv.m()` drops the named receiver |
| ConfigReportCommand.groovy:240, 241, 243 (recall) | `String description = propertyMap.get('description') instanceof String ? (String) propertyMap.get('description') : ''` (`Map<String, Object> propertyMap`, line 231) | `#loadPropertyMetadata` → `Map#get` medium (1st call, correct) **and** `.get`, low (2nd call, after `(String)`) | both `Map#get`, medium | wrong callee + confidence: a prefix cast drops the receiver |
| GrailsApplicationPostProcessor.groovy:179 | `for (cls in classes) {` (line 178 ends `... as Set<String>`) | `#registerRemainingApplicationClasses` → `grails.boot.config.GrailsApplicationPostProcessor#for`, medium, method | no edge | not a call: a `for` loop following a line that ends in the generic coercion `as Set<String>` is read as a call |
| GrailsApplicationPostProcessor.groovy:180 | `if (!registeredClassNames.contains(cls.name)) {` (line 178: `Set<String> registeredClassNames = ... as Set<String>`) | `→ registeredClassNames.contains`, low | `Set#contains`, medium | wrong callee + confidence: the typed local is lost (same declaration as the row above) |
| GrailsApplicationLifeCycle.groovy:55 | `default BeanRegistrar beanRegistrar() {` (Groovy interface default method) | `grails.core.GrailsApplicationLifeCycle#<init>` → `...#default`, medium, method **and** → `...#beanRegistrar`, medium, method | no edges (this is a method declaration) | not a call (2 edges): the `default` method declaration is read as a field initializer containing calls |
| GrailsApplicationPostProcessor.groovy:310 | `BeanRegistrar registrar = lifeCycle.beanRegistrar()` | → `grails.core.GrailsApplicationLifeCycle#beanRegistrar`, medium | same callee, **high** (defined at GrailsApplicationLifeCycle.groovy:55) | wrong confidence: the `default` method is not indexed as a definition |
| CommandFactoriesTransformation.groovy:87; ApplicationClassInjector.groovy:130; GlobalGrailsClassInjectorTransformation.groovy:125 | `URL url = GrailsASTUtils.getSourceUrl(source)` | → `org.grails.compiler.injection.GrailsASTUtils#getSourceUrl`, medium | same callee, **high** (`public static URL getSourceUrl(SourceUnit source)` at GrailsASTUtils.java:1629; Java→Java calls to it are high) | wrong confidence: this in-scan Java method is not matched from Groovy, although every other `GrailsASTUtils` method is |
| GroovyConfigPropertySourceLoader.groovy:80 | `... [${e.getClass().name}] ...` inside `} catch (Throwable e) {` (line 78) | → `e.getClass`, low | `Throwable#getClass`, medium | wrong callee + confidence: the catch parameter's type is ignored |
| ApplicationContextCommandRegistry.groovy:242 | `type.protectionDomain?.codeSource?.location?.toExternalForm() ?: 'unknown'` | → `.toExternalForm`, low | `location.toExternalForm`, low (last receiver segment, as for `a.b.m()`) | wrong callee: safe navigation after a property chain gives the computed form |
| MapBasedSmartPropertyOverrideConfigurer.groovy:77 | `grailsApplication?.config?.getProperty('beans', Map)` | → `.getProperty`, low | `config.getProperty`, low | wrong callee: same cause as the row above |
| GrailsAutoConfiguration.groovy:64 | `list.add(GroovyAwareAspectJAwareAdvisorAutoProxyCreator)` (line 62: `List<Class<?>> list = (List<Class<?>>) obj`; line 63 `list.add(...)` → `List#add` medium) | → `.add`, low | `List#add`, medium | wrong callee + confidence: the second call on a local declared with a nested-wildcard generic cast loses the receiver |
| GrailsFactoriesLoader.groovy:100 (recall) | `a?.getClass()?.name <=> b?.getClass()?.name` (closure params `T a, T b`; `T` is the method's type parameter) | → `T#getClass`, medium (×2) | the spec does not say how to name a receiver typed by a type variable (erasure would give `Object#getClass`) | spec gap |
| e.g. GrailsApp.groovy:116 | `log.info('Application starting in environment: {}', environment.getName())` (`@Slf4j` class, no declared `log` field) | → `log.info`, low | the spec does not cover fields added by an AST transform (`@Slf4j`) | spec gap |
| e.g. DomainMappingTypeCheckingExtension.groovy:64 | `withTypeChecker { visitClosureExpression(mappingProperty.initialExpression) }` | → `visitClosureExpression`, low, direct | the spec does not say how to name bare calls that Groovy resolves through a closure's delegate | spec gap (unchanged) |

## Recall (3 functions)

- **`org.apache.grails.core.cli.ConfigReportCommand#loadPropertyMetadata`** (ConfigReportCommand.groovy:204-249): 28 real calls, 0 missed, 0 non-calls.
  - Correct: the `ConfigReportCommand.classLoader.getResources` chain, which gives `classLoader.getResources`, low, as the spec requires.
  - Correct: the typed locals, which give `Enumeration#hasMoreElements`/`#nextElement`, `URL#openStream`, `InputStream#close`, `Map#putAll`/`#get`/`#keySet`, `List#add`/`#sort`.
  - Correct: the nested-class constructors `ConfigReportCommand.ConfigPropertyMetadata#<init>` and `.MetadataResult#<init>`, high.
  - 4 edges have the wrong callee, all from the prefix-cast pattern: lines 214, 240, 241 and 243.
- **`org.grails.core.io.support.GrailsFactoriesLoader#loadFactoriesWithArguments`** (lines 90-104): 10 real calls, 0 missed, 0 non-calls.
  - Correct: the chained `.newInstance` on `getDeclaredConstructor()` is computed, and `OrderComparator#sort` is qualified through its import.
  - 2 edges are wrong (typed for-loop variable): `clazz.newInstance` and `clazz.getDeclaredConstructor`.
  - 2 edges are `T#getClass` (spec gap).
- **`org.grails.compiler.injection.CompileStaticArtefactInjector#hasClosureFieldTag`** (lines 127-139): 7 real calls, 0 missed, 0 non-calls. `ClassNode#getProperties` and `ClassNode#getFields` are correct (typed parameter). All 5 calls on the loop variables `property` and `field` are wrong in the same way: bare `recv.m` at low.

## Systematic patterns

I counted each pattern over all 1979 in-scope edges with a script. The counts are ordered by how many edges a fix would correct.

1. **The declared type of a for-loop variable is ignored. 15 edges.** The pattern is `for (Type v : xs)` or `for (Type v in xs)`. Calls on `v` come out as `v.m`, low, when they should be `Type#m`, medium or high. There are 16 such call edges in all; 1 of them is a legitimately computed `.newInstance`, which leaves the 15. The only typed loop variables that do resolve (4 edges, `for (GrailsApplicationLifeCycle lifeCycle in lifeCycleBeans)`) are in a class that also has a field `lifeCycle` of the same type. Fixing this alone would move about 0.8 points of precision.
   - 5 edges in CompileStaticArtefactInjector
   - 3 edges in GrailsFactoriesLoader on `Class<? extends T> clazz`
   - 1 edge on `factoryName`
   - 1 edge on `envKey`
   - 3 edges on `GrailsPlugin plugin`, in GrailsApp and GrailsApplicationPostProcessor
   - 2 edges on `PersistenceContextInterceptor i`
2. **A prefix cast `(T) recv.m()` drops the named receiver. 8 edges**, plus 1 related edge (GrailsAutoConfiguration:64), so 9 in all. The output is the computed form `.m`, low. When the same call appears without a cast on the same line, it resolves (`Map#get` vs `.get` on ConfigReportCommand:240/241/243). The other cases:
   - `(ConfigurableEnvironment) applicationContext.getEnvironment()`
   - `(Map<String, Object>) slurper.parse(stream)`
   - `(PluginDiscovery) applicationContext.getBean(...)` ×2
   - `(T) all.get(0)`
3. **Groovy interface `default` methods are misparsed. 3 edges.** At GrailsApplicationLifeCycle.groovy:55 there are 2 non-call edges from `#<init>` (`#default`, `#beanRegistrar`). The method is then not indexed as a definition, so the one real call to it (GrailsApplicationPostProcessor:310) is medium instead of high. It is the only `default` method in the in-scope Groovy source.
4. **`GrailsASTUtils#getSourceUrl` is medium from Groovy. 3 edges.** It is defined in the in-scan `GrailsASTUtils.java`. The same callee is high from Java, and all of the other 18 `GrailsASTUtils` methods called from Groovy are high, so this is one unmatched member, not a general Java-resolution failure.
5. **A line ending in a generic coercion `as Set<String>`, followed by a `for (` line. 2 edges:** a non-call `#for` edge (GrailsApplicationPostProcessor:179), and the loss of the declared type of `registeredClassNames` on the next line. Of the 7 in-scope lines ending in `as X<...>`, only this one is followed by `for (`, and it is the only `#for` / keyword callee in the whole output (including Java).
6. **Safe navigation after a property chain gives the computed form. 2 edges:** `a.b?.m()` gives `.m`, when it should be `b.m`. Simple `x?.m()` is now fixed (0 remaining).
7. **The declared type of a catch parameter is ignored. 1 edge** (`catch (Throwable e)` → `e.getClass`).

Total of patterns 1-7: about 35 wrong edges of 1979, so about 98.2% precision. The order to fix them, by edges moved: patterns 1 and 2 (24 edges together), then 3 and 4 (3 each), then the rest.

Spec gaps. I do not count these as errors.
- **`@Slf4j` `log`**: 33 low `log.*` edges.
- **Bare calls inside closures resolved through the delegate**: 61 low `direct` edges. All 61 are inside closures (TypeCheckingDSL scopes, `Thread.start {}`, MarkupBuilder `resources {}`, BeanBuilder `bean(...)`, `.tap {}`).
- **Receivers typed by a type parameter** (`T#getClass`): 5 edges.

## Previous findings

Mismatch-table rows of the v2 report:

| v2 row | status | evidence |
|---|---|---|
| Settings.groovy:255 / :383 interface field → `<init>` | **fixed** | both now `grails.config.Settings#<clinit>` → field, implicit, high |
| WhereQueryTypeCheckingExtension.groovy:42 `methodNotFound` bare low | **fixed** | → `org.grails.compiler.WhereQueryTypeCheckingExtension#methodNotFound`, medium |
| TemplateRendererImpl.groovy:220 `f?.exists()` → `.exists` | **fixed** | → `org.grails.io.support.Resource#exists`, medium. Correction to v2: v2 said "high (node exists)", but `org.grails.io.support.Resource` has no source file in this scan; the node list also contains external IDs. So medium is correct. |
| GlobalGrailsClassInjectorTransformation.groovy:377 bare `getClass` | **fixed** | → `...GlobalGrailsClassInjectorTransformation#getClass`, medium |
| TypeConvertingMap.groovy:36 / :40 `AbstractTypeConvertingMap#<init>` unqualified medium | **fixed** | → `grails.util.AbstractTypeConvertingMap#<init>`, high |
| DomainMappingTypeCheckingExtension.groovy:64 closure-delegate bare call (spec gap) | **still present (spec gap)** | still `visitClosureExpression`, low, direct |
| TemplateRendererImpl.groovy:88 `@Delegate` methods (spec gap, 22 bare low edges) | **fixed under the new bare-call rule** | 0 bare low edges remain in the file; line 88 → `...TemplateRendererImpl#projectPath`, medium |

Systematic patterns of the v2 report:

1. **Interface fields get `<init>`: fixed.** In Settings.groovy, all 74 implicit edges now come from `grails.config.Settings#<clinit>` (74 → 0 wrong).
2. **Calls to members inherited from an external base stay bare and low: fixed outside closures.** Bare low `direct` edges went from 186 to 61, and all 61 that remain are inside closures (spec gap above). Specifically:
   - the TypeCheckingDSL calls at `run()` top level are now `Type#m` medium: `methodNotFound` 8, `setup` 6, `finish` 6, `unresolvedProperty` 2, `makeDynamic` 1
   - bare `getClass`: 6 → 0
   - `CustomSafeConstructor:55` → `#createDefaultList`, medium
3. **Same-package Java types not resolved from Groovy: fixed.**
   - Unqualified medium callees whose type exists in the scan: 23 → 0.
   - TypeConvertingMap's inherited calls (19 bare low in v2): 0 low remain, and 21 edges now resolve to `grails.util.AbstractTypeConvertingMap#getBoolean/getChar/getInt/...`, high.
   - What remains are 3 edges to `GrailsASTUtils#getSourceUrl` (new pattern 4). This is one unmatched member, not the old cause.
4. **Static imports not resolved: fixed.** Bare low static-import names: 10 → 0. ApplicationClassInjector:120 now gives 7 `org.codehaus.groovy.ast.tools.GeneralUtils#constX/classX/callX/stmt/args/propX` edges, medium.
5. **Safe navigation loses the receiver: mostly fixed.** The simple `x?.m()` form: 5 → 0. TemplateRendererImpl:220 and :165 give `Resource#exists`, and FileSystemInteractionImpl:137 gives `File#exists`. A residual variant remains, safe navigation after a property chain (`a.b?.m()`, 2 edges, new pattern 6).

New in v3, and not reported in v2 (they may have existed before):
- typed for-loop variables (15)
- prefix casts (9)
- `default` interface methods (3)
- `getSourceUrl` (3)
- the `as Generic<T>` + `for` misparse (2)
- catch parameters (1)
