# desk_sdui_generator — dot-shorthand AST lowering

**Goal:** Lower Dart 3.7+ context-shorthand expressions (`.smooth()`, `.fadeIn()`, `.only(top: 16)`) directly. Screen authors stop having to write `CueMotion.smooth()` / `EdgeInsets.only(top: 16)` to keep codegen happy; the analyzer resolves the context type and we use it to qualify the IR name.

**Prereq:** `.plans/desk-sdui-analyzer-8.md` merged (analyzer 13 exposes the AST nodes).

**Architecture:** Two new AST cases in `expression_lowerer.dart` — `DotShorthandPropertyAccess` and `DotShorthandInvocation`. Both expose `.staticType` (the context-resolved owner type) and a name token. Use the owner's resolved type-name as the qualifier and emit `ValueCtorNode(name: '$owner.$member', args: ...)`. Reuse the existing named-arg → record handling.

**Tech stack:** `analyzer ^13`, existing IR + lowerer.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Acceptance:** A test screen using `.smooth()` lowers to the same `ValueCtorNode('CueMotion.smooth', …)` as a fully-qualified `CueMotion.smooth()` does. Existing chef IR remains byte-identical.

---

## Task 1 — Add handlers in `expression_lowerer.dart`

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart`

**Step 1 — Add a helper for the owner-name lookup:**

```dart
String? _dotShorthandOwnerName(DartType? ctxType) {
  if (ctxType == null) return null;
  if (ctxType is InterfaceType) return ctxType.element.name;
  return null;
}
```

**Step 2 — Add the two `if (expr is …)` branches** above the existing `PrefixedIdentifier` / `PropertyAccess` handlers. Mirror the named-arg conversion used by `widget_lowerer.dart` — extract that helper to a shared utility if it isn't already.

```dart
if (expr is DotShorthandPropertyAccess) {
  final owner = _dotShorthandOwnerName(expr.staticType);
  if (owner == null) {
    throw LoweringError('dot-shorthand on unresolved context type', expr);
  }
  return ValueCtorNode(
    name: '$owner.${expr.propertyName.name}',
    args: const [],
  );
}

if (expr is DotShorthandInvocation) {
  final owner = _dotShorthandOwnerName(expr.staticType);
  if (owner == null) {
    throw LoweringError('dot-shorthand on unresolved context type', expr);
  }
  final args = lowerArguments(expr.argumentList); // shared helper
  return ValueCtorNode(
    name: '$owner.${expr.memberName.name}',
    args: args,
  );
}
```

**Step 3 — Verify** the file compiles:

```
cd packages/desk_sdui_generator && dart analyze lib/src/screen_lowering/expression_lowerer.dart
```

---

## Task 2 — Test

**Files:**
- Modify: `packages/desk_sdui_generator/test/expression_lowerer_test.dart`

**Step 1 — Add a test pair.** Author a fixture screen that uses dot-shorthand in a typed context (e.g. `EdgeInsets.only(top: 16)` → `.only(top: 16)` where the parameter type is `EdgeInsets`). Lower both forms; assert their IRs are equal.

```dart
test('dot-shorthand lowers to the same IR as the fully-qualified form', () {
  final shorthand = lowerScreen('''
    @Screen('a')
    Widget a() => Padding(padding: .only(top: 16), child: SizedBox());
  ''');
  final qualified = lowerScreen('''
    @Screen('a')
    Widget a() => Padding(padding: EdgeInsets.only(top: 16), child: SizedBox());
  ''');
  expect(shorthand, equals(qualified));
});
```

(Adapt the harness to whatever `expression_lowerer_test.dart` already exposes for parsing.)

**Step 2 — Run**

```
dart test test/expression_lowerer_test.dart
```

---

## Task 3 — Regress chef IR

**Step 1 — Regenerate**

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
```

**Step 2 — Diff against the most recent committed chef IR (`git show HEAD:packages/desk_sdui_demo/lib/screens/chef.sdui.g.dart > /tmp/chef.before`):** byte-identical, since chef uses no dot-shorthand. Any diff is a regression.

**Step 3 — Commit**

```
git add -A && git commit -m "feat(generator): lower dot-shorthand expressions"
```

---

## Out of scope

- Lowering dot-shorthand in *non*-ValueCtor positions (e.g. `.foo` resolved to a getter on the context type). If the analyzer reports such cases, add an additional `if (expr is DotShorthandPropertyAccess && expr.element is GetterElement)` branch — but flag as a deviation per the SDD process.
- Dot-shorthand in patterns. Patterns are not in any current @Screen body.

---

## CRITICAL: end-to-end runtime check (after a prior dispatch found a gap)

A previous opencode dispatch resolved the owner name via `element.enclosingElement.name` (the **declaring class**). For `.all(8)` in an `EdgeInsetsGeometry` slot, the analyzer's element resolves to `EdgeInsetsGeometry.all` — but the registry only generates a builder for `EdgeInsets.all` (the concrete constructor), so the IR fails to materialize at runtime.

**The lowered IR name MUST match the qualified form's name.** `.all(8)` in an `EdgeInsetsGeometry` parameter slot must lower to `EdgeInsets.all` (the concrete static type at the call site), NOT `EdgeInsetsGeometry.all` (the declaring class). The qualified form `EdgeInsets.all(8)` lowers to `'EdgeInsets.all'`; the shorthand `.all(8)` must lower to the same string.

**Use `expr.staticType` from the dot-shorthand AST node** (the context-resolved type at the call site), via the `_dotShorthandOwnerName` helper shown in Task 1. Do NOT use `element.enclosingElement.name`. If `staticType` is null or unresolvable, throw `LoweringError` rather than falling back.

### Task 4 — End-to-end demo screen (REQUIRED)

The previous attempt passed unit tests but the runtime path was never exercised. Add a real demo screen that uses dot-shorthand in a typed context, and verify the generated `.sdui_reg.g.dart` contains a builder matching the IR's name.

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

After `dart run build_runner build --delete-conflicting-outputs`:

1. Inspect `lib/screens/counter_shorthand.sdui.json` — the `padding` field must be `{"$type":"widget","name":"EdgeInsets.all","args":{"arg0":{"$type":"literal","value":16}}}`. The name must be `EdgeInsets.all`, NOT `EdgeInsetsGeometry.all`.
2. Inspect `lib/screens/counter_shorthand.sdui_reg.g.dart` — must contain `rt.registerValueBuilder('EdgeInsets.all', ...)`. If it doesn't, the registry's reachability walker isn't picking up the type — fix the walker.
3. Demo app, when run, must render the screen with no `value builder not registered` runtime errors.

### Task 5 — Smoke verify

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
grep 'EdgeInsets.all' lib/screens/counter_shorthand.sdui.json           # must hit
grep 'EdgeInsetsGeometry.all' lib/screens/counter_shorthand.sdui.json   # must miss
grep "registerValueBuilder('EdgeInsets.all'" lib/screens/counter_shorthand.sdui_reg.g.dart   # must hit
```

If any of these fail, the lowering is still wrong. Do NOT commit.

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
(cd packages/desk_sdui_generator && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter test) || exit 1
```
