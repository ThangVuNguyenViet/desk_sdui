# desk_sdui — Feature 15: Runtime class descriptors + `PayloadInstance`

**Goal:** Runtime data structures for payload-defined classes and their instances. Foundation for Features 16-26 (bucket 4 / dart_eval feature parity).

**Dependencies:** none from bucket 4 (this is the foundation). Practically needs bucket 3 to be useful — without statement loops + mutation, payload-class methods are too limited.

**Architecture:**
- `PayloadClass` descriptor (name, supertype, mixins, methods, fieldInitializers, ctor params, ctor body, mro).
- `PayloadInstance { PayloadClass type; Map<String, _Cell> fields }` — reuses `_Cell` from Feature 8 (no `$Value` boxing).
- `Runtime.payloadClasses: Map<String, PayloadClass>` populated by codegen at startup.
- mro computed at class-load (`registerPayloadClass`) and cached on the descriptor.

**Tech stack:** runtime support only. No IR changes, no lowerer changes.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Define types in `package:desk_sdui`

**File:** create `packages/desk_sdui/lib/src/payload_class.dart`.

```dart
import 'cell.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

class PayloadClass {
  PayloadClass({
    required this.name,
    this.supertype,
    this.mixins = const [],
    this.methods = const {},
    this.fieldInitializers = const {},
    this.ctorParams = const [],
    this.ctorBody,
  });

  final String name;
  final PayloadClass? supertype;
  final List<PayloadClass> mixins;
  final Map<String, PayloadFunctionNode> methods;
  final Map<String, IrNode> fieldInitializers;
  final List<String> ctorParams;
  final IrNode? ctorBody;

  /// Resolved at registration time. Drives method dispatch (Feature 17).
  late final List<PayloadClass> methodLookupOrder;
}

class PayloadInstance {
  PayloadInstance({required this.type, required this.fields});
  final PayloadClass type;
  final Map<String, _Cell> fields;
  @override
  String toString() => '${type.name}(${fields.entries.map((e) => "${e.key}: ${e.value.value}").join(", ")})';
}
```

`PayloadFunctionNode` comes from Feature 12 (already in IR annotation package).

---

## Task 2 — Runtime registry

**File:** modify `packages/desk_sdui/lib/src/runtime.dart`.

```dart
final Map<String, PayloadClass> _payloadClasses = {};

Map<String, PayloadClass> get payloadClasses => _payloadClasses;

void registerPayloadClass(PayloadClass cls) {
  if (_payloadClasses.containsKey(cls.name)) {
    throw StateError('PayloadClass "${cls.name}" already registered.');
  }
  _payloadClasses[cls.name] = cls;
  cls.methodLookupOrder = _computeMro(cls);
}

List<PayloadClass> _computeMro(PayloadClass cls) {
  // C3 linearization light: self → reversed mixins → supertype mro.
  final order = <PayloadClass>[cls];
  for (final m in cls.mixins.reversed) {
    order.add(m);
  }
  if (cls.supertype != null) {
    order.addAll(cls.supertype!.methodLookupOrder);
  }
  return order;
}
```

---

## Task 3 — Tests

**File:** create `packages/desk_sdui/test/payload_class_test.dart`.

Cases:
1. `registerPayloadClass(simple)` adds the entry; `payloadClasses['Order']` returns it.
2. Duplicate registration throws StateError.
3. `methodLookupOrder` for a class with no supertype + no mixins → `[self]`.
4. `methodLookupOrder` for class A with mixin M, M2 → `[A, M2, M]` (reversed mixin order).
5. Inheriting from another payload class: B extends A → B's mro = `[B, ...A.mro]`.
6. `PayloadInstance` toString includes class name and field values.

---

## Task 4 — Verify + commit

```
cd packages/desk_sdui && dart analyze && dart test
git commit -am "feat(runtime): PayloadClass descriptors + PayloadInstance (bucket 4 foundation)"
```

---

## Out of scope

- Inheritance from bridged classes (supertype must be Object or payload).
- Class-level annotations.
- Static methods on payload classes (could add, low priority).
- `Type` literals (Feature 24).

---

## Verify commands

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done
```
