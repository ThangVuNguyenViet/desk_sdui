# desk_sdui — Feature 20: Mixin linearization + dispatch

**Goal:** `class Order with Discountable, Auditable { ... }`. Mixin methods callable on instances; mro determines which override wins.

**Dependencies:** Feature 17 (method dispatch).

**Architecture:** Mixins are PayloadClass descriptors marked as non-instantiable. `Runtime._computeMro` already handles mixin reversal (rightmost-priority); this plan adds the mixin AST → IR path and `on TypeX` constraint checking.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

```dart
final class PayloadMixinNode extends IrNode {
  const PayloadMixinNode({required this.name, required this.onTypes, required this.fields, required this.methods});
  final String name;
  final List<String> onTypes;           // `mixin Foo on Bar`
  final List<PayloadFieldDeclNode> fields;
  final List<PayloadFunctionNode> methods;
}
```

Codec tag: `'payloadMixin'`.

The wrapping `ScreenWith…Node` (extended in Feature 16) now also carries `List<PayloadMixinNode> mixins`.

---

## Task 2 — Runtime: mixin → PayloadClass adapter

A mixin is a `PayloadClass` with no ctor:

```dart
void registerPayloadMixin(PayloadMixinNode m) {
  registerPayloadClass(PayloadClass(
    name: m.name,
    methods: { for (final fn in m.methods) fn.name: fn },
    fieldInitializers: { for (final f in m.fields) f.name: f.initializer ?? LiteralNode(null) },
    // ctor: synthesized empty
    ctorParams: const [],
    ctorBody: null,
  ));
}
```

`PayloadMixin` and `PayloadClass` share the descriptor for simplicity. Mixins are flagged as non-instantiable by an additional `isMixin: bool` field on `PayloadClass`; `registerPayloadClass` allows creating instances only when `!isMixin`.

---

## Task 3 — Lowerer

`MixinDeclaration` → `PayloadMixinNode`.

For each `ClassDeclaration` with a `with` clause: collect `mixinNames`. After all mixins + classes are lowered, validate each class's `on TypeX` constraints — for each mixin in the class's mixin list, check the mixin's `onTypes` against the class's own mro. If a constraint isn't satisfied, codegen error:

> Mixin `Discountable on Pricable` cannot be applied to `Order`: `Order` does not satisfy `Pricable`.

---

## Task 4 — Codegen emission

Emit `rt.registerPayloadMixin(...)` calls in the setup file for each lowered mixin, in declaration order. Mixins must be registered BEFORE classes that use them, so `methodLookupOrder` resolution at class registration finds them.

---

## Task 5 — Tests + demo

Tests:
1. Class with mixin gets mixin methods.
2. Two mixins with same method name — rightmost wins (`with M1, M2` → M2 priority).
3. Mixin field initializer runs at instance allocation.
4. `on TypeX` constraint enforced — non-satisfying class rejected at codegen.

Demo: payload `mixin Loggable { void log(String msg) { /* registered console.log call */ } }` applied to a class; instance method calls `log`.

---

## Out of scope

- Diamond inheritance edge cases beyond what Dart resolves.
- Mixins applied to bridged classes — host-side concern.
- Mixin generics.

---

## Verify commands

(Standard suite.)
