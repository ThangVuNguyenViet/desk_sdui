# desk_sdui — bucket 4: payload-defined types (dart_eval feature parity)

**Goal:** Add payload-side `class`, `mixin`, `extension`, operator overloading, and first-class function values to reach feature parity with dart_eval. After this lands, payloads can model new domain types and ship them from the server without app updates — at ~7-8% of dart_eval's binary cost and 2-4× faster per-op performance.

**Depends on:** [bucket 1+2+3 expressiveness roadmap](./desk-sdui-bucket-1-and-2-roadmap.md). Specifically `LetNode` (F1), `LambdaNode` (F2), `BlockNode` + control flow (F9), `AssignNode` (F8), statement loops (F10), payload function declarations (F12), cost classifier (F13), setter codegen (F14).

**Adds to runtime:** ~30-50 KB on top of bucket 3 (cumulative total: ~60-100 KB runtime, vs flutter_eval's ~1.5-2 MB).

**Trade-off acknowledged:** this bucket shifts the system identity from "closed-set executor over a registered catalog" to "constrained interpreter over registered leaves." Payload composition becomes arbitrary; payload leaves (native calls) remain allowlisted. See [why-not-flutter-eval.md](../docs/design/why-not-flutter-eval.md) "Author guide" for the per-tier breakdown.

**Out of scope:**
- Generators (`sync*` / `async*`) — universal skip.
- `dart:mirrors` on host AOT types — Flutter-disabled for both systems.
- FFI / isolates from payload — impossible.
- Inter-call generic type inference (`T identity<T>(T x)`). Ctor-level generic carriage (Feature 5) covers the common cases; full inference would require a runtime type system we don't ship.
- Migration tooling for existing payload code.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Verify per feature:**
```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter analyze
```

---

## Suggested dispatch order

```
15. Runtime class descriptors + PayloadInstance       (foundation)
16. Payload class declarations + constructor lowering (builds on 15)
17. Instance method dispatch                          (builds on 16; uses F12 body walker)
18. Instance field access (read + write)              (builds on 16; uses F8 cells)
19. is / as / subtype checks                          (builds on 15)
20. Mixin linearization + dispatch                    (builds on 17)
21. Extension method dispatch                         (builds on 17; orthogonal registry)
22. Operator overloading                              (builds on 17)
23. First-class function values (PayloadFunctionValue) (builds on 17 + F2)
24. Type introspection (runtimeType)                  (builds on 15)
25. Allowlist re-verification pass                    (codegen-time, builds on 16-23)
26. Cost classifier extension                         (codegen-time, builds on F13 + 16-23)
```

Each feature gets its own `.plans/desk-sdui-<feature>.md` written when we dispatch it. This file is the umbrella plan, not an implementation spec.

---

## Feature 15 — Runtime class descriptors + `PayloadInstance`

**What:** Runtime data structures that represent payload-defined classes and their instances. Foundation for all subsequent features.

**IR shape:** none yet — this is runtime support.

**Runtime additions:**
```dart
class PayloadClass {
  final String name;
  final PayloadClass? supertype;                    // bridged or payload
  final List<PayloadClass> mixins;                  // applied via linearization
  final Map<String, PayloadFunctionNode> methods;   // declared on this class only
  final Map<String, IrNode> fieldInitializers;
  final List<String> ctorParams;
  final BlockNode? ctorBody;
  // Resolved at class-load time:
  late final List<String> methodLookupOrder;        // mro for method dispatch
}

class PayloadInstance {
  final PayloadClass type;
  final Map<String, _Cell> fields;                  // native Dart values in cells
}
```

`PayloadClass` instances live in `Runtime.payloadClasses: Map<String, PayloadClass>`, populated when a payload containing class declarations is loaded. `PayloadInstance.fields` reuses bucket 3's `_Cell` type (no `$Value` boxing).

**Acceptance:**
- `Runtime.registerPayloadClass(PayloadClass)` adds an entry. Duplicate name → error.
- `Runtime.payloadClasses['Order']` returns the descriptor or null.
- Creating a `PayloadInstance` with no fields works; `instance.type.name == 'Order'`.

**Out of scope:**
- Inheritance from payload-defined class extending bridged class — supertype must be `Object` (implicit) or another payload class. (Bridged-class extension would require shipping bridge metadata for those types; skip.)

---

## Feature 16 — Payload class declarations + constructor invocation

**What:** Lower `class Order { String id; double total; Order(this.id, this.total); }` to a `PayloadClassNode`. Lower `Order('x', 9.99)` to `PayloadInstanceCreationNode`.

**Depends on:** Feature 15.

**IR shape:**
```dart
final class PayloadClassNode extends IrNode {
  final String name;
  final String? supertypeName;          // null = Object
  final List<String> mixinNames;
  final List<PayloadFieldDeclNode> fields;
  final List<PayloadCtorNode> ctors;
  final List<PayloadFunctionNode> methods;
}
final class PayloadFieldDeclNode extends IrNode {
  final String name;
  final IrNode? initializer;
  final bool isFinal;
}
final class PayloadCtorNode extends IrNode {
  final String name;                    // '' for default ctor
  final List<String> params;
  final List<PayloadFieldInitNode> fieldInits;  // for `this.x` params and `: x = expr`
  final BlockNode? body;
}
final class PayloadInstanceCreationNode extends IrNode {
  final String className;
  final String ctorName;                // '' for default
  final Map<String, IrNode> args;
}
```

**Resolver:** `resolvePayloadInstanceCreation`:
1. Look up `runtime.payloadClasses[className]`.
2. Allocate fresh `Map<String, _Cell>` for fields.
3. Run field initializers (declared on the class) in order, populating cells.
4. Apply ctor field initializers (`this.x` params, initializer list).
5. Run ctor body if present.
6. Return `PayloadInstance(type: cls, fields: ...)`.

**Lowerer:** `ClassDeclaration` AST → `PayloadClassNode`. `InstanceCreationExpression` where the type resolves to a payload class → `PayloadInstanceCreationNode`. Same expression where the type resolves to a registered bridged class continues to lower as today's `ValueCtorNode` / `WidgetNode`.

**Codegen:** payload class declarations in `@Screen` files are collected and emitted as `rt.registerPayloadClass(PayloadClass(...))` calls in the generated registration file.

**Acceptance:**
- `class Order { final String id; final double total; Order(this.id, this.total); }` lowers and registers.
- `final o = Order('x', 9.99);` returns a `PayloadInstance` with `o.fields['id'].value == 'x'`.
- Default ctor with no params + no body works.
- Named ctors (`Order.empty()`) work — `ctorName` field carries the name.

**Out of scope:**
- `factory` constructors. Could add later; needs return-value override semantics.
- `const` constructors. Payload-defined const is meaningless (no compile-time constant pool for payload types).
- Redirecting constructors (`Order(int x) : this._internal(x)`). Lower-priority.

---

## Feature 17 — Instance method dispatch

**What:** `order.applyDiscount(0.5)` on a payload instance resolves to walking that method's body with `this` bound.

**Depends on:** Feature 16, F12 (payload function body walker).

**IR shape:**
```dart
final class PayloadMethodCallNode extends IrNode {
  final IrNode receiver;      // resolves to a PayloadInstance
  final String methodName;
  final Map<String, IrNode> args;
}
```

**Resolver:** `resolvePayloadMethodCall`:
1. Resolve `receiver` to a `PayloadInstance`.
2. Walk `instance.type.methodLookupOrder` (set at class-load by mro pass — Feature 20) until a class with `methodName` is found.
3. Get the `PayloadFunctionNode` for the method.
4. Build env: `{this: instance, ...args bound to params}`. Field reads inside the body look up `instance.fields[name].value` via a `ThisFieldRefNode` lowering.
5. Walk the body via F12's executor, return value.
6. If no method found: throw `NoSuchMethodError` (or call `noSuchMethod` if Feature 22 overrides exist).

**Lowerer:** `MethodInvocation` where the receiver is statically known to be a payload-class type → `PayloadMethodCallNode`. Method invocations on bridged objects keep the existing `MethodCallNode` path.

**Acceptance:**
- `o.applyDiscount(0.5)` on a payload-class `Order` walks the method body, returns a new `PayloadInstance`.
- Method bodies that read `this.id` resolve correctly (via `ThisFieldRefNode`).
- Method bodies that call other methods on `this` (`this.compute()`) dispatch recursively.
- Unknown method → `NoSuchMethodError` thrown at runtime.

**Out of scope:**
- Async instance methods at the resolver level — those still gate via `ActionSequenceNode`/action context (consistent with F2/F4 rules).
- Method resolution involving bridged superclasses beyond `Object`.

---

## Feature 18 — Instance field access (read + write)

**What:** `order.id` reads; `order.total = newTotal` writes (if field is non-final).

**Depends on:** Feature 16, F8 (`AssignNode`), F14 (setter codegen pattern reused).

**IR shape:** extend `RefNode` to handle `receiver.fieldName`:
```dart
final class FieldRefNode extends IrNode {
  final IrNode receiver;
  final String fieldName;
}
// And reuse AssignNode with target/setterKey paths from F14.
```

**Resolver:**
- Read: `receiver.fields[fieldName].value` (native value, no unboxing).
- Write: `receiver.fields[fieldName].value = newValue`. Reject at lowering time if field was declared `final`.

**Lowerer:**
- `PropertyAccess` on a payload-instance receiver → `FieldRefNode`.
- `AssignmentExpression` of the form `instance.field = value` on a payload-instance → `AssignNode(target: receiver, fieldKey: fieldName, value)`.
- Reject `instance.finalField = ...` at codegen with a clear diagnostic.

**Acceptance:**
- `o.id` reads, returns native String.
- `o.total = 12.50` on a non-final field writes through the cell.
- `o.id = 'y'` on a final field is a codegen error.
- Reading an undeclared field is a codegen error (or runtime null if the field truly doesn't exist post-construction).

**Out of scope:**
- Getter/setter declared methods on payload classes (`int get total => ...;`). Could add as syntactic sugar over a regular method named `total`.

---

## Feature 19 — `is` / `as` / subtype checks

**What:** Runtime type tests against payload classes.

**Depends on:** Feature 15.

**IR shape:**
```dart
final class IsTypeNode extends IrNode {
  final IrNode operand;
  final String typeName;
  final bool negated;          // for `! is`
}
final class AsTypeNode extends IrNode {
  final IrNode operand;
  final String typeName;
  final bool nullable;         // `as Type?` vs `as Type`
}
```

**Resolver:**
- `IsTypeNode`: if operand is a `PayloadInstance`, walk `type.supertype` chain + check `mixins` for type-name match. If operand is a bridged value, fall through to native `is` check via registered type info.
- `AsTypeNode`: same check; on match return operand, on mismatch throw `TypeError`.

**Lowerer:**
- `IsExpression` → `IsTypeNode`.
- `AsExpression` → `AsTypeNode`.

**Acceptance:**
- `order is Order` returns true for `PayloadInstance` of class `Order` or any subclass.
- `instance is OtherType` returns false.
- `order as Order` returns operand if check passes, throws `TypeError` if not.

**Out of scope:**
- Generic type parameter checks (`order is Order<String>`). Generics still erased.

---

## Feature 20 — Mixin linearization + dispatch

**What:** `class Order with Discountable, Auditable { ... }`. Mixin methods become callable on instances; mro determines which override wins on conflicts.

**Depends on:** Feature 17 (method dispatch).

**IR shape:** `PayloadMixinNode` mirrors `PayloadClassNode` but is marked as a mixin (no instantiable ctor):
```dart
final class PayloadMixinNode extends IrNode {
  final String name;
  final List<String> onTypes;           // `on TypeX` constraints
  final List<PayloadFunctionNode> methods;
  final List<PayloadFieldDeclNode> fields;
}
```

**Runtime:** at class-load, compute `methodLookupOrder` for each `PayloadClass`:
1. Start with `[className]`.
2. Append mixin names in declaration order, reversed (rightmost mixin highest priority — matches Dart's mixin application order).
3. Walk supertype chain, appending each ancestor's mro segment.
4. Resolve to a flat list of class/mixin names used for method dispatch.

**Lowerer:** `MixinDeclaration` → `PayloadMixinNode`. `WithClause` on a class declaration captures `mixinNames`.

**Acceptance:**
- A class `with Discountable` gains `discount(double pct)` method.
- Conflicting method definitions in two mixins resolve to the rightmost mixin's version (Dart's semantics).
- `on TypeX` constraint: codegen rejects mixin application if class doesn't satisfy the constraint.

**Out of scope:**
- Diamond inheritance edge cases beyond what Dart itself supports.
- Mixins applied to bridged classes — host-side concern, not payload.

---

## Feature 21 — Extension method dispatch

**What:** `extension StringX on String { String shout() => toUpperCase() + '!'; }`. Adds methods to existing bridged types from within the payload.

**Depends on:** Feature 17 (method dispatch shape).

**IR shape:**
```dart
final class PayloadExtensionNode extends IrNode {
  final String name;
  final String targetTypeName;          // 'String', 'List', or a payload class
  final List<PayloadFunctionNode> methods;
}
```

**Runtime:** `Runtime.payloadExtensions: Map<String, List<PayloadExtensionNode>>` keyed by target type name. Method dispatch order at call site `'hi'.shout()`:
1. Try native dispatch on the receiver via registered methods.
2. If no match, walk extensions matching the receiver's runtime type. Return first match.
3. If still no match: `NoSuchMethodError`.

**Lowerer:** `ExtensionDeclaration` → `PayloadExtensionNode`. `MethodInvocation` lowering checks extension registry when the receiver type has no matching registered method.

**Acceptance:**
- `'hi'.shout()` calls the extension method, returns `'HI!'`.
- Extension on a payload class also works.
- Extension methods can be chained (`x.shout().toLowerCase()`).

**Out of scope:**
- Conflicting extensions on the same type — Dart's resolution rules (specificity) require analyzer-level support. Document the limitation: ambiguous calls become a codegen error.
- Extension types (Dart 3 "extension types" with their own identity).
- Generic extensions.

---

## Feature 22 — Operator overloading

**What:** `operator ==(Object other)`, `int get hashCode`, `Order operator +(Order other)`, `Item operator [](int i)`. Standard Dart operator methods on payload classes.

**Depends on:** Feature 17.

**IR shape:** none new — operators lower to method calls with reserved names (`==`, `hashCode`, `+`, `[]`, `[]=`, `<`, etc.). `PayloadMethodCallNode.methodName` carries the operator symbol.

**Resolver:** standard `ArithOpNode`/`CompareOpNode`/`IndexAccessNode` resolution checks: if LHS is a `PayloadInstance`, look up the operator method on its class via the mro. If no override, fall back to native semantics (identity equality for `==`, `IndexError` for `[]`).

**Special cases:**
- `==` always pairs with `hashCode` — codegen warns if one is overridden but not the other.
- `toString()` lowers like a regular instance method on payload instances (auto-generated default if undeclared: `'Order(id: ..., total: ...)'`).
- `noSuchMethod(Invocation)` — Feature 22a, optional. Lower priority; useful for proxy patterns but adds dispatch complexity.

**Lowerer:** binary/unary expressions on payload-instance operands lower to `PayloadMethodCallNode` with the operator name. `IndexExpression` similarly.

**Acceptance:**
- `o1 == o2` calls the payload's `operator ==` if defined; falls back to identity equality otherwise.
- `Order(1) + Order(2)` returns the result of the `+` method on a payload-class `Order`.
- `mylist[0]` calls the payload's `operator []`.
- Forgetting to override `hashCode` when overriding `==` emits a warning at codegen.

**Out of scope:**
- Tear-off of operators (`final adder = Order(1) + ;` — Dart doesn't allow this anyway).
- `~/`, `<<`, `>>`, bitwise — same shape as `+`, add piecemeal if authors hit them.

---

## Feature 23 — First-class function values

**What:** Payload-defined functions and methods passed as `Function` parameters or stored on objects. `final reducer = (a, b) => a + b; items.fold(0, reducer);`.

**Depends on:** Feature 17, F2 (LambdaNode).

**IR shape:**
```dart
final class PayloadFunctionValueNode extends IrNode {
  final String? functionName;          // payload-private function name, OR
  final LambdaNode? lambda;            // an inline lambda
  final Map<String, IrNode> capturedEnv;  // for closure-over-locals
}
```

**Runtime:** `PayloadFunctionValueNode` resolves to a closure: `Function = (args...) => walkBody(node, env + args)`. The closure is a native Dart `Function`, callable from registered host code or via payload `MethodCallNode`.

**Lowerer:** referring to a payload function name in a value position (not at a call site) → `PayloadFunctionValueNode(functionName: ..., capturedEnv: enclosingEnv)`. Inline lambdas reuse F2's `LambdaNode` wrapped in `PayloadFunctionValueNode`.

**Acceptance:**
- A payload function passed to `items.fold(0, reducer)` (registered Iterable.fold) invokes the closure per element.
- A method reference (`o.applyDiscount`) is a tear-off and callable as a Function.
- Closures correctly capture surrounding lexical scope (env extension).

**Out of scope:**
- Storing a function value on a bridged object field (requires F14 setter + type registration of `Function` setters). Add piecemeal.
- Async functions as first-class values inside non-action contexts — same gate as Feature 2: rejected outside action context.

---

## Feature 24 — Type introspection on payload instances

**What:** `instance.runtimeType` returns a value comparable to other types. Enables typed registries, switch-on-type patterns. Within-payload reflection only — does NOT extend to bridged AOT types (Dart's mirrors are disabled).

**Depends on:** Feature 15.

**IR shape:** none new — `runtimeType` access on a payload instance lowers as a special `RuntimeTypeRefNode`:
```dart
final class RuntimeTypeRefNode extends IrNode {
  final IrNode operand;
}
```

**Runtime:** returns a `PayloadTypeValue { PayloadClass cls; }`. `PayloadTypeValue.toString()` returns the class name. Equality by class identity.

**Lowerer:** `PropertyAccess(.runtimeType)` on payload-instance receivers → `RuntimeTypeRefNode`. On bridged values: returns the registered class name as a string (best-effort; not a full Type object).

**Acceptance:**
- `order.runtimeType == anotherOrder.runtimeType` returns true if same payload class.
- `order.runtimeType.toString() == 'Order'` returns true.
- Bridged values: `'hello'.runtimeType.toString()` returns `'String'`.

**Out of scope:**
- `Type` literals (`Order` used as a value, not in `is`/`as`). Could add but requires more lowering work; skip until needed.
- Reflective method invocation by name (`instance.invoke('foo', [args])`). Authors use a registered helper if they need this.

---

## Feature 25 — Allowlist re-verification pass

**What:** Codegen-time recursive check that every leaf call inside payload class methods, mixins, and extensions resolves to (a) another payload-defined function/method, (b) a registered host method/widget/value-ctor, or (c) a built-in primitive operation. Anything else is a hard codegen error.

**Why:** The whole reason bucket 4 is acceptable is that the safety boundary is preserved at the *leaves*. Composition becomes arbitrary; leaves stay allowlisted. The verifier enforces this.

**Depends on:** Features 16-23.

**Lowerer additions:** walk every payload function/method/extension body; for each method invocation, property access, or operator use:
- If the receiver is a payload instance: resolve method against the payload class registry. If not found and no `noSuchMethod` override exists, codegen error.
- If the receiver is a bridged value: check the receiver's registered method/getter set. If not registered, codegen error: "method `<x>` on bridged type `<T>` is not registered with `@Register`."
- If the call is a top-level / unqualified identifier: it must resolve to a payload function declaration or a registered top-level method.

**Diagnostic shape:**
```
error: payload method Order.compute() calls Foo.bar() at line 42:8, but Foo
is not in any @Register list. Add `@Register([Foo])` to the host, or remove
the call from payload-side code.
```

**Acceptance:**
- A payload method calling an unregistered host method is a codegen error with a clear pointer.
- A payload method calling another payload method is fine.
- A payload method calling a built-in primitive (`int.toString()`) is fine — built-in primitive support is auto-registered.
- Recursive payload method chains are verified all the way down.

**Out of scope:**
- Verifying that payload-class field types are also allowlisted (could be a follow-up; field types matter less than method-call leaves).
- Cross-payload-file verification (each `.sdui.json` is verified in isolation; cross-file refs are not supported by the registry model anyway).

---

## Feature 26 — Cost classifier extension for payload classes

**What:** Extend F13's cost classifier to also analyze payload class methods and extension methods. Same severity matrix; additional class:

- **Allocates-heap-per-call** (new class): method that constructs a payload instance — `Order.applyDiscount` returns a new `Order`. In tight build-path loops, this allocates per frame.

**Depends on:** Feature 13, all of bucket 4.

**Diagnostic additions:**
- "Method `Order.applyDiscount` allocates a payload instance and is called from a build path; consider memoizing if N > ~100."
- "Recursive method `tree.fold` has no size-decreasing argument; calling from build path may not terminate."

**Suppression:** same `// ignore: sdui_potential_cost` pattern.

**Acceptance:**
- A method that constructs N payload instances called from build emits a diagnostic.
- Free recursion in a payload method emits a warning everywhere.
- Pure-bounded payload methods are silent.

**Out of scope:**
- Inter-procedural escape analysis (tracking whether allocated instances escape the call frame). Approximation is good enough.

---

## Cost summary — bucket 4 delivered

| Component | Code (LOC) | Runtime binary |
|---|---|---|
| Runtime class descriptors + `PayloadInstance` (F15) | ~150 | ~5 KB |
| Class declarations + ctor invocation (F16) | ~250 | ~8 KB |
| Method dispatch (F17) | ~200 | ~5 KB |
| Field access (F18) | ~80 | ~2 KB |
| is/as/subtype checks (F19) | ~150 | ~3 KB |
| Mixins + linearization (F20) | ~250 | ~5 KB |
| Extensions (F21) | ~200 | ~5 KB |
| Operator overloading (F22) | ~150 | ~3 KB |
| First-class function values (F23) | ~120 | ~3 KB |
| Type introspection (F24) | ~80 | ~2 KB |
| Allowlist re-verification (F25, codegen-time) | ~300 | **0 KB** |
| Cost classifier extension (F26, codegen-time) | ~250 | **0 KB** |
| Lowerer (class/mixin/extension parsing) | ~2500 | **0 KB** |
| Tests | ~4000+ | not shipped |

**Total bucket-4 runtime contribution: ~40-50 KB.**
**Cumulative runtime after buckets 1+2+3+4: ~70-100 KB.**
**vs flutter_eval: ~1.5-2 MB.**
**Binary advantage: 20-30×.**
**Per-op performance advantage: 2-4× on every workload.**
**Build-path stability advantage: structural (Flutter framework diffs unchanged subtrees natively; flutter_eval re-executes bytecode per dirty rebuild).**

---

## What we have after bucket 4

Feature parity with dart_eval modulo:
- Generators (`sync*` / `async*`) — universal skip.
- Full inter-call generic inference — ctor-level only.
- Bridged-class extension as supertype for payload classes — skip; supertype must be `Object` or payload.

Everything else dart_eval can express, payload authors can write naturally and ship from the server: classes, mixins, extensions, operators, closures, async/await in actions, try/catch, pattern matching, statement loops, mutation, recursive methods, type introspection on payload types.

Native value flow preserved end-to-end. Codegen-time validation as strict as possible; runtime errors limited to "called an unregistered method on a bridged type" (which codegen catches today via F25) and "exceeded cost budget" (which classifier warns).

---

## Stdlib bridging surface — explicit non-goal

dart_eval ships pre-built bridges for many `dart:` libraries: `dart:async`, `dart:convert`, `dart:typed_data`, `dart:collection`, `dart:io`, `dart:math`, `dart:core` stdlib types beyond primitives. That surface area is part of why their runtime is ~1.5-2 MB — bridge code + type metadata for every exposed type lives in the package binary, whether the consumer uses it or not.

**We deliberately don't ship a pre-built stdlib bundle.** If a payload needs `jsonDecode`, `Uri.parse`, `Random`, `Future.delayed`, etc., the host app's authors register what they need via `@Register([jsonDecode, Uri, Random, ...])`. The host owns the audit surface.

What payload authors **can** write themselves (after F12 in bucket 3 + F23 in bucket 4): helpers composed from already-registered primitives. `formatPrice`, `discount`, `visibleOnly(items)`, domain predicates, recursive tree traversals, custom value classes with methods. These ship as payload IR, no host change needed.

What payload authors **cannot** write themselves: anything reaching into a system facility (I/O, network, JSON parsing, crypto, isolates, FFI, unregistered Flutter widgets). These need a host `@Register` first because the *leaves* of the computation cross the safety boundary.

The rule of thumb: pure computation over exposed primitives ✅ payload-side. Anything that touches a Dart VM or OS facility ❌ requires a host registration.

Why this is the right trade for us:
- **Bundle size scales with use, not capability.** A payload that never decodes JSON doesn't pay for `jsonDecode` registration.
- **Tree-shaking stays effective.** Every registration is an explicit `@Register([T])` referencing a concrete type; the AOT compiler can prove what's reachable.
- **The "registered surface = audit surface" property is preserved.** Bundling stdlib by default would mean every app implicitly ships the full surface, which is the opposite of what `@Register` is for.

**Practical implication:** payload authors targeting unusual stdlib types either ask the host author for a `@Register` addition (one-time, lives in the app binary forever) or compose the behavior in payload code from primitives. Either way, the host knows exactly what surface is exposed; nothing is exposed by accident.

**Documentation follow-on (separate from this plan):** publish a "common stdlib registration recipes" doc — `@Register` snippets for `jsonDecode`/`jsonEncode`, `Uri`, `Random`, `Future.delayed`, `DateTime` math, `Iterable` extensions, etc. — so consumers don't reinvent each one from scratch. Recipes, not a runtime bundle.

---

## Out of scope (do NOT touch in this plan)

- Bytecode compilation or interpretation. Tree walker only.
- `$Value` boxing infrastructure. Native values throughout.
- AST-to-bytecode runtime compiler. Server/build-time lowering only.
- Hot-reload of payload-defined classes. Reload-and-re-register, not patch-in-place.
- Migration tooling for existing payloads. Add piecemeal if authors hit needs.
- Generators, FFI, isolates, `dart:mirrors`. Universal impossibilities; document and move on.
