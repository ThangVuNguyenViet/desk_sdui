# desk_sdui — Feature 17: Instance method dispatch on payload classes

**Goal:** `order.applyDiscount(0.5)` on a `PayloadInstance` walks that method's body with `this` bound, supports super-class + mixin dispatch via mro.

**Dependencies:** Features 15 (descriptors), 16 (class declarations), 12 (payload function body walker).

**Architecture:**
- New IR node `PayloadMethodCallNode { receiver, methodName, args }`.
- Resolver walks `receiver.type.methodLookupOrder` until a class carrying `methodName` is found.
- Method body executes with `this` bound in env; field reads go through `ThisFieldRefNode`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

```dart
final class PayloadMethodCallNode extends ExpressionNode {
  const PayloadMethodCallNode({required this.receiver, required this.methodName, required this.args});
  final IrNode receiver;
  final String methodName;
  final Map<String, IrNode> args;
}

final class ThisFieldRefNode extends ExpressionNode {
  const ThisFieldRefNode({required this.fieldName});
  final String fieldName;
}

final class ThisRefNode extends ExpressionNode { const ThisRefNode(); }
```

Codec tags: `'payloadMethodCall'`, `'thisFieldRef'`, `'thisRef'`.

---

## Task 2 — Resolver

```dart
case PayloadMethodCallNode(:final receiver, :final methodName, :final args):
  final inst = evalExpression(receiver, env, runtime) as PayloadInstance;
  PayloadFunctionNode? fn;
  for (final cls in inst.type.methodLookupOrder) {
    if (cls.methods.containsKey(methodName)) {
      fn = cls.methods[methodName]; break;
    }
  }
  if (fn == null) {
    throw NoSuchMethodError.withInvocation(inst, Invocation.method(Symbol(methodName), []));
  }
  // Build callee env: this + params bound.
  final calleeEnv = <String, _Cell>{
    'this': _Cell(inst),
    for (var i = 0; i < fn.params.length; i++)
      fn.params[i]: _Cell(_evalArg(args, fn.params[i], i, env, runtime)),
  };
  // Execute body.
  final body = fn.body;
  if (body is BlockNode) {
    final flow = executeStatement(body, calleeEnv, runtime);
    return flow is FlowReturn ? flow.value : null;
  }
  return evalExpression(body, calleeEnv, runtime);

case ThisFieldRefNode(:final fieldName):
  final inst = env['this']?.value as PayloadInstance;
  return inst.fields[fieldName]?.value;

case ThisRefNode():
  return env['this']?.value;
```

---

## Task 3 — Lowerer

`MethodInvocation` where receiver's static type resolves to a payload class declared in the same file → `PayloadMethodCallNode`. Receivers on bridged types keep the existing `MethodCallNode` path.

Inside payload method bodies:
- `this.id` (or bare `id` when `id` is a field) → `ThisFieldRefNode`.
- `this` alone → `ThisRefNode`.
- `this.applyDiscount(...)` (or bare `applyDiscount(...)` when no local shadowing) → `PayloadMethodCallNode(receiver: ThisRefNode())`.

The lowerer needs a "current class" stack to resolve unqualified field/method references inside method bodies.

---

## Task 4 — Tests + demo

Resolver tests: method resolves on declaring class; method resolves on supertype; mixin override wins (Feature 20 coordination — initially test with no mixins); NoSuchMethodError on unknown method.

Lowerer tests: payload-instance method call lowers to PayloadMethodCallNode; bridged-receiver method call still lowers to MethodCallNode; bare `field` inside method body lowers to ThisFieldRefNode.

Demo: `Money` class with `Money add(Money other) => Money(cents + other.cents);` exercised in a screen.

---

## Out of scope

- Super-class super-calls (`super.method()`). Add later via `SuperMethodCallNode`.
- Async method bodies — same gate as Feature 2 (`inActionContext` only).
- Method tear-offs (`order.applyDiscount` as a value) — Feature 23.

---

## Verify commands

(Standard suite.)
