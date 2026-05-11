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

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
(cd packages/desk_sdui_generator && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter test) || exit 1
```
