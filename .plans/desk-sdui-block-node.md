# desk_sdui — `BlockNode` + control flow signals

**Goal:** Support multi-statement bodies in `@Screen` and payload-function bodies, including statement-level `if`/`else`. Foundation for statement loops (Feature 10) and payload functions with imperative bodies (Feature 12).

**Dependencies:** none architecturally — introduces the statement-form resolver. In practice, pairs naturally with `AssignNode` (Feature 8); this plan can land first or together.

**Architecture (load-bearing):**
- New resolver path: `executeStatement(node, env)` returns a `ControlFlow` signal — `Normal` | `Break` | `Continue` | `Return(value)`. Expression resolution stays unchanged (`evalExpression` returns a value).
- New IR nodes: `BlockNode { statements }`, `IfStatementNode { cond, then, else_ }`, `BreakNode`, `ContinueNode`, `ReturnNode { value }`.
- `BlockNode` executes statements in order; non-`Normal` signals abort the block and propagate up.
- Loop nodes (Feature 10) consume `Break`/`Continue` at their boundary.
- Function entries (payload functions, `@Screen` bodies) consume `Return(value)`.

**Tech stack:** existing IR + 5 new nodes, new statement-form resolver, lowerer extensions.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define a marker class** `StatementNode extends IrNode` (or a mixin); existing expression nodes still extend `ExpressionNode`. This makes the lowerer's typing self-checking.

**Step 2 — Define the statement nodes:**

```dart
final class BlockNode extends StatementNode {
  const BlockNode({required this.statements});
  final List<IrNode> statements;
  // operator ==, hashCode, toString
}

final class IfStatementNode extends StatementNode {
  const IfStatementNode({required this.cond, required this.then, this.else_});
  final IrNode cond;
  final IrNode then;     // typically BlockNode or expression-as-statement
  final IrNode? else_;
}

final class BreakNode extends StatementNode { const BreakNode(); }
final class ContinueNode extends StatementNode { const ContinueNode(); }

final class ReturnNode extends StatementNode {
  const ReturnNode({this.value});
  final IrNode? value;
}
```

**Step 3 — Codec:** tags `'block'`, `'ifStmt'`, `'break'`, `'continue'`, `'returnStmt'`. Block payload `{statements}`; if payload `{cond, then, else}` (else optional); break/continue no payload; return `{value}` (optional).

**Step 4 — Verify + commit.**

---

## Task 2 — Resolver: statement-form path + control flow signals

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` (add a sibling `executeStatement` function).

**Step 1 — Define the `ControlFlow` sum type.** Dart 3 sealed + pattern-matching:

```dart
sealed class ControlFlow {
  const ControlFlow();
}
final class FlowNormal extends ControlFlow {
  const FlowNormal();
  static const instance = FlowNormal();
}
final class FlowBreak extends ControlFlow {
  const FlowBreak();
  static const instance = FlowBreak();
}
final class FlowContinue extends ControlFlow {
  const FlowContinue();
  static const instance = FlowContinue();
}
final class FlowReturn extends ControlFlow {
  const FlowReturn(this.value);
  final Object? value;
}
```

(Const singletons for the three zero-arg cases avoid allocation in the hot path.)

**Step 2 — `executeStatement(node, env, runtime)` implementation:**

```dart
ControlFlow executeStatement(IrNode node, Map<String, _Cell> env, Runtime runtime) {
  switch (node) {
    case BlockNode(:final statements):
      for (final s in statements) {
        final flow = executeStatement(s, env, runtime);
        if (flow is! FlowNormal) return flow;
      }
      return FlowNormal.instance;

    case IfStatementNode(:final cond, :final then, :final else_):
      final c = evalExpression(cond, env, runtime);
      if (c == true) return executeStatement(then, env, runtime);
      if (else_ != null) return executeStatement(else_, env, runtime);
      return FlowNormal.instance;

    case BreakNode():
      return FlowBreak.instance;
    case ContinueNode():
      return FlowContinue.instance;
    case ReturnNode(:final value):
      return FlowReturn(value == null ? null : evalExpression(value, env, runtime));

    // Statement-form lets are reused from Feature 1: a LetNode at statement position
    // extends env in-place for the rest of the enclosing block. Distinct from
    // expression-form LetNode, which scopes name to its `body` only.
    // Decision: keep LetNode expression-only; statement-form locals lower as
    // a sibling `LetStatementNode` (not introduced here — Feature 12 adds it
    // when payload functions need it).

    default:
      // Expression-as-statement: evaluate and discard the value.
      evalExpression(node, env, runtime);
      return FlowNormal.instance;
  }
}
```

**Step 3 — Entry points.**
- `@Screen` body lowered to a top-level `BlockNode` (when block-bodied with multi-statement content): the runtime entry calls `executeStatement` on it; intercepts a `FlowReturn(value)` and treats the value as the screen's rendered widget. Outside `FlowReturn`, surface a runtime error `@Screen body did not return a widget`.
- Existing expression-body `@Screen` (`=> Center(...)`) continues to resolve via `evalExpression`.

**Step 4 — Verify** — existing single-return block-bodies continue to work (the lowerer can keep its current path for them, OR migrate them to BlockNode([ReturnNode(...)]) — either way the result is equivalent; pick whichever is cleaner).

**Step 5 — Commit.**

---

## Task 3 — Lowerer: block bodies, statement if/else, return/break/continue

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`.

**Step 1 — Block bodies.** Today the LetNode-aware lowerer recognizes `(VariableDecl)* ReturnStatement`. Generalize to: any statement sequence, lowered to `BlockNode([<lowered statements>])`.

**Step 2 — Per-statement dispatch:**

```dart
IrNode lowerStatement(Statement stmt) {
  if (stmt is ReturnStatement) {
    return ReturnNode(value: stmt.expression == null ? null : lowerExpression(stmt.expression!));
  }
  if (stmt is BreakStatement) {
    if (stmt.label != null) {
      throw InvalidScreenBodyError('Labeled break is not supported.');
    }
    return BreakNode();
  }
  if (stmt is ContinueStatement) {
    if (stmt.label != null) {
      throw InvalidScreenBodyError('Labeled continue is not supported.');
    }
    return ContinueNode();
  }
  if (stmt is IfStatement) {
    return IfStatementNode(
      cond: lowerExpression(stmt.condition),
      then: lowerStatement(stmt.thenStatement),
      else_: stmt.elseStatement == null ? null : lowerStatement(stmt.elseStatement!),
    );
  }
  if (stmt is Block) {
    return BlockNode(
      statements: stmt.statements.map(lowerStatement).toList(),
    );
  }
  if (stmt is VariableDeclarationStatement) {
    // Reuse LetNode-aware lowering. In a BlockNode statement position, this
    // becomes a sibling `LetStatementNode` (or absorbed via a nested BlockNode
    // structure — see Step 4 below).
    return _lowerVarDeclStatement(stmt);
  }
  if (stmt is ExpressionStatement) {
    return lowerExpression(stmt.expression);
    // Caller (BlockNode loop) treats non-StatementNode results as expression-statements.
  }
  throw InvalidScreenBodyError('Unsupported statement: ${stmt.runtimeType}');
}
```

**Step 3 — Variable declarations inside a block.** The cleanest model: a variable declaration extends the enclosing block's env for the *rest* of that block. Two ways to encode:
- **Option A:** introduce `LetStatementNode` whose scope is the rest of the block. Resolver mutates env in place (or wraps the block's tail).
- **Option B:** at lowering time, fold the `(VariableDecl)* Tail` pattern into nested `LetNode` expressions — but LetNode is expression-form, returning the value of `body`. That fights with the block-flow path.

**Pick option A.** Define `LetStatementNode { name, value }` (mutates env when executed as a statement). The lowerer rewrites blocks containing var decls so each decl is a `LetStatementNode` followed by the rest of the block executing with the binding visible.

But that means a block-internal `var x = 0` adds `x` to the **outer** block's env permanently — which is wrong (block-scoped should leave the binding at block exit). Dart's lexical scoping says block-locals are gone after the block.

**Refined approach:** the lowerer detects var decls in blocks and emits a *nested* BlockNode for the rest:

```
block { stmtA; var x = 0; stmtB; stmtC; }
  →
BlockNode([
  stmtA,
  LetStatementNode(x, 0),
  stmtB,
  stmtC,
])
```

But to enforce scoping, the resolver's BlockNode handler should clone env on entry and discard the clone on exit:

```dart
case BlockNode(:final statements):
  final scoped = Map<String, _Cell>.of(env); // shallow copy of cell refs
  for (final s in statements) {
    final flow = executeStatement(s, scoped, runtime);
    if (flow is! FlowNormal) return flow;
  }
  return FlowNormal.instance;
```

`LetStatementNode` inserts into `scoped`. Outer env is unaffected because `scoped` is a separate Map. The `_Cell` objects are still shared via reference (so outer mutables remain mutable), but the binding *names* are scoped to the block. This is exactly Dart's lexical scoping for locals.

**Cost note:** `Map.of` on entry costs O(env-size). For a screen with K nested blocks and N bindings, total cost is O(K × N). With typical N=10, K=3, that's 30 ops per build. Acceptable. If profiling reveals it's hot, switch to a copy-on-write linked-list scope structure.

**Step 4 — `LetStatementNode`:**

```dart
final class LetStatementNode extends StatementNode {
  const LetStatementNode({required this.name, required this.value, required this.isFinal});
  final String name;
  final IrNode value;
  final bool isFinal;
}
```

Resolver:

```dart
case LetStatementNode(:final name, :final value, :final isFinal):
  final v = evalExpression(value, env, runtime);
  env[name] = _Cell(v); // writable cell; final guard enforced at lowering
  return FlowNormal.instance;
```

The `isFinal` flag is consumed by the lowerer's binding tracker; resolver doesn't enforce it.

**Step 5 — Verify + commit.**

---

## Task 4 — Tests + demos

**Files:**
- Create: `packages/desk_sdui/test/block_node_eval_test.dart`
- Create: `packages/desk_sdui_generator/test/block_node_lowering_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/imperative_demo.dart`

**Step 1 — Resolver tests:**
1. Empty block executes returning `FlowNormal`.
2. Block with three expression-statements evaluates all three (verify via side-effecting method call counts).
3. `Break` mid-block aborts the rest, returns `FlowBreak`.
4. `Continue` mid-block aborts the rest, returns `FlowContinue`.
5. `Return(42)` mid-block aborts the rest, returns `FlowReturn(42)`.
6. `IfStatementNode` with true cond executes then-branch.
7. `IfStatementNode` with false cond + null else returns `FlowNormal` (skipped).
8. `IfStatementNode` with false cond + non-null else executes else-branch.
9. Block scoping: a `LetStatementNode` inside an inner block doesn't leak to the outer block.
10. Block scoping: outer `_Cell` mutation from inside a block IS visible to outer reads (shared cell reference, not value copy).

**Step 2 — Lowerer tests:**
1. `{ var x = 0; if (x < 1) { x = x + 1; } return x; }` lowers to BlockNode(...) with LetStatementNode + IfStatementNode + ReturnNode.
2. `return;` (no value) lowers to ReturnNode(value: null).
3. Reject labeled break/continue with diagnostic.

**Step 3 — Demo:** an imperative screen that exercises if/else + local mutation + return:

```dart
@Screen('imperative_demo')
Widget imperativeDemo(ImpController vm) {
  if (vm.items.isEmpty) {
    return const Text('No items');
  }
  var count = 0;
  for (final item in vm.items) {
    if (item.startsWith('!')) {
      continue;
    }
    count = count + 1;
  }
  return Text('Visible: $count');
}
```

(Note: the imperative-`for` here requires Feature 10 — verify by leaving the imperative-for under a `// SCAFFOLD:` comment until Feature 10 ships, or pick a simpler demo that uses only if/else + assignment + return.)

Simpler demo that fits Feature 9 alone:

```dart
@Screen('imperative_demo')
Widget imperativeDemo(ImpController vm) {
  if (vm.items.isEmpty) {
    return const Text('No items');
  }
  final summary = '${vm.items.length} items';
  return Text(summary);
}
```

**Step 4 — Verify + commit.**

---

## Task 5 — Full-suite verification

(Standard.)

---

## Out of scope

- **Labeled break/continue.** Rejected with diagnostic.
- **`switch` statement** (not switch expression). Future plan.
- **`try` at statement form** in payload functions. Feature 6 (TryStepNode) handles try inside action bodies; payload-function try is a follow-up.
- **`throw` from payload.** Requires registered `Exception` ctors and `__throw__` op; defer.
- **`finally` blocks.** Defer.

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
