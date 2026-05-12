# desk_sdui — ActionSequenceNode (async event handlers)

**Goal:** Support `onPressed: () async { await vm.login(); context.push(HomeRoute()); }` style event handlers in `@Screen` bodies. Today these force a hoist-to-VM-method refactor. ActionSequenceNode is the foundation for TryStepNode (Feature 6) and Cascades (Feature 7).

**Architecture (load-bearing):**
- New IR nodes: `ActionSequenceNode { steps }` and `ActionStepNode { call, awaitResult, bindResult }`.
- Resolver: when an `EventNode` slot resolves to an `ActionSequenceNode`, build a `Future<void> Function()` that runs the steps in order. Build remains synchronous; only the *event handler closure* is async.
- Lowerer: recognize async `FunctionExpression` whose body is a flat sequence of `ExpressionStatement`s (with optional `AwaitExpression` wrappers). Reject anything else with a clear diagnostic.
- Per-frame contract preserved: event handlers fire on user input, not in `build`. The resolver itself stays sync.

**Tech stack:** existing IR, resolver, generator. No new runtime machinery beyond the two nodes.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_encoder.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_decoder.dart`

**Step 1 — Define both nodes** (near `EventNode`):

```dart
/// A sequence of async-aware steps. Resolved into a `Future<void> Function()`
/// that runs the steps in order. Only appears as the resolved value of an
/// EventNode slot — never as a regular expression.
final class ActionSequenceNode extends IrNode {
  const ActionSequenceNode({required this.steps});
  final List<ActionStepNode> steps;

  @override
  bool operator ==(Object other) =>
      other is ActionSequenceNode && _listEq(other.steps, steps);
  @override
  int get hashCode => Object.hashAll(steps);
  @override
  String toString() => 'ActionSequenceNode(${steps.length} steps)';
}

/// One step of an ActionSequenceNode: a method/function call, optionally
/// awaited, optionally binding its result to a name for later steps.
final class ActionStepNode extends IrNode {
  const ActionStepNode({
    required this.call,
    required this.awaitResult,
    this.bindResult,
  });
  final IrNode call;        // typically MethodCallNode; future: WidgetMethodNode, etc.
  final bool awaitResult;
  final String? bindResult;

  @override
  bool operator ==(Object other) =>
      other is ActionStepNode &&
      other.call == call &&
      other.awaitResult == awaitResult &&
      other.bindResult == bindResult;
  @override
  int get hashCode => Object.hash(call, awaitResult, bindResult);
  @override
  String toString() =>
      'ActionStepNode(${awaitResult ? "await " : ""}$call${bindResult != null ? " as $bindResult" : ""})';
}
```

(`_listEq` may already exist in the file — reuse it. Otherwise define a private helper that does length+element equality.)

**Step 2 — JSON codec:** add `'actionSequence'` and `'actionStep'` cases to encoder + decoder. Payload for `actionSequence`: `{steps: [<actionStep>...]}`. Payload for `actionStep`: `{call, awaitResult, bindResult}`. Mirror the `GetterNode` pattern in `json_encoder.dart:109` / `json_decoder.dart:94`.

**Step 3 — Verify**

```
cd packages/desk_sdui_annotation && dart analyze && dart test
```

**Step 4 — Commit**

```
git commit -am "feat(ir): add ActionSequenceNode + ActionStepNode for async handlers"
```

---

## Task 2 — Resolver builds the async closure

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` (or wherever EventNode currently resolves — `grep -rn "EventNode" packages/desk_sdui/lib/src/`).

**Step 1 — Audit EventNode's current resolution.** Today an `EventNode(path)` resolves to a tear-off from the registered runtime methods (e.g. `vm.increment`). The new path: if the AST author wrote an async function body inline, the lowerer emits an `ActionSequenceNode` directly *as the event-slot value* (no path/tear-off needed). The resolver needs to handle this case.

**Step 2 — Add the case** (where EventNode slots are resolved, OR as a general expression case if the slot value flows through `evalExpression`):

```dart
case ActionSequenceNode(:final steps):
  return () async {
    var localEnv = input;
    for (final step in steps) {
      final result = evalExpression(step.call, localEnv, runtime);
      final value = step.awaitResult && result is Future
          ? await result
          : result;
      if (step.bindResult != null) {
        localEnv = {...localEnv, step.bindResult!: value};
      }
    }
  };
```

**Note on the function signature:** the closure is `Future<void> Function()`. Flutter's `VoidCallback` slots (e.g. `onPressed`) accept `Future<void> Function()` because `() async { ... }` returns `Future<void>` which is assignable to `VoidCallback` — Flutter just doesn't await it. That's the intended behavior; fire-and-forget event handler.

**Step 3 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

**Step 4 — Commit**

```
git commit -am "feat(eval): resolve ActionSequenceNode into Future<void> Function()"
```

---

## Task 3 — Lowerer recognizes async event-handler bodies

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart` (or wherever `FunctionExpression` lowering for event handlers lives — `grep -rn "FunctionExpression\|EventNode" packages/desk_sdui_generator/lib/src/`).

**Step 1 — Audit current event-handler lowering.** Today, `onPressed: vm.increment` lowers to `EventNode(['vm', 'increment'])` — a tear-off path. The new path: when the analyzer reports an inline `FunctionExpression` with an async body, lower it to `ActionSequenceNode`.

**Step 2 — Recognize the AST shape:**

```dart
// Pseudocode
if (expr is FunctionExpression && expr.body is BlockFunctionBody) {
  final body = expr.body as BlockFunctionBody;
  final isAsync = body.isAsynchronous;
  if (isAsync) {
    return _lowerActionSequence(body.block);
  }
}
```

**Step 3 — Lower the block to ActionSequenceNode.** The recognized grammar is:

```
AsyncBody := (ExpressionStatement | VariableDeclarationStatement(final, single, initialized-with-AwaitExpression))*
```

For each statement:
- `ExpressionStatement(AwaitExpression(call))` → `ActionStepNode(call: lower(call), awaitResult: true)`
- `ExpressionStatement(call)` → `ActionStepNode(call: lower(call), awaitResult: false)` (fire-and-forget; rare)
- `VariableDeclarationStatement(final x = await call())` → `ActionStepNode(call: lower(call), awaitResult: true, bindResult: 'x')`
- Any other statement form → throw `InvalidScreenBodyError('Async event handler bodies must be a sequence of (optionally-awaited) calls, optionally binding the result to a final local. Got: ${stmt.runtimeType}')`.

**Step 4 — Where the resulting ActionSequenceNode is placed.** The outer call site (e.g. the `onPressed:` arg of a `WidgetNode`) receives the ActionSequenceNode directly as the arg value, the same way EventNode does today. No special wiring: WidgetNode args are `Map<String, IrNode>`; an arg slot can carry any IrNode.

**Step 5 — Track the action context for future LambdaNode work.** Add a `bool inActionContext` flag to the lowerer's traversal state (default false). Set true when descending into an `ActionSequenceNode`'s step calls. LambdaNode (Feature 2) reads this to gate async-bearing lambdas. For this plan: just plumb the flag; no current rejection logic. Comment it as TODO for the LambdaNode plan to wire.

**Step 6 — Verify**

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

**Step 7 — Commit**

```
git commit -am "feat(codegen): lower async event-handler bodies to ActionSequenceNode"
```

---

## Task 4 — Tests

**Files:**
- Create: `packages/desk_sdui/test/action_sequence_eval_test.dart`
- Create: `packages/desk_sdui_generator/test/action_sequence_lowering_test.dart`

**Step 1 — Resolver tests** (`action_sequence_eval_test.dart`), cases:
1. Single awaited step, no bind — invoking the resolved closure awaits the call and returns.
2. Two awaited steps — invoked in order; second step sees the env from before its own bind would apply.
3. `bindResult` binds the awaited value into env for later steps (e.g. step 1 binds `user`, step 2 reads `user`).
4. `awaitResult: false` step doesn't await — closure returns before the Future from the call completes.
5. Inner call throws — `Future.error` propagates from the resolved closure (no implicit swallow). This is the contract TryStepNode (Feature 6) will use.

**Step 2 — Lowerer tests** (`action_sequence_lowering_test.dart`), cases:
1. `() async { await vm.login(); }` → ActionSequenceNode with one awaited step, no bind.
2. `() async { await vm.login(); context.push(HomeRoute()); }` → two steps, first awaited, second is `awaitResult: false` (no `await` keyword).
3. `() async { final user = await vm.login(); vm.greet(user); }` → step 1 has `bindResult: 'user'`; step 2's call references `RefNode(['user'])`.
4. Reject sync block: `() { vm.bump(); }` — should NOT lower to ActionSequenceNode (existing EventNode path keeps working).
5. Reject `if`/`switch`/`for`/`try` inside async block: emit the documented diagnostic.

**Step 3 — Verify**

```
cd packages/desk_sdui && dart test test/action_sequence_eval_test.dart
cd packages/desk_sdui_generator && dart test test/action_sequence_lowering_test.dart
```

**Step 4 — Commit**

```
git commit -am "test(desk_sdui): cover ActionSequenceNode resolver + lowerer paths"
```

---

## Task 5 — Demo screen exercising async handler

**Files:**
- Create: `packages/desk_sdui_demo/lib/screens/async_action_demo.dart`

**Step 1 — Author the screen.** It needs a VM with at least one async method so the lowerer has something to point `await` at:

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'async_action_demo.sdui.g.dart';

class AsyncActionController {
  AsyncActionController({this.onLogged});
  final void Function(String message)? onLogged;

  Future<String> simulateLogin() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'guest-123';
  }

  void log(String msg) => onLogged?.call(msg);
}

@Screen('async_action_demo')
Widget asyncActionDemo(AsyncActionController vm) {
  return Center(
    child: ElevatedButton(
      onPressed: () async {
        final user = await vm.simulateLogin();
        vm.log('Logged in as $user');
      },
      child: const Text('Login'),
    ),
  );
}
```

**Step 2 — Regenerate**

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
```

(If `dart run build_runner build` hangs as it did in the cue-example dispatch, fall back to `flutter pub run build_runner build --delete-conflicting-outputs`.)

**Step 3 — Verify** the generated IR contains an ActionSequenceNode with two steps:

```
grep -n "ActionSequenceNode\|ActionStepNode" packages/desk_sdui_demo/lib/screens/async_action_demo.sdui.g.dart
```

Expected: one `ActionSequenceNode` literal with two `ActionStepNode` entries; the first has `bindResult: 'user'` and `awaitResult: true`, the second has `awaitResult: false`.

**Step 4 — Verify setup.g.dart wires the screen.**

**Step 5 — Commit.**

```
git add packages/desk_sdui_demo/lib/screens/async_action_demo.dart \
        packages/desk_sdui_demo/lib/screens/async_action_demo.sdui.g.dart \
        packages/desk_sdui_demo/lib/screens/async_action_demo.sdui.json \
        packages/desk_sdui_demo/lib/screens/async_action_demo.sdui_reg.g.dart \
        packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart
git commit -m "feat(demo): async_action_demo exercising ActionSequenceNode"
```

(Skip wiring into `main.dart`'s `SegmentedButton` switcher — the screen rendering isn't required for plan acceptance; the lowering + regen succeeding is. Leave switcher integration for follow-up if useful.)

---

## Task 6 — Full-suite verification

**Step 1 — Per-package analyze + test**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done
```

**Step 2 — Demo analyze + test**

```
cd packages/desk_sdui_demo
flutter analyze
flutter test
```

**Step 3 — Confirm no existing screen broke.** Existing sync event handlers (EventNode tear-offs) MUST still lower the same way they did before — verify by re-regenerating and diffing the existing screens' `.sdui.g.dart` files; they should be byte-identical (or only differ in unrelated codec ordering — investigate any meaningful change).

---

## Out of scope (deliberately)

- **`if`/`else`/`for`/`switch` inside async handler bodies.** Reject with diagnostic. Authors hoist branching logic to a VM method.
- **`try`/`catch`** — covered by `TryStepNode` (Feature 6).
- **Cancellation, debouncing.** Author handles via registered VM logic.
- **Async lambdas inside collection ops.** Reject under the `inActionContext` flag — wired by LambdaNode (Feature 2).
- **Wiring the demo into `main.dart`'s switcher.** Screen existence + regen success is sufficient; visual demo can be added later.

---

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui

for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done

(cd packages/desk_sdui_demo \
  && dart run build_runner build --delete-conflicting-outputs \
  && flutter analyze \
  && flutter test) || exit 1
```
