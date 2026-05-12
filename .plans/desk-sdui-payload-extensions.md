# desk_sdui — Feature 21: Extension method dispatch

**Goal:** `extension StringX on String { String shout() => toUpperCase() + '!'; }`. Adds methods to existing bridged types from within the payload.

**Dependencies:** Feature 17 (method dispatch shape).

**Architecture:** Separate `payloadExtensions` registry keyed by target-type name. Method dispatch at call site tries native registered methods first, then extensions matching the receiver's runtime type.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR node

```dart
final class PayloadExtensionNode extends IrNode {
  const PayloadExtensionNode({required this.name, required this.targetTypeName, required this.methods});
  final String name;
  final String targetTypeName;
  final List<PayloadFunctionNode> methods;
}
```

Codec tag: `'payloadExtension'`.

---

## Task 2 — Runtime registry

```dart
final Map<String, List<PayloadExtensionNode>> _payloadExtensions = {};

void registerPayloadExtension(PayloadExtensionNode ext) {
  _payloadExtensions.putIfAbsent(ext.targetTypeName, () => []).add(ext);
}

PayloadFunctionNode? resolveExtensionMethod(String receiverTypeName, String methodName) {
  for (final ext in _payloadExtensions[receiverTypeName] ?? const []) {
    for (final m in ext.methods) {
      if (m.name == methodName) return m;
    }
  }
  return null;
}
```

Receiver's runtime type name: for a `PayloadInstance`, it's `inst.type.name`; for bridged values, the runtime needs a `typeNameOf(value)` helper that uses registered `registerTypeCheck` (Feature 3) to find the best match. For built-ins, hard-code: `String → 'String'`, `int → 'int'`, `List → 'List'`, etc.

---

## Task 3 — Lowerer

`ExtensionDeclaration` → `PayloadExtensionNode`.

At `MethodInvocation` lowering, when receiver's static type doesn't have `methodName` as a registered method AND doesn't have it as a payload-class method, try the extension registry. If found, emit a `PayloadMethodCallNode` whose receiver is the original target and whose `methodName` is the extension method — but the receiver lookup goes via the extension table at resolve time. Need a discriminator: introduce a `viaExtension: bool` flag on `PayloadMethodCallNode`, OR a new node `PayloadExtensionCallNode`:

```dart
final class PayloadExtensionCallNode extends ExpressionNode {
  const PayloadExtensionCallNode({required this.receiver, required this.targetTypeName, required this.methodName, required this.args});
  final IrNode receiver;
  final String targetTypeName;
  final String methodName;
  final Map<String, IrNode> args;
}
```

Resolver: look up via `runtime.resolveExtensionMethod`; bind `this` to receiver; execute body.

---

## Task 4 — Tests + demo

Tests: extension on String registered; `'hi'.shout()` resolves to extension method; native method has priority over extension; extension method chains (`x.shout().toLowerCase()`).

Demo: `extension OrderX on Order { String label() => 'Order ${id}: \$${total}'; }`; screen displays `order.label()`.

---

## Out of scope

- Conflicting extensions on same type (specificity rules) — emit codegen warning, prefer first declared.
- Generic extensions (`extension<T> ListX on List<T>`).
- Extension types (Dart 3 introduced opaque-wrapper extension types — distinct feature).

---

## Verify commands

(Standard suite.)
