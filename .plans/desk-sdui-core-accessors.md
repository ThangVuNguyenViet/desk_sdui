# desk_sdui — Core-type Accessor Registry

**Goal:** Stop hand-rolling core-type property accessors (`String.isNotEmpty`, `Iterable.first`, `List.length`, …) inside `ref_resolver`. Move them behind a uniform, extensible getter registry on `Runtime`, modeled on flutter_eval's bridge-spec approach. Keep `resolveRef` strictly about data-shape traversal (Map keys, List indexes).

**Why:** Today `expression_lowerer` flattens any `PropertyAccess` chain rooted in a `RefNode` into a longer `RefNode` path:

```dart
// dish.description.isNotEmpty  →  RefNode(['dish','description','isNotEmpty'])
```

That forces `ref_resolver` to interpret accessors against primitive receivers (`String`, `Iterable`, …) — which doesn't scale (`.toUpperCase()`, `.trim()`, `.contains()`, `.map()`, num arithmetic, DateTime, …). flutter_eval solves this with per-library *bridge specs* dispatched through a uniform registry; we'll adopt the same shape, scoped to getter-style reads.

**Architecture (load-bearing decision):**

- Lowering uses the analyzer's *resolved* static type to split a `PropertyAccess` chain at the first segment whose target is a non-data core type. The data-shape prefix becomes a `RefNode`; the trailing accessor becomes a `GetterNode(receiver, qualifiedName)` (e.g. `'String.isNotEmpty'`, `'Iterable.first'`).
- `Runtime` gains a getter registry: `_getters: Map<String, Object? Function(Object?)>` + `registerGetter` / `invokeGetter`.
- A new generator emits `registerCoreAccessors(Runtime rt)` covering a curated catalog of `dart:core` getters (String, num/int/double, bool, Iterable, List, Map, Set, DateTime, Duration). Curated, not full-SDK scan — only side-effect-free property reads.
- `resolveRef` is reduced to: Map key, List index, `__getters__` map escape hatch. The String/Iterable special cases are deleted.
- `registerAllScreens` (codegen) prepends `registerCoreAccessors(rt)` so consumers don't need to wire it manually.

**Tech stack:** Dart analyzer (`DartType`), `build_runner` / source_gen, existing `desk_sdui_generator`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Add `GetterNode` to the IR

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_ir_codec.dart` (encode + decode)

**Step 1 — Define the node** (after `MemberAccessNode`):

```dart
/// `receiver.name` where `name` is resolved through Runtime.invokeGetter,
/// not by walking a data path. `name` is the qualified handler key, e.g.
/// `'String.isNotEmpty'`, `'Iterable.first'`. Emitted by the lowerer when
/// the receiver's static type is a known core type.
final class GetterNode extends ExpressionNode {
  const GetterNode({required this.receiver, required this.name});
  final IrNode receiver;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is GetterNode && other.receiver == receiver && other.name == name;
  @override
  int get hashCode => Object.hash(receiver, name);
  @override
  String toString() => 'GetterNode($receiver.$name)';
}
```

**Step 2 — JSON codec:** add `'GetterNode'` case to both encode + decode; payload `{receiver, name}`.

**Step 3 — Verify**

```
cd packages/desk_sdui_annotation && dart analyze
dart test
```

Expected: clean.

**Step 4 — Commit**

```
git add -A && git commit -m "feat(ir): add GetterNode for core-type accessor dispatch"
```

---

## Task 2 — Runtime: getter registry

**Files:**
- Modify: `packages/desk_sdui/lib/src/runtime.dart`

**Step 1 — Add the typedef + registry** (next to existing `SduiMethodHandler`):

```dart
/// Resolves a getter call `receiver.name` to a value. Registered against the
/// qualified handler name, e.g. `'String.isNotEmpty'`.
typedef SduiGetterHandler = Object? Function(Object? receiver);
```

Inside `Runtime`:

```dart
final Map<String, SduiGetterHandler> _getters = {};

void registerGetter(String name, SduiGetterHandler handler) =>
    _getters[name] = handler;

SduiGetterHandler? resolveGetter(String name) => _getters[name];

Object? invokeGetter(String name, Object? receiver) =>
    _getters[name]?.call(receiver);
```

**Step 2 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

**Step 3 — Commit**

```
git commit -am "feat(runtime): add SduiGetterHandler registry"
```

---

## Task 3 — Resolver wires `GetterNode`

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart`

**Step 1 — Add the case** (next to `MemberAccessNode`):

```dart
case GetterNode(:final receiver, :final name):
  final r = evalExpression(receiver, input, runtime);
  final handler = runtime.resolveGetter(name);
  if (handler != null) return handler(r);
  throw StateError('No getter registered for "$name" (receiver: ${r.runtimeType})');
```

**Step 2 — Verify** — existing `desk_sdui` tests still pass:

```
cd packages/desk_sdui && dart test
```

**Step 3 — Commit**

```
git commit -am "feat(eval): dispatch GetterNode through Runtime.invokeGetter"
```

---

## Task 4 — Curated `registerCoreAccessors`

**Files:**
- Create: `packages/desk_sdui/lib/src/core_accessors.dart`
- Modify: `packages/desk_sdui/lib/desk_sdui.dart` (export)

**Step 1 — Write the module.** Hand-curated — only pure, side-effect-free property reads.

```dart
import 'runtime.dart';

/// Registers the built-in `dart:core` getters that desk_sdui supports out of
/// the box. Call this once during runtime setup (codegen does this for you
/// via `registerAllScreens`).
void registerCoreAccessors(Runtime rt) {
  // String
  rt.registerGetter('String.length',     (r) => (r as String).length);
  rt.registerGetter('String.isEmpty',    (r) => (r as String).isEmpty);
  rt.registerGetter('String.isNotEmpty', (r) => (r as String).isNotEmpty);
  rt.registerGetter('String.hashCode',   (r) => (r as String).hashCode);
  rt.registerGetter('String.runes',      (r) => (r as String).runes);
  rt.registerGetter('String.codeUnits',  (r) => (r as String).codeUnits);

  // Iterable<T> — covers List, Set, Iterable, Map.keys/values
  Object? _iterLen(Object? r)    => (r as Iterable).length;
  Object? _iterEmpty(Object? r)  => (r as Iterable).isEmpty;
  Object? _iterNonEmpty(Object? r) => (r as Iterable).isNotEmpty;
  Object? _iterFirst(Object? r)  {
    final it = r as Iterable;
    return it.isEmpty ? null : it.first;
  }
  Object? _iterLast(Object? r)   {
    final it = r as Iterable;
    return it.isEmpty ? null : it.last;
  }
  Object? _iterSingle(Object? r) {
    final it = r as Iterable;
    return it.length == 1 ? it.single : null;
  }
  for (final t in const ['Iterable', 'List', 'Set']) {
    rt.registerGetter('$t.length',     _iterLen);
    rt.registerGetter('$t.isEmpty',    _iterEmpty);
    rt.registerGetter('$t.isNotEmpty', _iterNonEmpty);
    rt.registerGetter('$t.first',      _iterFirst);
    rt.registerGetter('$t.last',       _iterLast);
    rt.registerGetter('$t.single',     _iterSingle);
  }

  // Map
  rt.registerGetter('Map.length',     (r) => (r as Map).length);
  rt.registerGetter('Map.isEmpty',    (r) => (r as Map).isEmpty);
  rt.registerGetter('Map.isNotEmpty', (r) => (r as Map).isNotEmpty);
  rt.registerGetter('Map.keys',       (r) => (r as Map).keys);
  rt.registerGetter('Map.values',     (r) => (r as Map).values);
  rt.registerGetter('Map.entries',    (r) => (r as Map).entries);

  // num / int / double
  for (final t in const ['num', 'int', 'double']) {
    rt.registerGetter('$t.isNaN',      (r) => (r as num).isNaN);
    rt.registerGetter('$t.isFinite',   (r) => (r as num).isFinite);
    rt.registerGetter('$t.isInfinite', (r) => (r as num).isInfinite);
    rt.registerGetter('$t.isNegative', (r) => (r as num).isNegative);
    rt.registerGetter('$t.sign',       (r) => (r as num).sign);
    rt.registerGetter('$t.abs',        (r) => (r as num).abs());
    rt.registerGetter('$t.round',      (r) => (r as num).round());
    rt.registerGetter('$t.floor',      (r) => (r as num).floor());
    rt.registerGetter('$t.ceil',       (r) => (r as num).ceil());
    rt.registerGetter('$t.truncate',   (r) => (r as num).truncate());
  }
  rt.registerGetter('int.isEven', (r) => (r as int).isEven);
  rt.registerGetter('int.isOdd',  (r) => (r as int).isOdd);

  // DateTime
  rt.registerGetter('DateTime.year',         (r) => (r as DateTime).year);
  rt.registerGetter('DateTime.month',        (r) => (r as DateTime).month);
  rt.registerGetter('DateTime.day',          (r) => (r as DateTime).day);
  rt.registerGetter('DateTime.hour',         (r) => (r as DateTime).hour);
  rt.registerGetter('DateTime.minute',       (r) => (r as DateTime).minute);
  rt.registerGetter('DateTime.second',       (r) => (r as DateTime).second);
  rt.registerGetter('DateTime.millisecond',  (r) => (r as DateTime).millisecond);
  rt.registerGetter('DateTime.weekday',      (r) => (r as DateTime).weekday);
  rt.registerGetter('DateTime.isUtc',        (r) => (r as DateTime).isUtc);

  // Duration
  rt.registerGetter('Duration.inDays',         (r) => (r as Duration).inDays);
  rt.registerGetter('Duration.inHours',        (r) => (r as Duration).inHours);
  rt.registerGetter('Duration.inMinutes',      (r) => (r as Duration).inMinutes);
  rt.registerGetter('Duration.inSeconds',      (r) => (r as Duration).inSeconds);
  rt.registerGetter('Duration.inMilliseconds', (r) => (r as Duration).inMilliseconds);
}
```

**Step 2 — Export from the package barrel** (`lib/desk_sdui.dart`): add `export 'src/core_accessors.dart';`.

**Step 3 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

**Step 4 — Commit**

```
git add -A && git commit -m "feat(runtime): ship registerCoreAccessors for dart:core getter dispatch"
```

---

## Task 5 — Lowering uses static types to split RefNode vs GetterNode

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart`

**Step 1 — Add a helper that classifies a `DartType`** by the core-type bucket used as the qualified-key prefix:

```dart
/// Returns the core-type bucket name used as the GetterNode key prefix
/// (e.g. 'String', 'Iterable', 'List', 'Map', 'num', 'int', 'double', 'bool',
/// 'DateTime', 'Duration'). Returns null when the type is not a recognized
/// core type (in that case the expression-lowerer should keep folding into
/// RefNode or emit MemberAccessNode as before).
String? _coreTypeBucket(DartType? type) {
  if (type == null || type is DynamicType || type is InvalidType) return null;
  final el = type.element;
  if (el == null) return null;
  final lib = el.library?.identifier ?? '';
  if (!lib.startsWith('dart:core') && !lib.startsWith('dart:async')) return null;
  final name = el.name;
  if (name == null) return null;
  // Direct buckets. `List`/`Set` route to themselves; subtypes resolve via
  // the runtime `Iterable.*` registration at dispatch time (callers fall
  // back through DartType.allSupertypes inspection — handled below).
  const direct = {
    'String', 'List', 'Set', 'Map', 'Iterable',
    'num', 'int', 'double', 'bool', 'DateTime', 'Duration',
  };
  if (direct.contains(name)) return name;
  // Fallback: walk supertypes for Iterable<T>, Map<K,V>, num.
  if (type is InterfaceType) {
    for (final sup in type.allSupertypes) {
      final n = sup.element.name;
      if (direct.contains(n)) return n;
    }
  }
  return null;
}
```

(Import `package:analyzer/dart/element/type.dart` at the top.)

**Step 2 — Rewrite the `PrefixedIdentifier` / `PropertyAccess` cases** so that, when the prefix lowers to a `RefNode` (data-binding path) but the prefix's **static type** is a core type, the trailing identifier becomes a `GetterNode` instead of being appended to the RefNode path.

Replace lines 28-48 with:

```dart
if (expr is PrefixedIdentifier) {
  if (expr.identifier.name == 'length') {
    return LengthOfNode(lowerExpression(expr.prefix));
  }
  final target = lowerExpression(expr.prefix);
  final bucket = _coreTypeBucket(expr.prefix.staticType);
  if (target is RefNode && bucket == null) {
    return RefNode([...target.path, expr.identifier.name]);
  }
  if (bucket != null) {
    return GetterNode(
      receiver: target,
      name: '$bucket.${expr.identifier.name}',
    );
  }
  return MemberAccessNode(target: target, name: expr.identifier.name);
}

if (expr is PropertyAccess) {
  if (expr.propertyName.name == 'length') {
    return LengthOfNode(lowerExpression(expr.target!));
  }
  final target = lowerExpression(expr.target!);
  final bucket = _coreTypeBucket(expr.target!.staticType);
  if (target is RefNode && bucket == null) {
    return RefNode([...target.path, expr.propertyName.name]);
  }
  if (bucket != null) {
    return GetterNode(
      receiver: target,
      name: '$bucket.${expr.propertyName.name}',
    );
  }
  return MemberAccessNode(target: target, name: expr.propertyName.name);
}
```

**Note on the typed-input contract:** the @Screen author writes `ChefData data` at the top of the function, but the render-time input is a `Map<String, Object?>`. The lowerer sees the *typed* signature, so `data.dishes` has `staticType == List<Dish>`. That means `data.dishes.first.name` correctly lowers to `MemberAccess(GetterNode(RefNode(['data','dishes']), 'List.first'), 'name')`. The runtime then evaluates the inner RefNode against the Map, the getter against the resolved list, and `MemberAccessNode` against the resulting `Map<String, Object?>` element. This is the behavior we want.

**Step 3 — Verify**

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

**Step 4 — Commit**

```
git commit -am "feat(codegen): lower core-type accessors as GetterNode using static types"
```

---

## Task 6 — Codegen calls `registerCoreAccessors` from `registerAllScreens`

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/registration_emitter.dart` (or wherever `registerAllScreens` is emitted — `grep -rn "registerAllScreens" packages/desk_sdui_generator/lib/src/`).

**Step 1 — Prepend `registerCoreAccessors(rt);` as the first body statement** of the emitted `registerAllScreens` function, and ensure `package:desk_sdui/desk_sdui.dart` is imported so the symbol is in scope.

**Step 2 — Regenerate the demo** and verify the file contains the call:

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
grep -n "registerCoreAccessors" lib/desk_sdui_setup.g.dart
```

Expected: one match inside `registerAllScreens`.

**Step 3 — Commit** the codegen change + regenerated demo files.

```
git add -A && git commit -m "feat(codegen): emit registerCoreAccessors call in registerAllScreens"
```

---

## Task 7 — Shrink `resolveRef` to data-shape traversal only

**Files:**
- Modify: `packages/desk_sdui/lib/src/ref_resolver.dart`

**Step 1 — Delete the String and Iterable branches**, plus the named-accessor switch inside the List branch. Result is the minimal version below:

```dart
import 'runtime.dart';

/// Walks a pre-split path through nested maps and lists and returns the leaf.
/// Only handles data-shape traversal; property accessors on primitives are
/// lowered to GetterNode (see expression_eval.dart).
Object? resolveRef(List<String> path, Map<String, Object?> input) {
  Object? current = input;
  for (final seg in path) {
    if (current == null) return null;
    if (current is Map) {
      final getters = current['__getters__'];
      if (getters is Map && getters.containsKey(seg)) {
        final g = getters[seg];
        if (g is Function) {
          current = Function.apply(g, const []);
          continue;
        }
      }
      current = current[seg];
      continue;
    }
    if (current is List) {
      final i = int.tryParse(seg);
      if (i == null || i < 0 || i >= current.length) return null;
      current = current[i];
      continue;
    }
    throw StateError(
      'resolveRef: cannot traverse "$seg" into ${current.runtimeType} '
      '(expected Map or List). Property accessors must be lowered as '
      'GetterNode, not appended to RefNode paths.',
    );
  }
  return current;
}

/// Resolves a path that may start with a Flutter class name (Icons, Colors,
/// CrossAxisAlignment, …). Constants are looked up via Runtime.resolveConstant.
Object? resolveFlutterRef(
  List<String> path,
  Map<String, Object?> input,
  Runtime runtime,
) {
  if (path.isEmpty) return null;
  if (path.length >= 2) {
    final key = '${path[0]}.${path[1]}';
    final v = runtime.resolveConstant(key);
    if (v != null) {
      if (path.length == 2) return v;
      return resolveRef(path.sublist(2), {'__root__': v});
    }
  }
  return resolveRef(path, input);
}
```

**Step 2 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

**Step 3 — Commit**

```
git commit -am "refactor(resolver): resolveRef handles only Map/List traversal"
```

---

## Task 8 — End-to-end demo verification

**Files:**
- Test only — no source changes expected.

**Step 1 — Rebuild the demo IR**

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

**Step 2 — Inspect the regenerated chef IR** to confirm `dish.description.isNotEmpty` now lowers to a `GetterNode` and is NOT in a flattened `RefNode` path:

```
grep -n "isNotEmpty" lib/screens/chef.sdui.g.dart
```

Expected: occurrence sits inside a `GetterNode(name: 'String.isNotEmpty', …)` constructor call, not inside a `RefNode(['…','isNotEmpty'])` list.

**Step 3 — Run the demo on web** and confirm the chef screen renders without exceptions:

```
flutter run -d chrome --target lib/main.dart
```

Watch the console for any `StateError: resolveRef: cannot traverse …` — any remaining accessor leakage will throw with that message (now clearer because the resolver no longer special-cases primitives).

**Step 4 — Run all package tests**

```
cd packages/desk_sdui            && dart test
cd ../desk_sdui_annotation       && dart test
cd ../desk_sdui_generator        && dart test
cd ../desk_sdui_demo             && flutter test
```

Expected: all pass.

**Step 5 — Commit** any regenerated artifacts.

```
git add -A && git commit -m "chore(demo): regenerate IR after GetterNode lowering"
```

---

## Out of scope (deliberately)

- **Method calls with arguments** (`.toUpperCase()`, `.contains(x)`, `.map(f)`). Those go through the existing `MethodCallNode` / `invokeMethod` path. A `registerCoreMethods` companion is a logical follow-up — but it's a separate plan because method dispatch has to handle argument lowering and pure-vs-side-effect classification.
- **A full SDK scanner** that enumerates every core getter. Curated catalog only — covering ~95% of real screens, with room to grow.
- **Consumer-defined getter packs.** The `registerGetter` API is public, so a consumer can drop in their own (e.g. `MyData.foo`) without codegen support. We don't ship tooling for that in this plan.

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui

# Per-package analyze + test
for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done

# Regenerate + test demo
(cd packages/desk_sdui_demo \
  && dart run build_runner build --delete-conflicting-outputs \
  && flutter test) || exit 1
```
