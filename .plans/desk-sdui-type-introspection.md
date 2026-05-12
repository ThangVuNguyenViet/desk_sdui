# desk_sdui — Feature 24: Type introspection (`runtimeType`)

**Goal:** `instance.runtimeType` returns a value comparable to other types. Within-payload reflection only — does NOT extend to bridged AOT types beyond best-effort class-name strings.

**Dependencies:** Feature 15 (descriptors).

**Architecture:** `RuntimeTypeRefNode` wraps `.runtimeType` access. Resolver returns a `PayloadTypeValue { PayloadClass cls }` for payload instances; for bridged values returns a registered class-name string.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR + runtime types

```dart
final class RuntimeTypeRefNode extends ExpressionNode {
  const RuntimeTypeRefNode({required this.operand});
  final IrNode operand;
}

class PayloadTypeValue {
  PayloadTypeValue(this.cls);
  final PayloadClass cls;
  @override
  bool operator ==(Object other) => other is PayloadTypeValue && other.cls.name == cls.name;
  @override
  int get hashCode => cls.name.hashCode;
  @override
  String toString() => cls.name;
}
```

Codec tag: `'runtimeTypeRef'`.

---

## Task 2 — Resolver

```dart
case RuntimeTypeRefNode(:final operand):
  final v = evalExpression(operand, env, runtime);
  if (v is PayloadInstance) {
    return PayloadTypeValue(v.type);
  }
  if (v == null) return 'Null'; // string fallback for bridged null
  // Bridged value: return the registered class-name string.
  return runtime.typeNameOf(v) ?? v.runtimeType.toString();
```

`runtime.typeNameOf(v)` checks registered type predicates (Feature 3 / 19): finds the registered type whose predicate returns true for `v`, returns that name. Fallback: native `runtimeType.toString()` — minified at release time but still useful for debugging.

---

## Task 3 — Lowerer

`PropertyAccess` named `runtimeType` → `RuntimeTypeRefNode`.

---

## Task 4 — Tests + demo

Tests:
1. `order.runtimeType` returns a `PayloadTypeValue` whose `cls.name == 'Order'`.
2. Two instances of same payload class produce equal `PayloadTypeValue`s.
3. `'hello'.runtimeType.toString() == 'String'`.
4. `null.runtimeType.toString() == 'Null'`.

Demo: a screen that switches on `event.runtimeType` (combine with Feature 3 pattern matching for the natural form).

---

## Out of scope

- `Type` literals (`Order` used as a value, not in `is`/`as` context). Could add but requires more lowerer work.
- Reflective method invocation by name. Authors use a registered helper.
- Full equality with Dart's `Type` objects from `runtime` mirror APIs.

---

## Verify commands

(Standard suite.)
