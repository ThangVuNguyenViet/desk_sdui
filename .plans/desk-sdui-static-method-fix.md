# desk_sdui — fix static-method emission and lowering

**Goal:** `Theme.of(context)`, `MediaQuery.sizeOf(context)`, and any other static method on a registered class must lower and emit as a **flat callable** (no receiver), not as an instance method.

**Background:** The vm-callable + context-param work landed with an incorrect shape:
- Lowerer in `widget_lowerer.dart` emits `MethodCallNode(receiver: RefNode(['context']), name: 'Theme.of', args: [])` — treats the *first argument* as the receiver.
- Emitter `emitMethod` in `registration_emitter.dart` generates `rt.registerMethod('Theme.of', (recv, args) => (recv as Theme).of(args['arg0']))` — would cast `BuildContext` to `Theme` at runtime and crash.

Static methods are not instance methods. They have no receiver. The correct shape:

```dart
// Lowered IR:
CallNode(name: 'Theme.of', args: {'arg0': RefNode(['context'])})

// Registry entry:
rt.registerFunction('Theme.of', (args) => Theme.of(args['arg0'] as BuildContext));
```

**Acceptance:**

1. The `themed_counter` demo renders without runtime errors. Tapping +/- increments the counter; toggling the app theme rebuilds with new colors.
2. Generated `desk_sdui_setup.g.dart` (or per-screen reg file) contains `rt.registerFunction('Theme.of', (args) => Theme.of(args['arg0'] as BuildContext));` — NO `(recv as Theme).of(...)` form.
3. `MethodCallNode` is no longer produced for static-method invocations. They lower to whatever flat-call node already exists for top-level functions (`CallNode` or similar; check `ast_to_ir.dart` for the function-call path and reuse it).
4. Existing tests still pass. Add one test fixture that asserts `Theme.of(context)` lowers to the flat-call shape and emits as `registerFunction`.

---

## Task 1 — Emitter: branch `emitMethod` on `isStatic`

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`

In `emitMethod`:

```dart
String emitMethod(MethodElement method, {required DartType receiverType}) {
  final receiverClassName = method.enclosingElement!.name;
  final qualifiedName = '$receiverClassName.${method.name}';
  final params = method.formalParameters;
  final callArgs = _buildCallArgList(params);

  if (method.isStatic) {
    // Static methods have no receiver. Emit as a flat function-style callable.
    return "rt.registerFunction('$qualifiedName', "
        "(args) => $receiverClassName.${method.name}($callArgs));";
  }

  final receiverTypeName = _typeDisplayName(receiverType);
  return "rt.registerMethod('$qualifiedName', "
      "(recv, args) => (recv as $receiverTypeName).${method.name}($callArgs));";
}
```

The `emitMethodsForClass` walker already skips statics (`if (method.isStatic) continue;`). Confirm the `collected.methods` walk that ends in `emitMethod` calls passes statics through (currently it does — that's how `Theme.of` got picked up). No change to the walker needed; `emitMethod` itself branches.

---

## Task 2 — Lowerer: remove the static-method MethodCallNode branch; route through the flat-call path

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/widget_lowerer.dart`

Delete the recently-added static-method branch (the `if (a is MethodInvocation && a.target is SimpleIdentifier && _isUppercase(...) && ...)` block that produces `MethodCallNode`). The existing "qualified static-factory / named-constructor call" branch below it already handles `ClassName.member(args)` — extend that path (or the flat-call path used by top-level functions) to cover static method calls too.

The lowered IR for `Theme.of(context)` should be the same shape as a top-level function call — whatever node kind `min(a, b)` lowers to today. Inspect `ast_to_ir.dart` / `expression_lowerer.dart` to identify that node kind (likely `CallNode` or similar) and emit it here.

If a flat call-node kind doesn't exist yet and `MethodCallNode` is the closest, repurpose `MethodCallNode` with `receiver: null` to mean "flat static call." But prefer reusing the existing function-call path if there is one.

---

## Task 3 — Runtime: invoke flat callable when receiver is null/absent

**File:** `packages/desk_sdui/lib/src/runtime.dart` (or wherever `MethodCallNode` / `CallNode` materialization lives)

If the chosen IR shape is a flat call (`CallNode`), no runtime change — the function-call dispatch path already exists.

If you reuse `MethodCallNode` with optional receiver, branch:
```dart
if (node.receiver == null) {
  final fn = rt.callableFor(node.name);
  return fn!(node.args);
} else {
  // existing instance-method dispatch
}
```

---

## Task 4 — Demo: verify themed_counter renders

**File:** `packages/desk_sdui_demo/lib/screens/themed_counter.dart` (already exists)

No source change. Re-run codegen and re-verify:

```bash
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
grep "rt.registerFunction('Theme.of'" lib/**/*.g.dart     # must hit
grep "(recv as Theme).of"            lib/**/*.g.dart      # must NOT hit
```

Launch the demo, navigate to `themed_counter`, tap +/-, toggle theme. Counter increments, theme follows. No runtime cast errors in the console.

---

## Task 5 — Test

**File:** `packages/desk_sdui_generator/test/register_for_sdui_test.dart` (or wherever static-method emission would be tested)

Add a test fixture that registers `Theme` and asserts the emitted output:
- Contains `rt.registerFunction('Theme.of', (args) => Theme.of(args['arg0'] as BuildContext));`
- Does NOT contain `(recv as Theme).of(`

Add a lowerer test fixture that lowers `Theme.of(context)` and asserts the resulting IR is a flat call (not a `MethodCallNode` with `context` as receiver).

---

## Verify

```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test
```

All green. Demo renders themed_counter end-to-end.

---

## Out of scope

- Generalizing flat-call vs instance-call to a single node kind. Keep using the existing function-call path for statics.
- Method discovery for inherited statics (e.g. `Theme.of` on a subclass of `Theme`). Only direct statics on the registered class.
- Optimization of duplicate emissions if multiple screens reach the same static method. Acceptable to emit once per screen if that's the current behavior.
