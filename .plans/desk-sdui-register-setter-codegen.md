# desk_sdui — Setter codegen for `@Register` (field assignment on registered objects)

**Goal:** Extend `@Register([T])` codegen to also emit `registerSetter` calls for non-final, public, non-late, non-static instance fields of `T`. Authors write `vm.count = 0` in payload and it lowers + executes. Today that requires hand-rolling `setCount(int)` wrapper methods.

**Dependencies:**
- **Feature 8 (`AssignNode` / mutable env)** must be merged. The lowerer needs to be able to parse assignment expressions at all; today they're rejected wholesale. Feature 8 lifts that for local vars; this plan extends acceptance to `receiver.field = value` shapes.
- Runtime setter dispatch is independent — could land before Feature 8 ships if we wanted, but the user-facing path requires the AssignmentExpression lowering work that Feature 8 introduces.

**Architecture (load-bearing):**
- Codegen change: the `@Register` field walker (currently emits `registerGetter` for public fields) gets a second branch — when the field is non-final + non-late + non-static + public, ALSO emit `registerSetter('Type.fieldName', (target, value) => (target as Type).fieldName = value as FieldType)`.
- Runtime change: `Runtime` gains a `Map<String, SduiSetterHandler> _setters` + `registerSetter`/`invokeSetter` mirroring the existing getter registry.
- New IR node: `SetterCallNode { target, setterKey, value }`. Keeps `AssignNode` (Feature 8) focused on local-variable mutation; field-setter dispatch is a sibling node. Lowerer routes `AssignmentExpression` to whichever node based on LHS shape.
- Allowlist preserved: setters dispatch through the same registry surface as getters/methods. Payload can only assign to fields whose owning type was registered.

**Tech stack:** existing `@Register` codegen, existing Runtime, new IR node, lowerer extension.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Runtime: setter registry

**Files:**
- Modify: `packages/desk_sdui/lib/src/runtime.dart`.

**Step 1 — Add the typedef + registry** alongside the existing `SduiGetterHandler` (introduced by core-accessors, already in main):

```dart
/// Mutates a field on `receiver` by writing `value`. Registered against the
/// qualified handler name, e.g. `'Vm.count'`. Codegen emits one per
/// non-final, non-late, non-static, public instance field of each
/// `@Register`-ed type.
typedef SduiSetterHandler = void Function(Object? receiver, Object? value);
```

Inside `Runtime`:

```dart
final Map<String, SduiSetterHandler> _setters = {};

void registerSetter(String name, SduiSetterHandler handler) =>
    _setters[name] = handler;

SduiSetterHandler? resolveSetter(String name) => _setters[name];

void invokeSetter(String name, Object? receiver, Object? value) {
  final h = _setters[name];
  if (h == null) {
    throw StateError(
      'No setter registered for "$name" (receiver: ${receiver?.runtimeType}). '
      'If this is a registered type, verify the field is non-final and public.',
    );
  }
  h(receiver, value);
}
```

**Step 2 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

Existing tests must pass — purely additive surface.

**Step 3 — Commit**

```
git commit -am "feat(runtime): SduiSetterHandler registry"
```

---

## Task 2 — IR node `SetterCallNode`

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the node** (near `GetterNode`):

```dart
/// `target.field = value` where `field` resolves through Runtime.invokeSetter.
/// `setterKey` is the qualified handler key, e.g. `'Vm.count'`. Emitted by
/// the lowerer when the LHS of an AssignmentExpression is a PropertyAccess
/// whose receiver's static type is a registered class.
final class SetterCallNode extends ExpressionNode {
  const SetterCallNode({
    required this.target,
    required this.setterKey,
    required this.value,
  });
  final IrNode target;     // the receiver expression
  final String setterKey;  // e.g. 'Vm.count'
  final IrNode value;

  @override
  bool operator ==(Object other) =>
      other is SetterCallNode &&
      other.target == target &&
      other.setterKey == setterKey &&
      other.value == value;
  @override
  int get hashCode => Object.hash(target, setterKey, value);
  @override
  String toString() => 'SetterCallNode($target.$setterKey = $value)';
}
```

**Step 2 — Codec:** `'setterCall'` tag, payload `{target, setterKey, value}`. Mirror `GetterNode`'s codec entries.

**Step 3 — Verify + commit.**

---

## Task 3 — Resolver dispatches `SetterCallNode`

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart`

**Step 1 — Add the case** (near `GetterNode`):

```dart
case SetterCallNode(:final target, :final setterKey, :final value):
  final receiver = evalExpression(target, env, runtime);
  final v = evalExpression(value, env, runtime);
  runtime.invokeSetter(setterKey, receiver, v);
  return v; // Dart's assignment returns the RHS
```

**Note on env mutability:** if Feature 8 (mutable env / `_Cell`) is merged, `env` is `Map<String, _Cell>` — adjust the recursive calls accordingly. If Feature 8 ISN'T yet merged, this node still works against the legacy `Map<String, Object?>` env — only the local-var `AssignNode` requires cells. SetterCallNode mutates the receiver's field directly via the registered closure; env is just for resolving the receiver and value expressions.

**Step 2 — Verify + commit.**

---

## Task 4 — Codegen: emit `registerSetter` calls

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/type_collector.dart` (where public fields are currently collected for getter emission).
- Modify: the registration emitter where `registerGetter` calls are produced.

**Step 1 — Field eligibility check.** When walking a registered class's public fields, the existing pass emits a getter for each. Add a sibling check for setter eligibility:

```dart
bool _isSetterEligible(FieldElement field) {
  return field.isPublic
      && !field.isFinal
      && !field.isLate
      && !field.isStatic
      && !field.isSynthetic;
}
```

`isSynthetic` excludes fields generated by accessors; we only want real declarations.

**Step 2 — Emit `registerSetter`.** For each eligible field, after the existing `registerGetter` line, emit:

```dart
rt.registerSetter('TypeName.fieldName', (target, value) =>
    (target as TypeName).fieldName = value as FieldType);
```

Where `FieldType` is `field.type.getDisplayString(withNullability: true)`. Handles nullable types: `int?` field → `value as int?`.

**Step 3 — Generic type args in the receiver.** `Vm<T>` and similar: cast targets the simple class name (`Vm`) — generics are erased in the registration surface, matching how `registerGetter` already works. No special handling needed.

**Step 4 — Sealed-type setter consideration.** Sealed parent + subtypes: setters are emitted per subtype (each subtype has its own concrete fields). This falls out naturally from the per-class field walker — no extra logic.

**Step 5 — Reachability-driven emission.** The reachability walker (already in main per `cf4aa7d`) drives which classes' registrations are emitted into `setup.g.dart`. The new setter calls live inside the same per-class registration block; if the class is reachable, its setters come along automatically.

**Step 6 — Verify** by regenerating the demo and grepping for the new lines:

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
grep -n "registerSetter" packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart | head
```

Expected: at least one match per non-final field on each `@Register`-ed type used in screen bodies. (If no current demo has a non-final registered field, this is just plumbing — verify via Task 5's unit + integration tests.)

**Step 7 — Commit**

```
git commit -am "feat(codegen): emit registerSetter for non-final public fields"
```

---

## Task 5 — Lowerer: route `AssignmentExpression` to `SetterCallNode`

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`

**Step 1 — Extend the `AssignmentExpression` lowering** introduced by Feature 8. Today that path handles `SimpleIdentifier` LHS (local var). Add LHS variants:

```dart
if (expr is AssignmentExpression) {
  final lhs = expr.leftHandSide;

  // Existing: local variable assignment.
  if (lhs is SimpleIdentifier) {
    // ... existing AssignNode emission ...
  }

  // NEW: property-access assignment (vm.count = 0, vm.name = 'a').
  if (lhs is PrefixedIdentifier) {
    return _lowerSetterAssignment(
      receiverExpr: lhs.prefix,
      fieldName: lhs.identifier.name,
      value: expr.rightHandSide,
    );
  }
  if (lhs is PropertyAccess && lhs.target != null) {
    return _lowerSetterAssignment(
      receiverExpr: lhs.target!,
      fieldName: lhs.propertyName.name,
      value: expr.rightHandSide,
    );
  }

  // Cascade-style setters (..text = 'x') route through Cascades (Feature 7).
  throw InvalidScreenBodyError(
    'Unsupported assignment target: ${lhs.runtimeType}',
  );
}

SetterCallNode _lowerSetterAssignment({
  required Expression receiverExpr,
  required String fieldName,
  required Expression value,
}) {
  final receiverType = receiverExpr.staticType;
  final typeBucket = _classNameForType(receiverType); // e.g. 'Vm'
  if (typeBucket == null) {
    throw InvalidScreenBodyError(
      'Assignment to ${receiverExpr.toSource()}.$fieldName: receiver '
      'type ${receiverType?.getDisplayString(withNullability: false)} is '
      'not a registered class. Register the owner type with @Register or '
      'use a registered setter method.',
    );
  }
  return SetterCallNode(
    target: lowerExpression(receiverExpr),
    setterKey: '$typeBucket.$fieldName',
    value: lowerExpression(value),
  );
}
```

`_classNameForType(DartType?)` returns the simple class name if the type's library is part of the project / a registered package, else null. The lowerer already needs this kind of helper for ctor classification; reuse or extract.

**Step 2 — Compound assignments on fields.** `vm.count += 5` → `SetterCallNode(target, 'Vm.count', ArithOpNode('+', GetterNode(target, 'Vm.count'), LiteralNode(5)))`. Use the existing `GetterNode` on the receiver to read the current value, add, then write back via SetterCallNode. The double-evaluation of `target` is fine when target is a simple ref; for complex targets (rare), hoist with `LetNode`.

**Step 3 — Final-field rejection.** When the lowerer encounters `vm.max = 10` and the static type's `max` field is `final`, the resulting setter key (`'Vm.max'`) won't be in the registry (codegen omits setters for final fields). The runtime `invokeSetter` throws a clear error. To surface this at codegen-time instead of runtime, optionally check the field's `isFinal` flag during lowering and emit a static diagnostic:

```
Cannot assign to `Vm.max`: field is `final`. No setter registered. Expose a
setter method on Vm if assignment from payload is required.
```

This is a nicer DX. Implement it if the analyzer surface makes the check easy; otherwise rely on the runtime error and add the codegen check in a follow-up.

**Step 4 — Verify + commit.**

---

## Task 6 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_generator/test/setter_codegen_test.dart`
- Create: `packages/desk_sdui_generator/test/setter_assignment_lowering_test.dart`
- Create: `packages/desk_sdui/test/setter_call_eval_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/setter_demo.dart`

**Step 1 — Codegen tests.** Synthesize a `@Register([Vm])` where `Vm` has:
- `int count = 0;` (non-final) → expect `registerSetter('Vm.count', ...)` emitted.
- `final int max = 10;` → NO `registerSetter` emitted.
- `late int lateCount;` → NO `registerSetter` emitted (excluded by `isLate`).
- `static int total = 0;` → NO `registerSetter` (excluded by `isStatic`).
- `int _private = 0;` → NO `registerSetter` (excluded by `isPrivate`).
- `String? maybeName;` → emit with `value as String?`.

**Step 2 — Lowerer tests:**
1. `vm.count = 0;` lowers to `SetterCallNode(target: RefNode(['vm']), setterKey: 'Vm.count', value: LiteralNode(0))`.
2. `vm.count += 5` lowers to `SetterCallNode(... value: ArithOpNode('+', GetterNode(vm, 'Vm.count'), LiteralNode(5)))`.
3. `obj.deeplyNested.field = x` rejected (receiver not a simple ref; or accepted if `obj.deeplyNested` resolves to a registered type — verify behavior matches what the helper decides).
4. `vm.max = 10;` (final field) — either codegen-time diagnostic (preferred) or runtime error (fallback). Document chosen path in the commit.

**Step 3 — Resolver tests:**
1. Register a setter, build a SetterCallNode manually, evaluate — verify the target's field changed.
2. Setter receives the awaited/computed RHS value (not the IR node).
3. Assignment-expression form returns the RHS value (e.g. `final t = (vm.count = 5);` binds `t = 5`).
4. Invoking a non-registered setter throws StateError with the documented message.

**Step 4 — Demo.** Combine with the existing async-action / counter pattern:

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'setter_demo.sdui.g.dart';

@Register([SetterDemoController])
class SetterDemoController {
  int count = 0;
  String message = 'idle';
}

@Screen('setter_demo')
Widget setterDemo(SetterDemoController vm) {
  return Column(
    children: [
      Text('Count: ${vm.count}'),
      Text('Message: ${vm.message}'),
      ElevatedButton(
        onPressed: () {
          vm.count = vm.count + 1;
          vm.message = 'bumped to ${vm.count}';
        },
        child: const Text('Bump'),
      ),
    ],
  );
}
```

Note the `onPressed` here uses a sync block body with two statement-level setter assignments. That requires either:
- Feature 9 (BlockNode) for multi-statement sync handlers, OR
- A single-statement test (`vm.count = vm.count + 1;` only) until Feature 9 lands.

Use the single-statement variant if the test environment doesn't have Feature 9 yet:

```dart
onPressed: () { vm.count = vm.count + 1; },
```

**Step 5 — Verify** end-to-end:

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
grep -n "registerSetter('SetterDemoController" lib/desk_sdui_setup.g.dart
# expected: registerSetter for 'count' and 'message' (both non-final)

flutter test
flutter analyze
```

**Step 6 — Commit.**

---

## Task 7 — Full-suite verification

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui

for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done

(cd packages/desk_sdui_demo \
  && dart run build_runner build --delete-conflicting-outputs \
  && flutter analyze \
  && flutter test) || exit 1
```

---

## Out of scope (deliberately)

- **Indexed assignment** (`vm.list[0] = x`). Routes through registered `operator []=`; separate plan.
- **Null-aware assignment** (`vm.x ??= y`). Lower priority; add when a real use case appears.
- **Conditional assignment** (`vm.x = cond ? a : b`). RHS already supports ConditionalNode — no change needed for this pattern; falls out automatically.
- **Setter visibility filters beyond `isPrivate`.** If author wants payload-private state, declare the field `final` and expose a setter-emitting method.
- **Codegen-time enforcement of final-field-assignment errors.** Runtime error is sufficient; codegen-time diagnostic is a DX nice-to-have noted as optional in Task 5 Step 3.
- **Setters on getter-only types** (classes with `int get x => ...` but no field). These aren't fields; no setter emitted.
- **Cascade-form setters** (`vm..count = 0..message = 'x'`). Handled by Feature 7 (Cascades), which already routes setter sections through a `'fieldName='`-keyed method dispatch. Coordinate: Feature 7's setter path can simply call `runtime.invokeSetter` (introduced here) instead of going through methods. If Feature 7 lands before this plan, update Feature 7's setter-section lowering to emit `SetterCallNode` rather than the `'fieldName='` MethodCallNode.

---

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui

for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done

(cd packages/desk_sdui_demo \
  && dart run build_runner build --delete-conflicting-outputs \
  && flutter analyze \
  && flutter test) || exit 1
```
