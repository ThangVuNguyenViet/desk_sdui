# desk_sdui — Feature 18: Instance field access (read + write) on payload classes

**Goal:** `order.id` reads, `order.total = newTotal` writes if field is non-final.

**Dependencies:** Features 16 (class decls), 8 (AssignNode / mutable env), 14 (setter dispatch pattern, adapted for payload instances).

**Architecture:** Reuse Feature 14's `SetterCallNode` pattern, but route to the payload instance's `_Cell` rather than a registered setter handler. New `FieldRefNode` (or extension of GetterNode) handles reads.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

```dart
final class PayloadFieldRefNode extends ExpressionNode {
  const PayloadFieldRefNode({required this.receiver, required this.fieldName});
  final IrNode receiver;
  final String fieldName;
}

final class PayloadFieldAssignNode extends ExpressionNode {
  const PayloadFieldAssignNode({required this.receiver, required this.fieldName, required this.value});
  final IrNode receiver;
  final String fieldName;
  final IrNode value;
}
```

Codec tags: `'payloadFieldRef'`, `'payloadFieldAssign'`.

---

## Task 2 — Resolver

```dart
case PayloadFieldRefNode(:final receiver, :final fieldName):
  final inst = evalExpression(receiver, env, runtime) as PayloadInstance;
  final cell = inst.fields[fieldName];
  if (cell == null) {
    throw StateError('No field "$fieldName" on ${inst.type.name}');
  }
  return cell.value;

case PayloadFieldAssignNode(:final receiver, :final fieldName, :final value):
  final inst = evalExpression(receiver, env, runtime) as PayloadInstance;
  final cell = inst.fields[fieldName];
  if (cell == null) {
    throw StateError('No field "$fieldName" on ${inst.type.name}');
  }
  final v = evalExpression(value, env, runtime);
  cell.value = v;
  return v;
```

The runtime trusts the codegen guarantee that field is non-final — final-field assignment is rejected at lowering.

---

## Task 3 — Lowerer

`PropertyAccess` / `PrefixedIdentifier` on a payload-instance receiver → `PayloadFieldRefNode`. Existing `GetterNode` path (for bridged types) is untouched.

`AssignmentExpression` with LHS `receiver.field`:
- Receiver type is bridged → existing Feature 14 `SetterCallNode` path.
- Receiver type is a payload class → `PayloadFieldAssignNode`.

Reject assignment to a final payload field at codegen with diagnostic:
> Cannot assign to `Order.id`: field is `final`.

---

## Task 4 — Tests + demo

Lowerer: payload-instance field read → PayloadFieldRefNode; bridged read still GetterNode; payload-instance field write → PayloadFieldAssignNode; final field write rejected.

Resolver: read via PayloadFieldRefNode returns the cell's value; write updates the cell; cross-instance writes don't bleed.

Demo: a `Counter` payload class with `int count = 0;` field; mutate from an action handler.

---

## Out of scope

- Getter/setter methods declared on payload classes (`int get total => ...`). Could lower as a regular method named `total`; defer.
- Static fields. Rejected at class decl in Feature 16.

---

## Verify commands

(Standard suite.)
