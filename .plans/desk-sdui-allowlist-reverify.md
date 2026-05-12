# desk_sdui — Feature 25: Allowlist re-verification pass

**Goal:** Codegen-time recursive check that every leaf call inside payload class methods, mixins, and extensions resolves to (a) another payload-defined function/method, (b) a registered host method/widget/value-ctor, or (c) a built-in primitive operation. Anything else is a hard codegen error.

**Why:** Bucket 4 makes composition arbitrary; safety hinges on the *leaves* staying allowlisted. The verifier enforces this — without it, the safety property collapses.

**Dependencies:** Features 16-23 (everything that produces payload-call sites).

**Architecture:** Purely codegen-time. No IR changes, no runtime contribution.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Build the registered-leaves catalog

**File:** `packages/desk_sdui_generator/lib/src/allowlist/registry_index.dart`.

At codegen time, after the `type_collector` pass, build an in-memory index:

```dart
class RegistryIndex {
  final Set<String> registeredWidgets;          // 'Column', 'Padding', ...
  final Set<String> registeredValueBuilders;
  final Map<String, Set<String>> registeredMethods;  // 'String' → {'toUpperCase', ...}
  final Map<String, Set<String>> registeredGetters;
  final Map<String, Set<String>> registeredSetters;
  final Set<String> payloadFunctionNames;        // declared in current file (Feature 12)
  final Set<String> payloadClassNames;           // (Feature 16)
  final Set<String> payloadMixinNames;
  final Map<String, Set<String>> payloadExtensionMethods; // targetTypeName → method names
}
```

Built from existing collectors + parsed IR of the current file.

---

## Task 2 — Verifier walker

**File:** `packages/desk_sdui_generator/lib/src/allowlist/verifier.dart`.

Walk each `PayloadFunctionNode.body`, each `PayloadClassNode.methods[].body`, each mixin method body, each extension method body. For every node:

1. `MethodCallNode(receiver, name, args)` — bridged method call. Check `receiverType.name in registry.registeredMethods AND name in registry.registeredMethods[receiverType.name]`. Else: error.
2. `PayloadMethodCallNode(receiver, name, args)` — payload-class method call. Check `name` resolves via the receiver's payload-class mro. Else: error.
3. `PayloadExtensionCallNode(receiver, targetType, name)` — check extension registry.
4. `GetterNode(receiver, name)` — check `registry.registeredGetters`.
5. `SetterCallNode(target, setterKey, value)` — check `registry.registeredSetters` (Feature 14).
6. `PayloadFieldRefNode(receiver, name)` — verify field declared on the payload class.
7. `PayloadFunctionCallNode(name)` — must be in `registry.payloadFunctionNames`.
8. `WidgetNode` / `ValueCtorNode` — must be in `registeredWidgets` / `registeredValueBuilders`.
9. `RefNode([name])` — must resolve to a local binding (from a Let/Lambda/ctor param) OR an input (screen param).

Built-in primitive operations are always allowed: `ArithOpNode`, `CompareOpNode`, `LogicOpNode`, `NotOpNode`, `IsNullCheckNode`, `IsTypeNode`, `StringInterpNode`, `LiteralNode`, `ListNode`, `MapNode`, `RecordNode`, control-flow nodes (`BlockNode`, `IfStatementNode`, `WhileNode`, etc.).

---

## Task 3 — Diagnostic emission

```
error: payload method `Order.compute()` calls `Foo.bar()` at let_demo.dart:42:8,
       but `Foo` is not in any @Register list. Add `@Register([Foo])` to the
       host, or remove the call from payload-side code.
```

The verifier collects all violations before failing; reports them all at once for fast feedback.

For warnings (not blocking) — e.g. recursive call where size-decrease can't be proven — defer to Feature 26's classifier.

---

## Task 4 — Wire into the build pipeline

After lowering completes and before emission, run `verifier.verify(ir, registry)`. Any error → `BuildException` aborts codegen with all violations listed.

---

## Task 5 — Tests + demo

Tests:
1. Payload method calls registered `Iterable.where` → passes.
2. Payload method calls unregistered `MyHelper.compute` → error with line number.
3. Payload method calls another payload method → passes.
4. Payload method calls payload extension method → passes.
5. Built-in arithmetic in payload method → passes.
6. Field access on payload instance — field is declared → passes; undeclared → error.

Demo: a deliberately-broken `cost_demo_invalid.dart` that calls an unregistered method; verify the build fails with the documented diagnostic. Add to the test corpus (gated by a "must fail" build configuration).

---

## Out of scope

- Verifying payload-class field TYPES (e.g. `final Foo foo;` where `Foo` isn't registered) — could be a follow-up; field types matter less than method-call leaves.
- Cross-payload-file refs (each file verified in isolation).
- Inter-procedural type narrowing (e.g. `x as Foo; x.barWhichIsRegisteredOnFoo()`).

---

## Verify commands

(Standard suite.)
