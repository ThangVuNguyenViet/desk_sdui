# desk_sdui — Feature 23: First-class function values

**Goal:** Payload-defined functions/methods passed as `Function` parameters or stored on objects. `final reducer = (a, b) => a + b; items.fold(0, reducer);`. Also method tear-offs: `o.applyDiscount` as a callable value.

**Dependencies:** Feature 17 (method dispatch), Feature 2 (LambdaNode).

**Architecture:** `PayloadFunctionValueNode` wraps either a payload-function name or a `LambdaNode`. The resolver produces a native Dart `Function` (closure) that captures env + dispatches to the body when called. Callable from registered host code or via `PayloadMethodCallNode`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR node

```dart
final class PayloadFunctionValueNode extends ExpressionNode {
  const PayloadFunctionValueNode({
    this.functionName,
    this.lambda,
    this.methodTearoff,
    required this.capturedEnvKeys,
  });
  final String? functionName;       // payload-private function name in the current file
  final LambdaNode? lambda;         // inline lambda
  final _MethodTearoff? methodTearoff; // o.applyDiscount style
  final List<String> capturedEnvKeys; // env names the body might read (for closure capture)
}

class _MethodTearoff {
  _MethodTearoff({required this.receiver, required this.methodName});
  final IrNode receiver;
  final String methodName;
}
```

Codec tag: `'payloadFnValue'`.

Exactly one of the three forms is non-null.

---

## Task 2 — Resolver

```dart
case PayloadFunctionValueNode(:final functionName, :final lambda, :final methodTearoff, :final capturedEnvKeys):
  // Capture env (only the keys we know are referenced).
  final captured = <String, _Cell>{for (final k in capturedEnvKeys) k: env[k]!};
  if (functionName != null) {
    final fn = ctx.payloadFunctions[functionName]!;
    return _makeFunction(fn, captured, runtime);
  }
  if (lambda != null) {
    return _makeLambdaFunction(lambda, captured, runtime);
  }
  if (methodTearoff != null) {
    final inst = evalExpression(methodTearoff.receiver, env, runtime) as PayloadInstance;
    return _makeTearoff(inst, methodTearoff.methodName, runtime);
  }
  throw StateError('empty PayloadFunctionValueNode');
```

`_makeFunction` returns a Dart `Function` that takes runtime-discovered args and dispatches to the body via Feature 12's executor:

```dart
Function _makeFunction(PayloadFunctionNode fn, Map<String, _Cell> captured, Runtime rt) {
  if (fn.params.length == 1) {
    return (Object? a0) {
      final callEnv = {...captured, fn.params[0]: _Cell(a0)};
      return executePayloadFunctionBody(fn.body, callEnv, rt);
    };
  }
  if (fn.params.length == 2) {
    return (Object? a0, Object? a1) {
      final callEnv = {...captured, fn.params[0]: _Cell(a0), fn.params[1]: _Cell(a1)};
      return executePayloadFunctionBody(fn.body, callEnv, rt);
    };
  }
  // 0-, 3-, 4-param variants similar. >4 throws.
  throw StateError('Payload Function values support 0-4 params');
}
```

(`executePayloadFunctionBody` handles BlockNode-vs-expression body.)

---

## Task 3 — Lowerer

Detect three forms producing a function value:
1. Bare identifier whose name is a payload function declaration AND the use is in a value position (not a call site) → `PayloadFunctionValueNode(functionName: name)`.
2. Inline `FunctionExpression` (e.g. arrow lambda) in a value position → `PayloadFunctionValueNode(lambda: LambdaNode(...))`.
3. `PropertyAccess` where the property is a method name on the receiver type AND no `(args)` follows → `PayloadFunctionValueNode(methodTearoff: ...)`.

The lowerer's "in a call site" detector: parent AST is `MethodInvocation` whose `methodName` is THIS identifier/access — then it's a call, not a value.

Compute `capturedEnvKeys` by walking the body and collecting free names that resolve to enclosing scope (not params, not field accesses on `this`).

---

## Task 4 — Tests + demo

Tests: payload function passed to `.fold` runs over each element; lambda passed to `.where` filters; method tear-off (`o.applyDiscount`) callable; closure captures outer let-bound name.

Demo: a screen that filters a list using a payload-defined predicate function.

---

## Out of scope

- Storing function values on bridged-object fields (requires setter dispatch + type-erased Function setters).
- Async function values outside action context — same gate as Feature 2.
- Function values with 5+ params.

---

## Verify commands

(Standard suite.)
