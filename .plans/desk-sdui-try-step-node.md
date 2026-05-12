# desk_sdui — TryStepNode (try/catch in action handlers)

**Goal:** Support `try { await vm.save(); } catch (e) { vm.showError(e); }` inside async event handler bodies. Error handling around `await` is the single most-cited natural-Flutter pattern not covered by ActionSequenceNode alone.

**Dependencies:** `ActionSequenceNode` (Feature 4) must be merged. TryStepNode is a kind of step that appears inside an `ActionSequenceNode.steps` list alongside regular `ActionStepNode`s.

**Architecture:** Bucket 2 — small new IR node, executed inline by the existing action-sequence resolver. The resolver wraps the try-steps in a Dart `try { ... } catch (e) { ... }` block and binds the caught exception into the local env for the catch branch.

**Tech stack:** existing IR + new node, existing resolver, existing lowerer (extends async-block recognition).

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR node

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the node:**

```dart
/// A try/catch step within an ActionSequenceNode. The resolver wraps the
/// `trySteps` in a Dart try/catch; on exception, it binds `exceptionBind`
/// (if non-null) into the local env and runs `catchSteps`.
final class TryStepNode extends IrNode {
  const TryStepNode({
    required this.trySteps,
    required this.catchSteps,
    this.exceptionBind,
  });
  final List<ActionStepNode> trySteps;
  final List<ActionStepNode> catchSteps;
  final String? exceptionBind;

  @override
  bool operator ==(Object other) =>
      other is TryStepNode &&
      _listEq(other.trySteps, trySteps) &&
      _listEq(other.catchSteps, catchSteps) &&
      other.exceptionBind == exceptionBind;
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(trySteps), Object.hashAll(catchSteps), exceptionBind);
  @override
  String toString() =>
      'TryStepNode(try ${trySteps.length} catch (${exceptionBind ?? "_"}) ${catchSteps.length})';
}
```

**Important:** `TryStepNode` extends `IrNode` (not `ActionStepNode`). It's a sibling kind of step. The `ActionSequenceNode.steps` list type must widen to accommodate it — change from `List<ActionStepNode>` to `List<IrNode>`, with a runtime guard in the resolver that each element is either `ActionStepNode` or `TryStepNode`.

**Codec change:** the `actionSequence` payload's `steps` array now mixes `actionStep` and `tryStep` tagged objects. Decoder dispatches on tag.

**Step 2 — Verify + commit.**

---

## Task 2 — Resolver wraps in try/catch

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` (where `ActionSequenceNode` is resolved).

**Step 1 — Refactor the ActionSequenceNode resolver** to dispatch per step kind:

```dart
case ActionSequenceNode(:final steps):
  return () async {
    var localEnv = input;
    for (final step in steps) {
      localEnv = await _runActionStep(step, localEnv, runtime);
    }
  };

// New helper:
Future<Map<String, Object?>> _runActionStep(
  IrNode step,
  Map<String, Object?> env,
  Runtime runtime,
) async {
  if (step is ActionStepNode) {
    final result = evalExpression(step.call, env, runtime);
    final value = step.awaitResult && result is Future ? await result : result;
    if (step.bindResult != null) {
      return {...env, step.bindResult!: value};
    }
    return env;
  }
  if (step is TryStepNode) {
    try {
      var e = env;
      for (final s in step.trySteps) {
        e = await _runActionStep(s, e, runtime);
      }
      // Try succeeded: don't propagate catch env to outer; outer continues with try's env.
      return e;
    } catch (err, _) {
      var e = step.exceptionBind != null
          ? {...env, step.exceptionBind!: err}
          : env;
      for (final s in step.catchSteps) {
        e = await _runActionStep(s, e, runtime);
      }
      // Catch's bindings DON'T leak to outer (matches Dart's lexical scoping).
      return env;
    }
  }
  throw StateError('Unknown action step kind: ${step.runtimeType}');
}
```

**Note on scoping:** Dart's try/catch doesn't introduce a new scope for variables declared inside the try block — they're scoped to the block, not visible outside. The resolver above matches this: on success, the try's local-env extensions (`bindResult` from steps inside the try) are discarded after the try-block; same for catch. Outer steps see only the env that existed before the TryStepNode.

This differs from a plain `ActionStepNode.bindResult` at the top level, which DOES extend env for subsequent steps. The asymmetry is intentional and matches Dart semantics.

**Step 2 — Verify + commit.**

---

## Task 3 — Lowerer recognizes `TryStatement`

**Files:**
- Modify: the async-block lowerer added by ActionSequenceNode (Feature 4, Task 3).

**Step 1 — Extend the recognized grammar:**

```
AsyncBody := (Step)*
Step :=
  | ExpressionStatement(AwaitExpression(call))   → ActionStepNode(awaitResult: true)
  | ExpressionStatement(call)                    → ActionStepNode(awaitResult: false)
  | VariableDeclarationStatement(final x = await call())  → ActionStepNode(awaitResult: true, bindResult: x)
  | TryStatement                                 → TryStepNode (this plan)
```

**Step 2 — Lower `TryStatement`:**

```dart
TryStepNode _lowerTryStatement(TryStatement stmt) {
  // Reject `finally` blocks.
  if (stmt.finallyBlock != null) {
    throw InvalidScreenBodyError(
      '`finally` blocks are not supported in action handlers (yet). '
      'Use only try/catch.',
    );
  }
  // Single catch only (no `on TypeX catch (e)` clauses with multiple types).
  if (stmt.catchClauses.length != 1) {
    throw InvalidScreenBodyError(
      'Action handlers support exactly one catch clause (no typed `on Type catch (e)` chains).',
    );
  }
  final catchClause = stmt.catchClauses.single;
  if (catchClause.exceptionType != null) {
    throw InvalidScreenBodyError(
      'Action handlers do not support typed catch (`on FormatException catch (e)`). '
      'Use a single untyped catch and dispatch on `e.runtimeType` in a registered VM method if needed.',
    );
  }
  final excBind = catchClause.exceptionParameter?.name.lexeme; // null = `catch { ... }`
  final trySteps = _lowerStepBlock(stmt.body);
  final catchSteps = _lowerStepBlock(catchClause.body);
  return TryStepNode(
    trySteps: trySteps,
    catchSteps: catchSteps,
    exceptionBind: excBind,
  );
}
```

`_lowerStepBlock(Block)` is the existing helper that walks an async-block's statements emitting `ActionStepNode`s. Note: it must allow nested `TryStatement`s recursively, but reject statement-level control flow (`if`, `for`, `switch`) inside try/catch — same restriction as the outer async block.

**Step 3 — Verify + commit.**

---

## Task 4 — Tests + demo

**Files:**
- Create: `packages/desk_sdui/test/try_step_eval_test.dart`
- Create: `packages/desk_sdui_generator/test/try_step_lowering_test.dart`
- Modify: an existing async-demo screen OR create `try_step_demo.dart`.

**Step 1 — Resolver tests:**
1. Try with no exception: try-steps run, catch-steps skipped, env reset to pre-try state.
2. Try with exception in step 1: trySteps[0] throws, catchSteps run, env in catch has `exceptionBind` set.
3. Exception bind is null (`catch {}`): catchSteps run, no `e` binding in env.
4. Outer step after a try observes only pre-try env (try's bindings discarded).
5. Nested TryStepNode: inner catch handles inner exception, outer continues.

**Step 2 — Lowerer tests:**
1. `try { await a(); } catch (e) { vm.log(e); }` lowers to TryStepNode with one trySteps + one catchSteps, exceptionBind: 'e'.
2. `try { ... } catch { ... }` (no param) lowers with `exceptionBind: null`.
3. Reject `try ... finally`.
4. Reject `try ... on FormatException catch (e) ...`.
5. Reject `if (cond) throw X` inside try (statement control flow rejected).
6. Accept nested try inside try: `try { try { await a(); } catch { } } catch { }`.

**Step 3 — Demo screen:**

```dart
@Screen('try_step_demo')
Widget tryStepDemo(SaveController vm) {
  return ElevatedButton(
    onPressed: () async {
      try {
        await vm.save();
      } catch (e) {
        vm.showError(e);
      }
    },
    child: const Text('Save'),
  );
}
```

(Define `SaveController` with `Future<void> save() async { throw ...; }` and `void showError(Object e) {...}` for a runnable demo.)

**Step 4 — Regen, verify, commit.**

---

## Task 5 — Full-suite verification

(Standard.)

---

## Out of scope

- **`finally` blocks.** Future plan.
- **Typed catches** (`on FormatException catch (e)`). Author dispatches in a registered VM method.
- **Multiple catch clauses.** Single catch only.
- **`rethrow`.** Add later if a real use case appears.
- **`throw <expr>` from payload code.** Not in this plan; the VM method's exception is what flows here.

---

## Verify commands

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
