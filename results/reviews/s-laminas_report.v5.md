# s-laminas (php) blind call-graph review, round 5

precision 49/50; census ≈99.5% (5 wrong of 1016 in-scope); recall: 0 missed of 68 real calls; 0 non-calls

## Scope
Tool output `<scans>/final12-A/s-laminas.v2.json` has 4075 edges, all from `.php` files. 3059 are under `test/` and out of scope. The 1016 in-scope edges come from 67 files under `src/`. There is no `vendor/` directory, so every `Laminas\EventManager`, `Laminas\ServiceManager`, `Laminas\View`, `Interop\Container` etc. type is outside the scan.
- Confidence: high 315, medium 413, low 287, unknown 1.
- call_type: method 747, direct 152, constructor 116, callback 1.
- By pair: low/method 286, high/method 261, medium/method 200, medium/direct 151, medium/constructor 62, high/constructor 54, unknown/callback 1, low/direct 1.

The precision sample has 50 edges, seed `20261113`: high 15, medium 20, low 14, unknown 1 (the only edge in that tier). It covers 28 files. 49 edges are correct. 1 is a spec gap: #11, `new PluginManager(...)` reported as `Laminas.Mvc.Controller.PluginManager#<init>` high, but PluginManager inherits its constructor from the out-of-scan `AbstractPluginManager` (see Spec gaps). No sampled edge is wrong.

Recall checked 3 functions, 68 real calls, all found:
- `DispatchListener#onDispatch`: 26 calls
- `Forward#dispatch`: 17 calls
- `ViewManager#onBootstrap`: 25 calls

I also compared written calls with edges on every `src/` line, about 1023 calls. Edge counts matched written calls on every line except the 7 dynamic calls listed below, so there are no extra or non-call edges. The `measured_accuracy` field in the JSON was ignored.

Helper scripts are in the fanout folder with prefix `s-laminas_r5_` (load, sample, ctx, types, census, typed, recvtype, lines, miss, propalias, ctor, recall).

## Mismatch table
| file:line | source line | tool said (caller → callee, confidence, call_type) | correct per spec | category | root cause |
|---|---|---|---|---|---|
| src/Service/HttpDefaultRenderingStrategyFactory.php:23 | `$config   = $this->getConfig($container);` | `Laminas.Mvc.Service.HttpDefaultRenderingStrategyFactory#__invoke` → `Laminas.Mvc.Service.HttpDefaultRenderingStrategyFactory#getConfig`, medium, method | `Laminas.Mvc.Service.HttpViewManagerConfigTrait#getConfig`, high, method (the method is defined only in the scanned trait `HttpViewManagerConfigTrait`, pulled in by `use HttpViewManagerConfigTrait;`; the trait method is in `nodes`) | wrong callee / wrong confidence | trait method named on the using class (open defect php/17); the invented ID breaks C2 |
| src/Service/HttpExceptionStrategyFactory.php:22 | `$config   = $this->getConfig($container);` | `…HttpExceptionStrategyFactory#__invoke` → `Laminas.Mvc.Service.HttpExceptionStrategyFactory#getConfig`, medium, method | `Laminas.Mvc.Service.HttpViewManagerConfigTrait#getConfig`, high | wrong callee / wrong confidence | same (php/17) |
| src/Service/HttpRouteNotFoundStrategyFactory.php:22 | `$config   = $this->getConfig($container);` | `…HttpRouteNotFoundStrategyFactory#__invoke` → `Laminas.Mvc.Service.HttpRouteNotFoundStrategyFactory#getConfig`, medium, method | `Laminas.Mvc.Service.HttpViewManagerConfigTrait#getConfig`, high | wrong callee / wrong confidence | same (php/17) |
| src/Controller/PluginManager.php:116 | `$plugin = parent::get($name, $options);` | `Laminas.Mvc.Controller.PluginManager#get` → `parent.get`, low, method | not `parent.get`; with the parent `Laminas\ServiceManager\AbstractPluginManager` outside the scan, the ID-format rule gives `.get` (low) | wrong callee | `parent::m()` with an out-of-scan parent becomes `parent.m` (open defect php/18) |
| src/Service/ServiceManagerConfig.php:114 | `parent::configureServiceManager($services);` | `Laminas.Mvc.Service.ServiceManagerConfig#configureServiceManager` → `parent.configureServiceManager`, low, method | `.configureServiceManager` (low); parent `Laminas\ServiceManager\Config` is outside the scan | wrong callee | same (php/18) |
| src/Controller/AbstractActionController.php:73 | `$actionResponse = $this->$method();` | no edge | an unresolved low guess, per C4 (ID form: see Spec gaps) | missed call | variable method name dropped |
| src/Controller/AbstractRestfulController.php:344 | `$return = $this->$method();` | no edge | same | missed call | variable method name dropped |
| src/Controller/LazyControllerAbstractFactory.php:112 | `return new $requestedName();` | no edge | an unresolved constructor guess, per C4 | missed call | `new $var` dropped |
| src/Controller/LazyControllerAbstractFactory.php:118 | `return new $requestedName();` | no edge | same | missed call | `new $var` dropped |
| src/Controller/LazyControllerAbstractFactory.php:126 | `return new $requestedName(...$parameters);` | no edge | same | missed call | `new $var` dropped |
| src/Controller/Plugin/AcceptableViewModelSelector.php:88 | `return new $name();` | no edge | same | missed call | `new $var` dropped |
| src/Service/AbstractPluginManagerFactory.php:28 | `return new $pluginManagerClass($container, $options);` | no edge | same | missed call | `new $var` dropped |

## Systematic patterns (wrong), by scripted count
1. **`parent::m()` with an out-of-scan parent becomes `parent.m`** (open defect php/18): 2 edges, `PluginManager.php:116` and `ServiceManagerConfig.php:114`. I grepped `src/` for every `parent::` site. The other `parent::` sites are correct:
   - `parent::__construct` gives `Parent#<init>` medium, for example `ControllerManager.php:51` → `Laminas.ServiceManager.AbstractPluginManager#<init>`.
   - In-scan parents resolve: `AbstractRestfulController.php:313` → `AbstractController#dispatch` high, and `ViewHelperManagerFactory.php:43` → `AbstractPluginManagerFactory#__invoke` high.
2. **Trait method named on the using class at medium** (open defect php/17): 3 edges. A script compared every `T#m` callee against the scanned class hierarchy. These 3 are the only medium edges that name a scanned type with no out-of-scan ancestor and no definition of `m`. The trait `HttpViewManagerConfigTrait` is the only trait in `src/`, and `getConfig` is its only method.

Census: 5 wrong of 1016, 1 − 5/1016 = 99.51%.

Checks that found nothing wrong:
- Every callee name appears called on its reported line (0 mismatches).
- All 270 typed-receiver method edges on `$var->m()` match the declared parameter type or `= new T` type, resolved through the file's `use` imports. Catch and closure parameters are also correct.
- No medium edge names a method that is defined in a scanned class or ancestor.
- No high method edge is missing a definition.
- Every builtin with a `use function` import is `name`, medium, direct.
- The one PHP `$f = function` binding is named `Laminas.Mvc.Application#run.shortCircuit`.
- Anonymous closures fold into their enclosing method.
- Callable arrays (`[$this, 'onDispatch']`), `$x::class`, `$x::CONST`, `clone`, `isset` and `instanceof` emit no edges.
- `src/` has no first-class callables, anonymous classes, enums or top-level code, so open defects php/12, 13, 14 and 11 do not occur. There are no declared object return types either, so php/06 does not occur.

## Missed-call patterns (recall)
- `new $variable(...)`, a dynamic class instantiation: 5 calls, no edge.
- `$this->$method()`, a dynamic method name: 2 calls, no edge.

Total 7, found by comparing written calls with edges on every `src/` line. In the 3 hand-checked functions, 0 of 68 calls were missed. No other call is missing in `src/`.

## Spec gaps (counted separately, not wrong): 50 edges, plus the 7 dynamic calls above
1. **`new T` where scanned class T inherits its constructor from an out-of-scan parent: 41 edges, all high.** Examples:
   - `$this->event = $event  = new MvcEvent();` (src/Application.php:133; `class MvcEvent extends Event`, Event from `Laminas\EventManager`)
   - `throw new DomainException(...)` with `Laminas\Mvc\Exception\DomainException extends \DomainException`
   - `$this->setPluginManager(new PluginManager(new ServiceManager()));` (sample #11)

   Question: PHP constructors are inherited, and T declares no `__construct`. Is the edge `T#<init>` at high, because T is defined in the scan, or `T#<init>` at medium under the rule for "a call of a member inherited from a superclass outside the scan", or the parent's `#<init>`?

   Related case: 3 edges construct scanned classes with no constructor anywhere in their ancestry (`SendResponseListener.php:120–122`). These are high, the same as a default constructor in other languages.
2. **A local bound to a read of a typed property: 7 edges, all low.** Example:

   ```php
   $view = $this->view;
   $view->setRequest($request);
   ```

   Here the property is `protected View $view` (src/View/Http/DefaultRenderingStrategy.php:83–90). The other cases are `$serviceManager = $this->serviceManager;` (Application.php:129, 139) and `$controllerManager = $this->controllerManager;` (DispatchListener.php:80, 91). The tool types `$this->view->m()` in place. The 2026-11-12 ruling types a local bound to a call result.

   Question: does a local bound to a declared-type property read (no call) take that property's type, or stay a `view.setRequest` low guess?
3. **An unqualified global function inside a namespace with no `use function`: 1 edge.** The construct is `zend_monitor_custom_event_ex(` (src/DispatchListener.php:142, in `namespace Laminas\Mvc`). The tool emitted `zend_monitor_custom_event_ex`, low, direct. This is CAPABILITIES php/15, undecided. Question: is the callee the runtime fallback `zend_monitor_custom_event_ex` or the namespace-qualified `Laminas.Mvc.zend_monitor_custom_event_ex`? Is it low or medium?
4. **A local assigned `new T` on one branch and an untyped value on the other, then called after the branches merge: 1 edge.** The code is `if (! $vars instanceof ViewModel) { $model = new ViewModel(); … } else { $model = $vars; … } $model->setTemplate(...)` (src/View/Http/RouteNotFoundStrategy.php:188). The tool emitted `model.setTemplate`, low. Inside the branches it gave `ViewModel#setVariable` medium in the `new` branch and `model.*` low in the `$vars` branch. Question: in PHP, with no declaration and conflicting assignments, does decision A's "`= new T(...)`" type the receiver after the merge?
5. **The ID form for dynamic member and class names** (the 7 missed calls above). The constructs are `$this->$method()` and `new $requestedName(...$parameters)`. C4 requires an edge. Question: SPEC gives no ID for a call whose member name or class name is itself a variable. Should it be a `.member`-style guess, the variable's name as a callback, or something else?
