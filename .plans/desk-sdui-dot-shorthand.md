# desk_sdui_generator — dot-shorthand AST lowering (v3)

**Goal:** Lower Dart 3.7+ context-shorthand expressions (`.smooth()`, `.fadeIn()`, `.all(8)`, `.only(top: 16)`) directly. Screen authors stop having to write `CueMotion.smooth()` / `EdgeInsets.all(8)` to keep codegen happy.

**Prereq:** `@Register` rename merged.

## Honest framing (v3 correction)

Previous attempts tried to recover the "concrete" type at the call site (`EdgeInsets.all` instead of `EdgeInsetsGeometry.all` when the slot is typed `EdgeInsetsGeometry`). This was wrong.

The analyzer's dot-shorthand resolution gives the **element on the context type**. For `padding: .all(8)` where `padding: EdgeInsetsGeometry`, the resolved element is `EdgeInsetsGeometry.all` (a redirecting factory, internally returning `EdgeInsets`). That IS the right answer:

- `EdgeInsetsGeometry.all` is a real, callable, const factory at runtime.
- The redirecting factory produces a concrete `EdgeInsets` — exactly what we want.
- The unified `@Register` model treats every named member uniformly: if `EdgeInsetsGeometry` is in the catalog, the emitter walks its factories and registers `'EdgeInsetsGeometry.all'`, `'EdgeInsetsGeometry.only'`, etc.

So the right cut: **lower to whatever the analyzer resolved, and rely on the registry having that name available** (because the abstract base is in the catalog).

**Architecture:** Three new `if` branches in `widget_lowerer.dart::_lowerArg` for `DotShorthandConstructorInvocation`, `DotShorthandInvocation`, `DotShorthandPropertyAccess`. Each reads `element.enclosingElement.name` to get the declaring class name (the analyzer's truth) and emits `WidgetNode(name: '$enclosing.$member', args: ...)`.

**Tech stack:** `analyzer ^13`, existing IR + lowerer.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Acceptance:**

1. `.all(8)` in an `EdgeInsetsGeometry` slot lowers to `WidgetNode(name: 'EdgeInsetsGeometry.all', args: {arg0: LiteralNode(8)})`.
2. The qualified form `EdgeInsetsGeometry.all(8)` would lower to the same string. (Note: the existing qualified form `EdgeInsets.all(8)` lowers to `'EdgeInsets.all'` — that's expected to differ from the shorthand. Both run correctly as long as both names are in the registry.)
3. A demo screen using `.all(...)` in a `Padding` runs without `value builder not registered` errors. This requires `EdgeInsetsGeometry` to be present in `kCommonWidgets` (or wherever the demo's catalog includes it).
4. Existing tests still pass; demo regen byte-identical for non-shorthand screens.

---

## Task 1 — Add handlers in `widget_lowerer.dart::_lowerArg`

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/widget_lowerer.dart`

Add three branches before the fallthrough to `lowerExpression`:

```dart
if (a is DotShorthandConstructorInvocation) {
  final owner = _enclosingTypeName(a.element);
  if (owner == null) {
    throw LoweringError('dot-shorthand constructor on unresolved element', a);
  }
  final args = _lowerDotShorthandArgs(a.argumentList, constEvaluator);
  return WidgetNode(name: '$owner.${a.constructorName.name}', args: args);
}
if (a is DotShorthandInvocation) {
  final owner = _enclosingTypeName(a.memberName.element);
  if (owner == null) {
    throw LoweringError('dot-shorthand invocation on unresolved element', a);
  }
  final args = _lowerDotShorthandArgs(a.argumentList, constEvaluator);
  return WidgetNode(name: '$owner.${a.memberName.name}', args: args);
}
if (a is DotShorthandPropertyAccess) {
  final owner = _enclosingTypeName(a.propertyName.element);
  if (owner == null) {
    throw LoweringError('dot-shorthand property on unresolved element', a);
  }
  return WidgetNode(name: '$owner.${a.propertyName.name}', args: const {});
}
```

Helper:

```dart
String? _enclosingTypeName(Element? element) {
  if (element == null) return null;
  // For ConstructorElement, PropertyAccessorElement, MethodElement,
  // enclosingElement is the declaring class/enum.
  final enclosing = element.enclosingElement;
  if (enclosing is InterfaceElement) return enclosing.name;
  return null;
}

Map<String, IrNode> _lowerDotShorthandArgs(
  ArgumentList argList,
  Object? Function(InstanceCreationExpression)? constEvaluator,
) {
  final args = <String, IrNode>{};
  for (final a in argList.arguments) {
    if (a is NamedArgument) {
      args[a.name.lexeme] = _lowerArg(a.argumentExpression, constEvaluator: constEvaluator);
    } else {
      args['arg${args.length}'] = _lowerArg(a, constEvaluator: constEvaluator);
    }
  }
  return args;
}
```

**Step 2 — Verify** the file compiles:

```
cd packages/desk_sdui_generator && dart analyze lib/src/screen_lowering/widget_lowerer.dart
```

---

## Task 2 — Registry: ensure abstract bases get their factories emitted

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`

When emitting registrations for a class T in the catalog, walk T's `constructors` regardless of whether T is abstract. Redirecting factories are still callable.

Today the emitter likely has a guard `if (!valueType.isAbstract)` around the unnamed-ctor branch. That guard is correct for the UNNAMED ctor (can't call `new EdgeInsetsGeometry()`). But NAMED ctors / factories on an abstract class CAN be called when they're redirecting factories. The named-ctor loop should NOT be guarded by `!isAbstract`.

Check the existing emitter logic and confirm. Adjust if needed.

---

## Task 3 — Demo screen exercising dot-shorthand end-to-end

**File (new):** `packages/desk_sdui_demo/lib/screens/counter_shorthand.dart`

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

part 'counter_shorthand.sdui.g.dart';

@Screen('counter_shorthand')
Widget counterShorthand(CounterData data) => Padding(
      padding: .all(16),
      child: Center(
        child: Text(
          '${data.value}',
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
        ),
      ),
    );
```

**Catalog update:** add `EdgeInsetsGeometry` to the demo's catalog (or to `kCommonMaterialWidgets` if it isn't already). The bundle in `packages/desk_sdui/lib/widget_bundles.dart` likely has `EdgeInsets` but may not have `EdgeInsetsGeometry`. Add it; the abstract base's redirecting factories are what `.all`/`.only` resolve to.

---

## Task 4 — Test

**File:** `packages/desk_sdui_generator/test/expression_lowerer_test.dart` (or the existing dot-shorthand test location)

```dart
test('dot-shorthand .all() lowers using enclosing type name', () async {
  // Source: padding: .all(8), where padding has type EdgeInsetsGeometry.
  // Lowered name should be 'EdgeInsetsGeometry.all' (the analyzer's resolution).
  // This is correct because the unified registry will have 'EdgeInsetsGeometry.all'
  // registered when EdgeInsetsGeometry is in the catalog.
  final fnDecl = await _resolveScreen('''
    import 'package:flutter/material.dart';
    Widget s() => Padding(padding: .all(8), child: SizedBox());
  ''');
  final result = lowerScreen(fnDecl, ScreenAnnotationData(name: 's'));
  final dartOutput = emitDart(result.copyWith(root: constFold(result.root)));
  expect(dartOutput, contains('EdgeInsetsGeometry.all'));
});
```

The earlier "must contain `EdgeInsets.all`, must NOT contain `EdgeInsetsGeometry.all`" assertion was wrong; reverse it.

---

## Task 5 — Smoke verify

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
grep 'EdgeInsetsGeometry.all' lib/screens/counter_shorthand.sdui.json    # must hit
grep "register.*EdgeInsetsGeometry.all" lib/desk_sdui_setup.g.dart        # must hit (registry has it)
```

Both grep hits required. If the second misses, `EdgeInsetsGeometry` isn't in the catalog or the emitter is guarding-out abstract-class named ctors — fix accordingly.

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
(cd packages/desk_sdui_generator && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter test) || exit 1
```

Run the demo app and visually verify the `counter_shorthand` screen renders the padded counter with no runtime errors.

---

## Out of scope

- Dot-shorthand in patterns. Patterns are not in any current @Screen body.
- Recovering the concrete type when the analyzer resolves to an abstract base. We accept the analyzer's resolution; the registry handles availability.
- Adding `EdgeInsetsGeometry` to bundles automatically — handled manually in this plan via Task 3.
