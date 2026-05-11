# desk_sdui_generator — wildcard variable support

**Goal:** Handle Dart 3.7+ wildcard variables (`_`) in @Screen closures and patterns. Today the lowerer treats `_` as a `SimpleIdentifier` and tries to resolve it as a data ref — throws or emits a broken `RefNode(['_'])`. After this lands, `(_, _) => something` and `for (final _ in xs) ...` lower correctly.

**Prereq:** `.plans/desk-sdui-analyzer-8.md` merged.

**Architecture:** Single-point fix in `expression_lowerer.dart` (and `closure_lowerer.dart` if closure params are handled there): when encountering a `SimpleIdentifier` whose name is `_` AND whose static element is `null` (no binding), emit a sentinel `LiteralNode(null)` for expression contexts, or skip emission entirely for parameter / pattern positions. Analyzer 13 marks wildcards as `isWildcardVariable`; use that flag rather than string-matching the lexeme.

**Tech stack:** `analyzer ^13`, existing IR.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Acceptance:**
- A screen using `(_, _) => Container()` as a closure expression lowers without errors.
- A screen using `for (final _ in items) ...` lowers, iterating without binding.
- Existing chef IR byte-identical.

---

## Task 1 — Lowerer treats `_` as a wildcard, not a ref

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart`
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/closure_lowerer.dart` (if it iterates formal params)

**Step 1 — Identify wildcards.** In analyzer 13, `SimpleIdentifier` and `FormalParameter` expose `isWildcardVariable` (or `name.lexeme == '_'` with no binding — the analyzer guarantees this never collides with a real identifier in Dart 3.7+).

**Step 2 — Add the branch in `expression_lowerer.dart`:**

```dart
if (expr is SimpleIdentifier && expr.isWildcardVariable) {
  // Wildcard at expression position is unreachable in valid Dart, but
  // a defensive null is correct — wildcards do not bind, so any use of
  // their value is meaningless.
  return const LiteralNode(null);
}
```

Add this **before** the existing `if (expr is SimpleIdentifier) return RefNode(...)` branch.

**Step 3 — In `closure_lowerer.dart`** (or wherever closure params are emitted), skip wildcard params from the binding list:

```dart
final params = closure.parameters!.parameters
    .where((p) => !p.isWildcardVariable)
    .map((p) => p.name!.lexeme)
    .toList();
```

For positional wildcard params, preserve the *position* (don't shift later params left) — pass `null` or a synthesized sentinel name (`'_<index>'`) so the closure's arity stays correct.

**Step 4 — Verify**

```
cd packages/desk_sdui_generator && dart analyze
```

---

## Task 2 — Test

**Files:**
- Modify: `packages/desk_sdui_generator/test/expression_lowerer_test.dart`
- Modify: `packages/desk_sdui_generator/test/widget_lowerer_test.dart` (if closures live there)

**Step 1 — Add tests** for both positions:

```dart
test('wildcard param in closure does not bind', () {
  final ir = lowerScreen('''
    @Screen('w')
    Widget w() => Builder(builder: (_) => SizedBox());
  ''');
  // Assert the closure's params list is empty or contains a sentinel.
  // Exact shape depends on closure_lowerer's emission contract — pick
  // the assertion that matches.
});

test('wildcard in for-in iterates without binding', () {
  final ir = lowerScreen('''
    @Screen('w')
    Widget w() => Column(children: [for (final _ in [1,2,3]) Text('x')]);
  ''');
  // Assert no RefNode(['_']) appears anywhere in the IR.
});
```

**Step 2 — Run**

```
dart test
```

---

## Task 3 — Regress chef IR

Standard byte-identical diff against the committed chef IR (chef uses no wildcards, so output must be identical):

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
git diff packages/desk_sdui_demo/lib/screens/chef.sdui.g.dart
```

Expected: zero diff.

---

## Task 4 — Commit

```
git add -A && git commit -m "feat(generator): support wildcard variables in @Screen bodies"
```

---

## Out of scope

- Pattern wildcards inside `switch` expressions on @Screen bodies. The IR doesn't model patterns at all yet; that's a much larger surface.
- Wildcard type parameters. Not used in any @Screen.

## Verify commands

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
(cd packages/desk_sdui_generator && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter test) || exit 1
```
