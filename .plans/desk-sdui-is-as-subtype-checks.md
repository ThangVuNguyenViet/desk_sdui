# desk_sdui — Feature 19: `is` / `as` / subtype checks for payload classes

**Goal:** `order is Order` / `order as Order` runtime checks against payload-defined classes. Bridged-type checks (`x is String`) keep working via Feature 3's `IsTypeNode` (introduced for pattern matching).

**Dependencies:** Feature 15 (descriptors). Coordinate with Feature 3's `IsTypeNode` — extend or share it.

**Architecture:** Feature 3 already added `IsTypeNode` for sealed-class pattern matching (registered via `registerTypeCheck`). For payload classes, the type check walks `methodLookupOrder` looking for a name match. `AsTypeNode` does the same check + throws TypeError on mismatch.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

Reuse Feature 3's `IsTypeNode`. Add:

```dart
final class AsTypeNode extends ExpressionNode {
  const AsTypeNode({required this.operand, required this.typeName, required this.nullable});
  final IrNode operand;
  final String typeName;
  final bool nullable;  // `as Type?` vs `as Type`
}
```

Codec tag: `'asType'`.

---

## Task 2 — Resolver

Extend Feature 3's `IsTypeNode` case to also handle payload classes:

```dart
case IsTypeNode(:final receiver, :final typeName):
  final v = evalExpression(receiver, env, runtime);
  // 1. Payload-instance check.
  if (v is PayloadInstance) {
    for (final cls in v.type.methodLookupOrder) {
      if (cls.name == typeName) return true;
    }
    return false;
  }
  // 2. Bridged: fall through to registered type-check predicate.
  return runtime.checkType(typeName, v);

case AsTypeNode(:final operand, :final typeName, :final nullable):
  final v = evalExpression(operand, env, runtime);
  if (v == null) {
    if (nullable) return null;
    throw TypeError();
  }
  if (v is PayloadInstance) {
    for (final cls in v.type.methodLookupOrder) {
      if (cls.name == typeName) return v;
    }
    throw TypeError();
  }
  if (runtime.checkType(typeName, v)) return v;
  throw TypeError();
```

---

## Task 3 — Lowerer

`IsExpression` → `IsTypeNode`. `AsExpression` → `AsTypeNode` (carry the `?` from the type annotation).

The codegen needs to ensure both payload classes AND any bridged types used in `is`/`as` are registered for `runtime.checkType` (the latter is already covered by Feature 3's sealed-subtype emission).

---

## Task 4 — Tests + demo

Resolver: payload instance is its own class (true); is a supertype (true); is a mixin (true via mro); is unrelated type (false). `as` returns operand on match, throws on mismatch; `as T?` accepts null.

Demo: switch-on-type using a sealed payload hierarchy (`sealed class Event; class Click extends Event; class Hover extends Event;` — note "sealed" rejected at class decl, so use non-sealed inheritance instead, plus exhaustive switch via `_ =>` fallback).

---

## Out of scope

- Generic type-arg checks (`x is Order<String>`). Generics are erased.
- Pattern-matching `is` with field shorthand (`x is Order(:final id)`). That's Feature 3's pattern matching territory.

---

## Verify commands

(Standard suite.)
