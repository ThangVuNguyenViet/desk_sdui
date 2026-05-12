# desk_sdui — Statement loops (`WhileNode`, `DoNode`, imperative `ForNode`)

**Goal:** Support `while`/`do-while`/`for(;;)` loops in `@Screen` bodies and payload functions. Required for any imperative accumulator pattern (`int sum = 0; for (...) sum += x;`).

**Dependencies:** Features 8 (mutable env / AssignNode) and 9 (BlockNode + control flow signals) must be merged.

**Architecture (load-bearing):**
- Three new statement nodes: `WhileNode { condition, body }`, `DoNode { body, condition }`, `ImperativeForNode { init, condition, update, body }`.
- Resolver iterates: evaluate condition (or run body first for `Do`), execute body via `executeStatement`, handle `FlowBreak` (exit loop) / `FlowContinue` (continue to next iteration) / `FlowReturn` (propagate up).
- `ImperativeForNode` introduces a fresh scope for the loop variable — like Dart's `for (int i = 0; ...; ...)` where `i` is block-scoped to the loop.
- **Cost-rule status:** these violate the build-path cost rule when iteration count depends on data. Author opts in. Codegen-time diagnostics surfaced by Feature 13 (cost classifier).

**Tech stack:** existing IR + 3 new nodes, existing statement-form resolver from Feature 9.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the nodes:**

```dart
final class WhileNode extends StatementNode {
  const WhileNode({required this.condition, required this.body});
  final IrNode condition;
  final IrNode body; // typically BlockNode
}

final class DoNode extends StatementNode {
  const DoNode({required this.body, required this.condition});
  final IrNode body;
  final IrNode condition;
}

/// C-style `for (init; cond; update) body`. Distinct from collection-for
/// (`for (x in xs)`), which stays sugar over the existing ForNode.
/// `init` is typically a LetStatementNode introducing the loop variable.
final class ImperativeForNode extends StatementNode {
  const ImperativeForNode({
    this.init,
    this.condition,
    this.update,
    required this.body,
  });
  final IrNode? init;        // LetStatementNode or expression-statement
  final IrNode? condition;   // null = infinite loop until break
  final IrNode? update;      // expression evaluated after each iteration
  final IrNode body;
}
```

**Step 2 — Codec:** tags `'while'`, `'do'`, `'imperativeFor'`. Payloads match field names.

**Step 3 — Verify + commit.**

---

## Task 2 — Resolver: iterate each loop, handle flow signals

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` — extend `executeStatement` from Feature 9.

**Step 1 — `WhileNode` case:**

```dart
case WhileNode(:final condition, :final body):
  while (evalExpression(condition, env, runtime) == true) {
    final flow = executeStatement(body, env, runtime);
    if (flow is FlowBreak) break;
    if (flow is FlowContinue) continue;
    if (flow is FlowReturn) return flow; // propagate
  }
  return FlowNormal.instance;
```

**Step 2 — `DoNode` case:**

```dart
case DoNode(:final body, :final condition):
  do {
    final flow = executeStatement(body, env, runtime);
    if (flow is FlowBreak) break;
    if (flow is FlowContinue) continue;
    if (flow is FlowReturn) return flow;
  } while (evalExpression(condition, env, runtime) == true);
  return FlowNormal.instance;
```

**Step 3 — `ImperativeForNode` case:**

```dart
case ImperativeForNode(:final init, :final condition, :final update, :final body):
  // Fresh scope for the loop variable, per Dart semantics.
  final scoped = Map<String, _Cell>.of(env);
  if (init != null) {
    final flow = executeStatement(init, scoped, runtime);
    if (flow is! FlowNormal) return flow;
  }
  while (condition == null || evalExpression(condition, scoped, runtime) == true) {
    final flow = executeStatement(body, scoped, runtime);
    if (flow is FlowBreak) break;
    if (flow is FlowReturn) return flow;
    // FlowContinue and FlowNormal both fall through to update.
    if (update != null) {
      evalExpression(update, scoped, runtime); // discard value
    }
  }
  return FlowNormal.instance;
```

**Note on `update`:** Dart's spec says `update` is an *expression*, not a statement (no var decls allowed there). Same here — `update` must lower from an `Expression` in the AST.

**Step 4 — Verify + commit.**

---

## Task 3 — Lowerer: recognize `WhileStatement`, `DoStatement`, statement-form `ForStatement`

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`.

**Step 1 — `WhileStatement`:**

```dart
if (stmt is WhileStatement) {
  return WhileNode(
    cond: lowerExpression(stmt.condition),
    body: lowerStatement(stmt.body),
  );
}
```

**Step 2 — `DoStatement`:**

```dart
if (stmt is DoStatement) {
  return DoNode(
    body: lowerStatement(stmt.body),
    cond: lowerExpression(stmt.condition),
  );
}
```

**Step 3 — `ForStatement`.** Dart's `ForStatement` has two variants: `ForParts` (C-style `for(init; cond; update)`) and `ForEachParts` (collection `for(x in xs)`). The collection variant ALREADY lowers via the existing collection-for path. Detect the C-style variant and dispatch:

```dart
if (stmt is ForStatement) {
  final parts = stmt.forLoopParts;
  if (parts is ForPartsWithDeclarations) {
    return ImperativeForNode(
      init: _lowerForInit(parts.variables),
      cond: parts.condition == null ? null : lowerExpression(parts.condition!),
      update: _lowerForUpdate(parts.updaters),
      body: lowerStatement(stmt.body),
    );
  }
  if (parts is ForPartsWithExpression) {
    return ImperativeForNode(
      init: parts.initialization == null ? null : ExpressionStatementWrapper(lowerExpression(parts.initialization!)),
      cond: parts.condition == null ? null : lowerExpression(parts.condition!),
      update: _lowerForUpdate(parts.updaters),
      body: lowerStatement(stmt.body),
    );
  }
  // ForEachParts: collection-for. Delegate to existing path.
  return _lowerCollectionFor(stmt);
}
```

Helper `_lowerForInit` handles `VariableDeclarationList` (typically `int i = 0`) — emits a `LetStatementNode` or, for multiple decls, a `BlockNode` containing several `LetStatementNode`s.

`_lowerForUpdate(NodeList<Expression>)` — Dart allows multiple updaters (`i++, j--`). If there's one, lower directly. If multiple, wrap in a small `SequenceNode` (Feature 7) or emit a `BlockNode([ExpressionStatement(a), ExpressionStatement(b)])`. Pick whichever is already available; both work.

**Step 4 — Label rejection.** Loops with labels (`outer: while (...)`) are rejected because we don't support labeled break/continue (per Feature 9). Diagnostic: `Labeled loops are not supported.`

**Step 5 — Verify + commit.**

---

## Task 4 — Tests + demo

**Files:**
- Create: `packages/desk_sdui/test/loop_eval_test.dart`
- Create: `packages/desk_sdui_generator/test/loop_lowering_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/loop_demo.dart`

**Step 1 — Resolver tests:**
1. WhileNode: counter `var i = 0; while (i < 5) { i = i + 1; }` runs 5 times.
2. WhileNode with false initial condition: body never runs.
3. WhileNode with `break`: exits early.
4. WhileNode with `continue`: skips rest of body, re-checks condition.
5. WhileNode with `return`: propagates FlowReturn out of the loop.
6. DoNode: body runs at least once even when condition initially false.
7. ImperativeForNode: standard counted loop runs N times.
8. ImperativeForNode: null condition + body with `break` (infinite-until-break).
9. ImperativeForNode: loop variable is block-scoped (not visible after loop).
10. Nested loops: inner `break` doesn't exit outer loop.

**Step 2 — Lowerer tests:**
1. `while (cond) { body }` lowers to WhileNode.
2. `do { body } while (cond);` lowers to DoNode.
3. `for (int i = 0; i < n; i++) { ... }` lowers to ImperativeForNode with all four parts populated.
4. `for (;;) { ... }` lowers to ImperativeForNode with init/cond/update all null.
5. `for (var item in items) { ... }` delegates to collection-for (NOT ImperativeForNode).
6. Reject labeled loops.

**Step 3 — Demo:**

```dart
@Screen('loop_demo')
Widget loopDemo(LoopController vm) {
  var positives = 0;
  for (var i = 0; i < vm.numbers.length; i++) {
    if (vm.numbers[i] > 0) {
      positives = positives + 1;
    }
  }
  return Text('Positives: $positives');
}
```

(`vm.numbers` is a `List<int>`. `vm.numbers[i]` requires `IndexAccessNode` on a List — already supported per the parser-surface table.)

**Step 4 — Verify + commit.**

---

## Task 5 — Full-suite verification

(Standard.)

---

## Out of scope

- **Labeled break/continue** (rejected).
- **`break`/`continue` outside a loop body** — caught at runtime as `FlowBreak/FlowContinue propagated to a top-level @Screen body, expected FlowReturn or FlowNormal`. Lowerer could pre-check, but the resolver guard is sufficient.
- **`yield` / `yield*`** — generators, universal skip.
- **Cost classifier diagnostics** — Feature 13's job. This plan lands the loops; warnings come later.

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
