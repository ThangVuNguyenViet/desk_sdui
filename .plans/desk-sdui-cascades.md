# desk_sdui — Cascades

**Goal:** Support `obj..a()..b()..c` cascade syntax in `@Screen` bodies. Common Flutter pattern for setup (`TextEditingController()..text = 'x'`). Today forces author to break into multiple statements.

**Dependencies:**
- `ActionSequenceNode` (Feature 4) must be merged — cascade lowers to an ActionSequenceNode-like sequence that returns the receiver.
- `LetNode` (Feature 1) must be merged — receiver is hoisted into a let so it's evaluated once.

**Architecture:** Bucket 1 — pure lowering, no new runtime machinery. The cascade `obj..a()..b()` lowers to:

```
LetNode(name: '__cas__', value: obj, body:
  SequenceNode(steps: [
    a(__cas__),
    b(__cas__),
  ], returnRef: RefNode(['__cas__']))
)
```

We **don't** reuse `ActionSequenceNode` directly because cascades are sync (they happen during build) and `ActionSequenceNode`'s resolved value is a `Future<void> Function()`. Cascades need a synchronous "run these in order, return X" node. Introduce a small new `SequenceNode { steps, returnRef }`.

**Tech stack:** existing IR + new `SequenceNode`, lowerer, generator emitter.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Add `SequenceNode` to the IR

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the node:**

```dart
/// Evaluates each step in `steps` in order (synchronously), then evaluates
/// and returns `returnExpr`. Used by cascade lowering: each step is a
/// side-effecting call on the cascade receiver, and `returnExpr` references
/// the receiver (typically via a Let-bound name).
///
/// Distinct from ActionSequenceNode: this is synchronous and returns a value
/// (the receiver). ActionSequenceNode is async and returns a Future<void>
/// Function() for event-handler slots.
final class SequenceNode extends ExpressionNode {
  const SequenceNode({required this.steps, required this.returnExpr});
  final List<IrNode> steps;
  final IrNode returnExpr;

  @override
  bool operator ==(Object other) =>
      other is SequenceNode &&
      _listEq(other.steps, steps) &&
      other.returnExpr == returnExpr;
  @override
  int get hashCode => Object.hash(Object.hashAll(steps), returnExpr);
  @override
  String toString() => 'SequenceNode(${steps.length} steps, return $returnExpr)';
}
```

**Step 2 — Codec:** `'sequence'` tag, payload `{steps, returnExpr}`. Mirror existing patterns.

**Step 3 — Verify + commit.**

---

## Task 2 — Resolver evaluates SequenceNode

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart`

**Step 1 — Add the case:**

```dart
case SequenceNode(:final steps, :final returnExpr):
  for (final step in steps) {
    evalExpression(step, input, runtime);
    // Side effect: step is a method call on the receiver. Return value ignored.
  }
  return evalExpression(returnExpr, input, runtime);
```

**Step 2 — Verify + commit.**

---

## Task 3 — Lowerer recognizes `CascadeExpression`

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart` (or wherever cascade currently fails — `grep -rn "CascadeExpression" packages/desk_sdui_generator/lib/src/`).

**Step 1 — Recognize the AST shape:**

```dart
if (expr is CascadeExpression) {
  return _lowerCascade(expr);
}
```

Where `_lowerCascade(expr)`:

```dart
IrNode _lowerCascade(CascadeExpression expr) {
  final receiver = lowerExpression(expr.target);
  final casName = '__cas_${_freshId()}__';
  final ref = RefNode([casName]);

  final steps = <IrNode>[];
  for (final section in expr.cascadeSections) {
    steps.add(_lowerCascadeSection(section, ref));
  }

  return LetNode(
    name: casName,
    value: receiver,
    body: SequenceNode(steps: steps, returnExpr: ref),
  );
}

IrNode _lowerCascadeSection(Expression section, RefNode receiver) {
  // section is one of:
  //   - MethodInvocation (`..a()`)
  //   - AssignmentExpression with LHS PropertyAccess where target is implicit (`..text = 'x'`)
  //   - PropertyAccess (`..foo` — bare property reference, rare; reject)
  if (section is MethodInvocation) {
    // Rewrite: treat as `receiver.method(args)`.
    // Build a MethodCallNode with `receiver` as the explicit target.
    return MethodCallNode(
      target: receiver,
      method: section.methodName.name,
      args: section.argumentList.arguments
          .map(lowerExpression)
          .toList(),
      // namedArgs handled similarly
    );
  }
  if (section is AssignmentExpression) {
    final lhs = section.leftHandSide;
    if (lhs is PropertyAccess && lhs.isCascaded) {
      final setterName = lhs.propertyName.name;
      // Setter form: `..text = 'x'` requires a registered setter on the receiver type.
      // Lower as a MethodCallNode named '${name}=' (Dart convention for setter dispatch).
      return MethodCallNode(
        target: receiver,
        method: '$setterName=',
        args: [lowerExpression(section.rightHandSide)],
      );
    }
    throw InvalidScreenBodyError(
      'Unsupported cascade section: ${section.runtimeType}. '
      'Only method invocations (..a()) and simple setter assignments (..foo = x) are supported.',
    );
  }
  throw InvalidScreenBodyError(
    'Unsupported cascade section: ${section.runtimeType}.',
  );
}
```

**Step 2 — Setter dispatch.** Setter sections lower to a method call named `'<setter>='`. The runtime needs to look up the registered method by that name. Either:
- Codegen emits both `'text'` (getter) and `'text='` (setter) for properties on registered types. Most types don't currently have setter dispatch registered — extend the type collector to walk setters for registered classes and emit `registerMethod('TypeName.fieldName=', ...)`.
- Alternative: emit a generic "assign field" closure per registered type that does `(target, value) => target.field = value`. Cleaner per-class wrapper.

**Pick the first approach** for consistency with existing method dispatch. Wire it in `type_collector.dart` (extend the ctor-param walker to also walk public setters of registered classes).

**Step 3 — `?..` null-aware cascade.** Reject with a diagnostic for now. Document as out-of-scope.

**Step 4 — Verify + commit.**

---

## Task 4 — Type collector emits registerMethod for setters

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/type_collector.dart`
- Modify: the registration emitter.

**Step 1 — When walking a registered class**, in addition to ctors and getters/static-consts, walk public setters:

```dart
for (final accessor in cls.accessors) {
  if (accessor.isSetter && accessor.isPublic) {
    setters.add(accessor.displayName); // 'text' (without the '=')
  }
}
```

**Step 2 — Emit `registerMethod` for each setter** in the catalog file:

```dart
rt.registerMethod('TextEditingController.text=', (target, args) {
  (target as TextEditingController).text = args[0] as String;
  return null;
});
```

**Step 3 — Conditional emission.** Only emit setters for classes that actually appear as cascade receivers in the screen bodies (cuts noise). The reachability walker that drives the import emitter can be extended to also record "cascade-receiver" usages and gate setter emission on those.

**Step 4 — Verify + commit.**

---

## Task 5 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_generator/test/cascade_lowering_test.dart`
- Create: `packages/desk_sdui/test/sequence_node_eval_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/cascade_demo.dart`

**Step 1 — Lowerer tests:**
1. `obj..a()..b()` lowers to `LetNode('__casN__', obj, SequenceNode([a(ref), b(ref)], ref))`.
2. `obj..a()..b()..c` returns the receiver, NOT the last cascade section's value.
3. `TextEditingController()..text = 'hi'` lowers with a `TextEditingController.text=` MethodCallNode in the sequence.
4. Reject `?..a()` (null-aware) with diagnostic.
5. Reject cascade on chained-expression receiver (`a.b..c()`) — receiver must be simple ref/ctor.

**Step 2 — Resolver test:**
- Build a SequenceNode by hand, register a method that side-effects (e.g. appends to a list), verify steps run in order and return value is the explicit `returnExpr` (not the last step's result).

**Step 3 — Demo screen:**

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'cascade_demo.sdui.g.dart';

class CascadeController {
  final TextEditingController controller = TextEditingController();
}

@Screen('cascade_demo')
Widget cascadeDemo(CascadeController vm) {
  return TextField(
    controller: vm.controller..text = 'initial',
  );
}
```

Verify the generated IR contains a `LetNode` wrapping a `SequenceNode` whose single step is a `TextEditingController.text=` MethodCallNode.

**Step 4 — Regen + verify + commit.**

---

## Task 6 — Full-suite verification

(Standard.)

---

## Out of scope

- **Null-aware cascades** (`obj?..a()`).
- **Cascades on chained receivers** (`a.b..c()`).
- **Cascades returning the last-section value** (Dart's `obj..a().b` syntax). Cascade always returns the receiver.
- **Indexed setter** (`obj..[0] = x`). Future plan.
- **Cascades inside async handlers.** Should work transparently — the cascade lowers to a sync SequenceNode, which is a valid expression inside an `ActionStepNode.call`. Test via Task 5 if practical; otherwise document as believed-to-work and add when a real demo exercises it.

---

## Verify commands

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
