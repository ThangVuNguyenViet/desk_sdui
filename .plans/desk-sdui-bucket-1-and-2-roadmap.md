# desk_sdui — expressiveness roadmap (buckets 1, 2, 3)

**Goal:** Close the "natural Dart feel" gap between desk_sdui and disciplined flutter_eval, without embedding a general-purpose Dart interpreter. Each feature is a focused extension that exploits our existing tree-walking resolver + native value flow. Bucket 1 + 2 preserve the per-frame perf advantage absolutely; bucket 3 preserves it by **codegen-time warnings**, not feature absence.

**Scope:** features grouped under three buckets from the [parser surface comparison](../docs/design/why-not-flutter-eval.md):

- **Bucket 1 — sugar over existing IR** (lower to nodes we already have): Pattern matching, Generic type carriage, Cascades.
- **Bucket 2 — narrow new runtime machinery** (extend env/resolver without invading per-frame contract): `LetNode`, `LambdaNode`, `ActionSequenceNode`, `TryStepNode`.
- **Bucket 3 — bounded interpreter extensions** (mutable env, statement loops, cross-build state, payload-defined functions): `AssignNode`, `WhileNode`/`DoNode`/imperative `ForNode`, `BlockNode` + control flow, `IrStatefulNode`, payload function declarations, and a cost classifier that emits diagnostics at call sites based on context × cost class.

**Out of scope:**
- Generators (`sync*` / `async*`). Universal skip — neither we nor flutter_eval support them well.
- User-defined classes / extensions in payload. Allowlist refusal, on purpose. (Payload functions are allowed because their bodies can only call registered things — composition sugar, not new behavior.)
- Any change that would require boxing values in a uniform wrapper type — values stay native Dart objects in `Map<String, _Cell>` (cells hold native values, no `$Value` wrapper).
- Any change that makes the resolver async — `build` is sync by Flutter contract; resolver stays sync. Async lives in `ActionSequenceNode` only.

---

## Suggested dispatch order

Feature 1 (`LetNode`) is foundational because `LambdaNode` re-uses its env extension shape. Features 3-5 are independent and can be dispatched in parallel after 1 and 2 land.

```
Bucket 1 + 2 (preserve cost rule absolutely):
1. LetNode               (foundation: env extension)
2. LambdaNode            (builds on LetNode env shape)
3. Pattern matching      (independent, parallel-safe)
4. ActionSequenceNode    (independent, parallel-safe)
5. Generic type carriage (independent, parallel-safe)
6. TryStepNode           (builds on ActionSequenceNode)
7. Cascades              (pure lowering, free after ActionSequenceNode)

Bucket 3 (cost rule preserved by codegen-time warnings):
8.  Mutable env + AssignNode    (LetNode cells become mutable; reads dereference)
9.  BlockNode + control flow    (Break/Continue/Return signals)
10. Statement loops              (WhileNode, DoNode, imperative ForNode)
11. IrStatefulNode               (cross-build local state via Flutter State<>)
12. Payload function declarations (compose registered ops; bodies allowlist-checked)
13. Cost classifier              (codegen-time diagnostic emitter for hot paths)
14. Setter codegen for @Register  (small: enables `vm.count = 0` from payload)
```

Each feature gets its own `.plans/desk-sdui-<feature>.md` written when we dispatch it. This file is the umbrella roadmap, not an implementation spec.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Verify per feature:**
```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter analyze
```

---

## Feature 1 — `LetNode` (locals in screen bodies)

**What:** Support `final t = expr; <rest>` shapes in `@Screen` bodies. Today these fail in the lowerer; today's workaround is to compute everything inline or hoist to a registered method.

**Why:** Authors hit this for any non-trivial intermediate computation. Hoisting two-line scratch values into registered Dart methods is busywork.

**IR shape:**
```dart
final class LetNode extends IrNode {
  final String name;
  final IrNode value;
  final IrNode body;
}
```

**Resolver:** evaluate `value` in current env, extend env with `{name: result}`, evaluate `body` in extended env. ~10 lines.

**Lowerer:** recognize `VariableDeclarationStatement` followed by `ReturnStatement` in block bodies. Chain multiple lets into nested `LetNode`s.

**Acceptance:**
- `@Screen Widget foo(Vm vm) { final t = vm.title.toUpperCase(); return Text(t); }` lowers and renders.
- Multiple sequential `final` bindings chain correctly.
- Cost-rule check: `LetNode` adds one env-map allocation per let. O(1) per binding; bounded by IR-tree-size.

**Out of scope:**
- Mutable `var` locals. Only `final`.
- Locals inside lambda bodies — handled when `LambdaNode` lands.
- Reassignment. Lets are single-assignment by construction.

---

## Feature 2 — `LambdaNode` (closures in screen bodies)

**What:** Support `(p) => expr` and `(p) { return expr; }` shapes, primarily for use inside collection methods (`Iterable.where`, `.map`, `.fold`).

**Why:** The natural-Dart-feel case the user keeps hitting. Today forces refactor to a registered method that returns the materialized list.

**Depends on:** `LetNode` (env extension shape).

**IR shape:**
```dart
final class LambdaNode extends IrNode {
  final List<String> params;
  final IrNode body;
}
```

**Resolver:** synthesize a Dart `Function` that captures env + executes `body` with params bound. One-liner:
```dart
Function buildLambda(LambdaNode n, Map<String, Object?> env) {
  return (Object? p) => resolveNode(n.body, {...env, n.params[0]: p});
}
```
(Multi-param variant similar.)

**Lowerer:** recognize `FunctionExpression` whose body is itself a lowerable expression. Reject (with diagnostic) if body contains statements other than `ReturnStatement`, control flow other than `ConditionalNode`-compatible, or references to closures-of-closures.

**Context tracking — action vs build:** the lowerer maintains an `inActionContext: bool` flag, set true when descending into `ActionSequenceNode` / `EventNode` bodies. Used to gate async-bearing lambdas:
- Sync `LambdaNode` (no `await` in body): allowed everywhere — collection ops in screen bodies, reactive bindings, action steps.
- Async `LambdaNode` (body contains `await`): allowed **only** when `inActionContext == true`. Rejected with diagnostic if it appears as a `WidgetNode` arg, `ConditionalNode`/`ForNode` subtree, or any signal-driven binding.
- Enables `items.whereAsync((x) async => await vm.canShow(x))` inside an `onPressed` handler while still rejecting the same construct in a `Column(children: [for (...)])` slot.

**Cost-rule violation acknowledged:** lambdas inside collection ops do `O(IR-body-size × N)` work, where N is the iterable length. Authors opt in by writing the lambda; document the per-element cost clearly. Async lambdas additionally compound with await latency — fine in action paths (per-input, ~1 Hz), forbidden in build/signal paths (per-frame, 60 Hz).

**Acceptance:**
- `book.pages.where((p) => p.startsWith('p')).map((p) => p.toUpperCase()).toList()` lowers and renders.
- Lambda body limited to expressions (sugar over `ConditionalNode` for `?:`); no statement-level control flow.
- `Iterable.where`, `.map`, `.toList`, `.fold` registered in core-accessors catalog.
- Inside an `ActionSequenceNode` step, `await items.whereAsync((x) async => await vm.canShow(x))` lowers and runs. Same construct in a `WidgetNode` arg slot emits a diagnostic pointing at the `await`.

**Out of scope:**
- Async lambdas outside action context (rejected by the `inActionContext` gate above).
- Lambdas with locals. (Could add later by combining `LetNode` + `LambdaNode`.)
- Closures that escape the build (passed to async APIs, stored on objects). Resolver creates them per-build; lifecycle is tied to one resolution pass.

---

## Feature 3 — Pattern matching (switch expressions, simple destructuring)

**What:** Support `switch (x) { 'a' => ..., 'b' => ..., _ => ... }` expressions and pattern destructuring for records (`final (a, b) = pair;`).

**Why:** Dart 3 idioms. Common for state-driven UI (`switch (state) { Loading() => ..., Loaded(:final data) => ... }`).

**Bucket 1:** no new runtime machinery. Lower switch expressions to chains of `ConditionalNode`. Lower record destructuring to multiple `LetNode`s extracting fields.

**Lowerer:**
- `SwitchExpression` with literal patterns → chain of `ConditionalNode(CompareOpNode(==), branch, else)`.
- `SwitchExpression` with type patterns (`Loading()`, `Loaded()`) → `IsNullCheckNode`-style type checks (need a new `IsTypeNode` for non-null type tests).
- Record destructuring → `LetNode` per extracted field.

**Acceptance:**
- `switch (state) { Loading() => CircularProgressIndicator(), Loaded(:final items) => ListView(...), _ => SizedBox() }` lowers.
- `final (a, b) = vm.pair; return Text('$a $b');` lowers (needs `LetNode` from Feature 1).

**Out of scope:**
- Logical patterns (`a || b`).
- Guards (`when` clauses).
- Pattern matching inside `if-case` statements (only switch expressions and destructuring assignments).

---

## Feature 4 — `ActionSequenceNode` (async event handlers)

**What:** Support `onPressed: () async { await vm.login(); context.push(HomeRoute()); }` style event handlers.

**Why:** The single most-cited natural-Dart pattern that today forces a hoist-to-VM-method refactor. Doesn't touch per-frame perf (event handlers fire on user input, not in build).

**IR shape:**
```dart
final class ActionSequenceNode extends IrNode {
  final List<ActionStepNode> steps;
}
final class ActionStepNode extends IrNode {
  final MethodCallNode call;   // method invocation
  final bool awaitResult;       // whether to await before next step
  final String? bindResult;     // optional: bind to a name for later steps
}
```

**Resolver:** when an `EventNode` slot resolves an `ActionSequenceNode`, build a `Future<void> Function()` that runs the steps in order:
```dart
Future<void> Function() build(ActionSequenceNode n, env) {
  return () async {
    var localEnv = env;
    for (final step in n.steps) {
      final result = await maybeAwait(resolveNode(step.call, localEnv), step.awaitResult);
      if (step.bindResult != null) localEnv = {...localEnv, step.bindResult: result};
    }
  };
}
```

**Lowerer:** recognize async `FunctionExpression` whose body is a sequence of `ExpressionStatement` (with `AwaitExpression` optionally wrapping each). Reject anything else (no if/else in async handlers — yet).

**Acceptance:**
- `onPressed: () async { await vm.login(); context.push(HomeRoute()); }` lowers and runs.
- Optional bind-result form: `final user = await vm.login(); context.push(ProfileRoute(user));` lowers.
- Synchronous-only handlers (`onPressed: () { vm.bump(); }`) keep working via existing `EventNode`.

**Out of scope:**
- If/else, loops, try/catch inside async handlers. Just sequenced awaits.
- Async lambdas inside collection ops (cost-rule violation in hot path).
- Cancellation, debouncing. Author handles via registered VM logic.

---

## Feature 5 — Generic type carriage in IR

**What:** Carry generic type arguments in IR for ctor invocations where the type matters (`List<MyType>()`, `Map<String, int>()`).

**Why:** Today `WidgetNode`/`ValueCtorNode` only carry the simple class name. Generic instantiation is erased, which can cause runtime cast failures when the registered closure expects a typed container.

**Bucket 1:** no new runtime machinery. Extend IR node schema to optionally carry type-argument names; the registered closure receives them as part of args.

**IR schema:** add optional `typeArgs: List<String>?` to `WidgetNode` / `ValueCtorNode` / `MethodCallNode`. Resolver passes them in the args map under reserved key `__typeArgs__`.

**Generated closures** (per-ctor) check for the key when relevant:
```dart
rt.registerValueBuilder('List', (args) {
  final typeArg = (args['__typeArgs__'] as List?)?.first;
  switch (typeArg) {
    case 'MyType': return <MyType>[];
    case 'String': return <String>[];
    // ...
  }
});
```

**Acceptance:**
- `List<MyType>()` ctor in `@Screen` lowers with `typeArgs: ['MyType']` and the resulting list has the right runtime type for downstream casts.
- Existing un-typed `WidgetNode`s unaffected (typeArgs omitted = same behavior as today).

**Out of scope:**
- Full generic inference (resolving type variables across call chains). Just direct annotations.
- Generic methods (`fn<T>(x)`). Methods stay registered without type args.

---

## Feature 6 — `TryStepNode` (try/catch in action handlers)

**What:** Support `onPressed: () async { try { await vm.save(); } catch (e) { vm.showError(e); } }`.

**Why:** Error handling around `await` is the single most common natural-Flutter pattern not covered by Feature 4. Today forces a VM-side wrapper method.

**Depends on:** `ActionSequenceNode` (Feature 4).

**IR shape:**
```dart
final class TryStepNode extends IrNode {
  final List<ActionStepNode> trySteps;
  final List<ActionStepNode> catchSteps;
  final String? exceptionBind; // name to bind caught exception
}
```
A `TryStepNode` is a kind of step that can appear inside an `ActionSequenceNode` alongside regular `ActionStepNode`s.

**Resolver:** within the existing action-sequence executor, when a step is a `TryStepNode`, wrap its `trySteps` in `try { ... } catch (e) { ... }`. Bind `exceptionBind` into the catch branch's localEnv.

**Lowerer:** recognize `TryStatement` inside async function bodies. `try { await a(); await b(); } catch (e) { vm.report(e); }` lowers to `TryStepNode(trySteps: [a, b], catchSteps: [report(e)], exceptionBind: 'e')`. No support for `on TypeX catch (e)` clauses yet — single catch only.

**Acceptance:**
- `try { await vm.save(); } catch (e) { vm.showError(e); }` lowers and runs.
- Exception thrown from `vm.save()` is caught, bound as `e`, passed to `vm.showError`.
- Uncaught exceptions outside try-blocks propagate normally (no implicit swallow).

**Out of scope:**
- Typed catch clauses (`on FormatException catch (e)`). Single untyped catch.
- `finally` blocks. Could add later.
- `throw` from payload code. Re-raise only happens implicitly when the catch block re-throws via a registered method.

---

## Feature 7 — Cascades

**What:** Support `obj..a()..b()..c` cascade syntax, lowered to an `ActionSequenceNode` that returns the receiver.

**Why:** Common in Flutter setup code (`TextEditingController()..text = 'x'..selection = ...`). Currently forces author to break into multiple steps.

**Depends on:** `ActionSequenceNode` (Feature 4).

**Bucket 1:** no new runtime machinery. Pure lowering.

**Lowerer:** `obj..a()..b()` lowers to:
```
LetNode(name: '__cas__', value: obj, body:
  ActionSequenceNode(steps: [
    a(__cas__),
    b(__cas__),
  ], returnRef: RefNode(['__cas__']))
)
```
Returns the receiver. Setter-form cascade (`..text = 'x'`) requires registered setters on the target type; rejected with a clear diagnostic if the setter isn't registered.

**Acceptance:**
- `TextEditingController()..text = 'hi'` lowers (assuming `TextEditingController.text=` is registered).
- `vm.list..clear()..addAll(items)` lowers and runs the cascade in order.
- Cascade returns the original receiver, not the last call's result.

**Out of scope:**
- Null-aware cascade (`obj?..a()`). Skip; uncommon.
- Cascades on chained expressions (`a.b..c()..d()`). Receiver must be a simple ref/ctor.

---

## Feature 8 — Mutable env + `AssignNode`

**What:** Allow `int x = 0; x = x + 1;` in payload. Locals become mutable cells.

**Why:** Foundation for statement loops, accumulator patterns, and natural function bodies. Without it, payload functions are crippled — most real helpers mutate a local result.

**Depends on:** `LetNode` (Feature 1).

**IR shape:**
```dart
final class AssignNode extends IrNode {
  final String name;
  final IrNode value;
}
```

**Env model change:** `Map<String, Object?>` becomes `Map<String, _Cell>` where `_Cell.value` is mutable. `LetNode` allocates a fresh `_Cell`; reads dereference; `AssignNode` writes `_Cell.value`. Cell wrapper holds **native Dart objects** — no `$Value` boxing. Lookup cost: one hashmap get + one property read (~70 ns, ~1.5× current read cost; constant factor, additive).

**Lowerer:** `AssignmentExpression` (`x = expr`) → `AssignNode`. Compound assignments (`x += 1`) lower to `AssignNode(x, ArithOpNode('+', RefNode([x]), expr))`.

**Acceptance:**
- `int x = 0; x = x + 1; return Text('$x');` lowers, renders `1`.
- `x += 5` compound assignment lowers.
- Existing `final`-bound `LetNode`s keep working — final locals get a cell with no writer.

**Out of scope:**
- Field assignment on registered objects (`vm.field = x`) — separate path, requires registered setters.

---

## Feature 9 — `BlockNode` + control flow signals

**What:** Statement sequences with break/continue/return propagation. Foundation for loops.

**Depends on:** nothing (introduces statement-form resolver).

**IR shape:**
```dart
final class BlockNode extends IrNode { final List<IrNode> statements; }
final class BreakNode extends IrNode {}
final class ContinueNode extends IrNode {}
final class ReturnNode extends IrNode { final IrNode? value; }
```

**Resolver:** new `executeStatement(node, env)` path returning a `ControlFlow` signal: `Normal`, `Break`, `Continue`, `Return(value)`. `BlockNode` executes statements in order, propagates non-`Normal` signals up. Loop nodes consume `Break`/`Continue` at the right level.

**Lowerer:** `BlockFunctionBody` containing statements → `BlockNode`. Statement-form `if`/`else` (currently rejected) → `IfStatementNode` (new) inside `BlockNode`, lowered to conditional execution.

**Acceptance:**
- `{ final a = 1; final b = a + 2; return b; }` lowers and evaluates to 3.
- `if/else` statements lower (currently only ternary works).
- Break/continue inside a loop body propagate correctly.

---

## Feature 10 — Statement loops (`WhileNode`, `DoNode`, imperative `ForNode`)

**What:** `while`/`do`/`for(;;)` loops with full bodies.

**Depends on:** Features 8 + 9.

**IR shape:**
```dart
final class WhileNode extends IrNode { final IrNode condition; final BlockNode body; }
final class DoNode extends IrNode { final BlockNode body; final IrNode condition; }
final class ImperativeForNode extends IrNode {
  final IrNode? init;
  final IrNode? condition;
  final IrNode? update;
  final BlockNode body;
}
```

**Resolver:** iterate while condition holds, execute body via `executeStatement`, handle `Break`/`Continue` signals. `ImperativeForNode` initializes a fresh scope for the loop variable.

**Lowerer:** `WhileStatement`, `DoStatement`, statement-form `ForStatement` (the C-style one, distinct from collection-for which stays sugar over `ForNode`).

**Acceptance:**
- `int x = 0; while (x < 10) { x++; } return x;` evaluates to 10.
- `for (int i = 0; i < items.length; i++) { ... }` lowers as `ImperativeForNode`.
- `break` and `continue` work inside all three loop forms.

**Cost-rule status:** these violate the build-path cost rule when iteration count depends on data. Surfaced via Feature 13 (cost classifier).

---

## Feature 11 — `IrStatefulNode` (cross-build local state)

**What:** State that survives across rebuilds without a VM. `int counter = 0;` at screen-body root persists; `onPressed: () { counter++; }` increments it; build re-renders with the new value.

**Why:** "Without VM" authoring path. Author writes a screen that owns its own simple state, no separate ViewModel class required.

**Depends on:** Features 8 + 9.

**IR shape:**
```dart
final class IrStatefulNode extends IrNode {
  final List<IrStatefulFieldNode> fields;  // cell initializers
  final IrNode body;                        // build body
}
final class IrStatefulFieldNode extends IrNode {
  final String name;
  final IrNode initializer;
}
```

**Runtime glue:** a generated Flutter `StatefulWidget` + `State<>` per `@Screen` that declares root-level mutable fields. The `State<>` owns a `Map<String, _Cell>` initialized once in `initState`. Every `build` call resolves the IR with that cell map merged into env. Mutations from action handlers persist.

**Lowerer:** screen body root-level `var`/`final` declarations → `IrStatefulFieldNode`. The screen itself becomes a stateful screen if any field exists; otherwise stays stateless.

**Acceptance:**
- A counter screen written without a VM: `var counter = 0;` at body root, `onPressed: () { counter++; }`, renders updated count.
- `final` root-level declarations are allowed but have no writer (read-only cell).
- Field initializers can reference each other in declaration order (`var a = 1; var b = a + 1;`).

**Out of scope:**
- `initState`/`dispose` lifecycle hooks. Initial cell values are computed at first build; cleanup not exposed.
- Listening to host signals from inside payload state — that's still the VM-with-signals path.

---

## Feature 12 — Payload function declarations

**What:** Allow `List<Widget> visibleChips(List<Item> items) { ... }` to be defined inside a screen file and called from `@Screen` bodies. Function bodies can contain any statements from Features 8-10, but call sites are still allowlist-checked.

**Why:** Composition. Authors factor repeated IR into named helpers. The function declaration is **sugar over IR** — it doesn't introduce new behavior, just names a composition of already-registered operations. Allowlist property preserved: the function body's individual calls are all to registered things; the function itself is a payload-private name.

**Depends on:** Features 1, 8, 9, 10 (locals, mutation, blocks, loops).

**IR shape:**
```dart
final class PayloadFunctionNode extends IrNode {
  final String name;
  final List<String> params;
  final IrNode body;  // BlockNode or expression
}
```

**Registration:** payload functions are added to a per-file local function table at codegen time. Call sites lower to `PayloadFunctionCallNode(name, args)`. The resolver looks up the function by name in the local table, then walks its body with params bound. **No** runtime registration via `@Register` — these are private to the payload.

**Allowlist invariant:** the lowerer recursively checks that every leaf call inside a payload function body resolves to either (a) another payload function or (b) a registered method/widget/value-ctor. Anything else is a hard error.

**Acceptance:**
- A function with a statement-for body lowers and is callable from `@Screen` body.
- Recursive functions lower (with classifier diagnostic if no size-decreasing arg).
- A payload function that calls an unregistered method is rejected at codegen.

**Out of scope:**
- Function types as first-class values (passing payload fns around as `Function` parameters). Could lower via existing `LambdaNode` if needed.
- Generic payload functions. Stay erased like ctor generics.

---

## Feature 13 — Cost classifier + diagnostics

**What:** A codegen-time analyzer that assigns each payload function a **cost class** and emits diagnostics at call sites based on `context × class`.

**Why:** Lets us deliver bucket 3 expressiveness while keeping authors informed about per-frame cost. Author decides — toolchain surfaces information.

**Cost classes:**
- **Pure-bounded:** no loops, or loops with literal iteration count. Constant cost per call.
- **Linear-in-arg:** has a loop iterating over a parameter of known iterable shape (`for in items`, `while (i < arr.length)`). O(N × body) per call.
- **Unbounded:** has a `while (cond)` where condition depends only on internal mutable state. No statically-derivable iteration bound.
- **Recursive (size-decreasing):** recursive call passes a strictly smaller argument. Treated as linear-in-arg.
- **Recursive (free):** recursive call without size-decrease guarantee. Treated as unbounded.

**Call-site contexts** (tracked by lowerer):
- **Build:** inside an `@Screen` body or `WidgetNode` arg.
- **Signal:** inside a reactive binding / `computed`.
- **Action:** under an `ActionSequenceNode` / `EventNode`.

**Diagnostic matrix:**

| Function class × call site | Build | Signal | Action |
|---|---|---|---|
| Pure-bounded | silent | silent | silent |
| Linear-in-arg | ⚠️ info: "O(N) per frame" | ⚠️ info: "O(N) per signal tick" | silent |
| Unbounded | ⚠️ warning: "no upper bound in build path" | ⚠️ warning: same | ℹ️ info: "confirm termination" |
| Recursive (free) | ⚠️ warning | ⚠️ warning | ⚠️ warning |

**Suppression:** standard `// ignore: sdui_potential_cost` (or per-rule names). No annotations needed to opt in — diagnostics are non-blocking.

**Acceptance:**
- A `visibleChips(items)` linear-in-arg function called from build emits an info diagnostic pointing at the call site, with the message "O(items.length) work per frame; consider collection-for or moving to action context."
- The same function called from `onPressed:` is silent.
- An unbounded `while (! done) { step(); }` called from anywhere emits a warning.

**Out of scope:**
- Configurable severity per project (`analysis_options.yaml`-style integration). Could add later.
- Inter-procedural classification (function A's class depends on the class of function B it calls). Start with intra-procedural; add transitivity if needed.

---

## Feature 14 — Setter codegen for `@Register` (field assignment on registered objects)

**What:** Extend the existing `@Register([T])` codegen to also emit `registerSetter` calls for non-final, public, non-late instance fields of `T`. Enables `vm.count = 0` in payload syntax to lower and execute.

**Why:** Today payload can read fields and call methods on registered objects, but can't assign to fields. Authors work around this by exposing `setCount(int)` methods. With this feature, the natural Dart syntax just works — no extra registration boilerplate, no per-field method wrappers.

**Depends on:** Feature 8 (`AssignNode`) for the lowerer to even parse `vm.count = 0` as something other than a hard error. The runtime setter dispatch is independent.

**Codegen change:** the `@Register` field walker already visits public fields for getters and static-const constants. Add a third branch for non-final, non-late, non-static, public instance fields:

```dart
// existing emission (getter):
rt.registerGetter('Vm.count', (target) => (target as Vm).count);

// new emission (setter), only if field is not final:
rt.registerSetter('Vm.count', (target, value) => (target as Vm).count = value as int);
```

The cast `value as int` uses the field's declared type, captured at codegen time from `FieldElement.type`. For nullable fields use `as int?`.

**Runtime addition:** the existing `Runtime` class needs a `registerSetter` method + `setters` map alongside `getters`/`methods`. New `SetterCallNode` (or extension to `AssignNode` lowering) dispatches via `runtime.setters['Vm.count']?.call(target, value)`.

**IR shape:** payload-side `vm.count = 0` lowers to an `AssignNode` whose `name` is null and which carries a `target` ref + a `setterKey`:
```dart
final class AssignNode extends IrNode {
  final String? name;        // for local var assignment
  final IrNode? target;      // for setter call: the receiver
  final String? setterKey;   // for setter call: e.g., 'Vm.count'
  final IrNode value;
}
```
(Resolver dispatches on which fields are populated.)

**Acceptance:**
- `@Register([Vm])` where `Vm` has `int count = 0` (non-final) emits a `registerSetter('Vm.count', ...)` in the generated registration file.
- Payload `vm.count = 0;` inside an `ActionSequenceNode` lowers and runs.
- Final fields (`final int max = 10;`) emit no setter; payload assignment to them is a clear codegen error: "field `Vm.max` is final; no setter registered."
- Existing getter / method registrations unchanged.

**Out of scope:**
- Setter visibility filters beyond `isPrivate`. If author wants payload-private state, they use a `final` field with a setter-exposing method.
- Indexed assignment (`vm.list[0] = x`). Would route through registered `operator []=`.
- Conditional/null-aware assignment (`vm.x ??= y`). Lower in priority.

---

## Discussion — what bucket 3 deliberately does NOT include

- **Generators (`sync*` / `async*`).** Universal skip; not "natural Flutter feel." Use a registered stream from the VM/host instead.
- **User-defined classes / mixins / extensions in payload.** Allowlist refusal. Adding these reintroduces the safety property flutter_eval can't offer.
- **Field assignment on registered objects** (`vm.field = x` from payload). Requires registered setters; not part of bucket 3 core. Add piecemeal as users hit the need.
- **Async resolver path.** Resolver stays sync. `build` cannot await. Async lives in `ActionSequenceNode` only.
- **Tail-call optimization on recursive payload functions.** Stack-depth-bounded recursion is the only safe form. Author who needs unbounded recursion converts to a loop.

---

## Cost summary — bucket 3 delivered vs flutter_eval

| Component | Code size | Runtime binary contribution |
|---|---|---|
| Mutable env (`_Cell`) | ~200 LOC | ~5-10 KB |
| `executeStatement` + control flow signals | ~400 LOC | ~10-15 KB |
| Statement node classes (Block/Break/Continue/Return/While/Do/ImperativeFor/Assign/If) | ~250 LOC | trivial |
| `IrStatefulNode` + State<> glue | ~300 LOC | ~10 KB |
| Payload function declarations + local function table | ~400 LOC | ~5 KB |
| Cost classifier (codegen-time) | ~400-600 LOC | **0 KB (build-time only)** |
| Setter codegen for `@Register` (Feature 14) | ~50-80 LOC | ~1 KB (per-field hashmap entries) |
| Lowerer changes (block bodies, assignments, statement loops, function declarations) | ~1500-2000 LOC | **0 KB (build-time only)** |
| Tests | ~2500+ LOC | not shipped |

**Total runtime binary contribution: ~30-50 KB.** Order of magnitude smaller than flutter_eval's ~1.5-2 MB. Native value flow preserved (no `$Value` boxing). Allowlist property preserved (no payload-defined types or unregistered calls).

---

## Discussion — bucket 3, "can we just copy dart_eval source?"

Recorded here so the option is on the record.

**dart_eval is BSD-3 licensed.** Legally copyable with attribution. The question is whether copying makes sense, technically.

What's in dart_eval that we might steal:

1. **Bytecode compiler (Dart AST → bytecode).** We have an analogous Dart-AST-to-IR compiler. Reading their source is *educational* — we'd learn how they handle Dart language evolution, nullability edge cases, named-vs-positional param normalization. **Verdict:** read for ideas, not direct copy. Their compiler emits bytecode for an interpreter we don't have.

2. **Bytecode interpreter.** This is the load-bearing piece. We don't have one and don't want one as the default path. Copying it means shipping their interpreter, paying the binary cost and the `$Value` boxing tax at every value boundary. **Verdict:** don't copy — this is the bucket 3 architectural decision; lifting it across collapses our perf advantage.

3. **`$Value` type bridge system.** Tied to the interpreter. Same reason — don't copy.

4. **Bridge generation (`@Bind` + `dart_eval bind`).** We have our own (`@Register` + codegen). Their version is shaped for the interpreter we don't have. **Verdict:** different problem; no copy.

5. **stdlib bridges** (String, List, Map, Iterable, num, etc.). The core-accessors plan already overlaps with this. Reading their bridge-spec files is **useful as a reference** for the surface area to cover. **Verdict:** read as a checklist; implement ourselves the desk_sdui-shaped way.

6. **Generator compilation (`sync*`/`async*`).** Documented gap in dart_eval. We'd be at parity by not supporting them.

7. **Pattern compilation.** For Feature 3 (pattern matching), reading their approach to lowering switch expressions is useful as a reference. Same verdict as #5: read for the technique, implement ourselves.

**General principle:** dart_eval's source is a valuable *reference* for solving Dart-language-handling problems. It is not a valuable *donor* for runtime code, because their runtime is general-purpose where ours is specific-purpose, and the runtime architectures are incompatible.

**Where to read dart_eval source if a feature needs it:**

| Feature we're adding | What to read in dart_eval |
|---|---|
| Pattern matching | `lib/src/eval/compiler/statement/switch.dart` (if present) for switch-expression compilation patterns |
| Generic type carriage | bridge type system files for how generics-as-runtime-data are represented |
| Anything Dart-language-edge-case | their main compiler entry points + analyzer-usage patterns |

**License obligation:** if we lift any code (even adapted), BSD-3 requires attribution + license preservation. Keep that in mind if direct copy ever becomes attractive.

**Recommendation:** treat dart_eval as a research resource. For each feature we add, before designing the lowerer, read the corresponding dart_eval source to understand how they solved the same Dart-language problem. Then implement in our shape (native value flow, hashmap dispatch, tree-walking resolver). We get the benefit of their hard-won language-handling expertise without inheriting their runtime architecture.
