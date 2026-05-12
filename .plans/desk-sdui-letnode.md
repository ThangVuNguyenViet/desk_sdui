# desk_sdui — LetNode (locals in screen bodies)

**Goal:** Support `final t = expr; <rest>` shapes in `@Screen` bodies. Today these fail in the lowerer; today's workaround is to compute inline or hoist into a registered method. LetNode is the foundation for `LambdaNode` (re-uses the env extension shape) and for pattern destructuring (Feature 3 lowers record `final (a, b) = pair;` to chained LetNodes).

**Architecture (load-bearing):**
- New IR node `LetNode { name, value, body }` — single-assignment binding.
- Resolver evaluates `value` in current env, extends env with `{name: result}`, evaluates `body` in extended env. ~10 lines.
- Lowerer recognizes `VariableDeclarationStatement` followed by `ReturnStatement` (or further declarations) in `@Screen` block bodies. Multiple sequential `final` bindings chain into nested `LetNode`s.
- Per-binding cost is O(1) env-map allocation; per-screen cost stays `O(IR-tree-size)`. No cost-rule violation.

**Tech stack:** Dart analyzer, existing `desk_sdui_annotation` IR, existing `desk_sdui` resolver, existing `desk_sdui_generator` lowerer.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Add `LetNode` to the IR

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_encoder.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_decoder.dart`

**Step 1 — Define the node** (place near `GetterNode` / other expression nodes):

```dart
/// Binds `name = value` and evaluates `body` in the extended env.
/// Lowered from `final name = value; <body>` in @Screen bodies. Single-
/// assignment — no re-binding within the same scope.
final class LetNode extends ExpressionNode {
  const LetNode({required this.name, required this.value, required this.body});
  final String name;
  final IrNode value;
  final IrNode body;

  @override
  bool operator ==(Object other) =>
      other is LetNode &&
      other.name == name &&
      other.value == value &&
      other.body == body;
  @override
  int get hashCode => Object.hash(name, value, body);
  @override
  String toString() => 'LetNode($name = $value in $body)';
}
```

**Step 2 — JSON codec:** add `'let'` case to encoder + decoder, payload `{name, value, body}`. Follow the `GetterNode` pattern (see `'getter'` cases in `json_encoder.dart` line 109 / `json_decoder.dart` line 94).

**Step 3 — Verify**

```
cd packages/desk_sdui_annotation && dart analyze && dart test
```

Expected: clean, including any codec round-trip tests.

**Step 4 — Commit**

```
git add -A && git commit -m "feat(ir): add LetNode for screen-body locals"
```

---

## Task 2 — Resolver wires `LetNode`

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart`

**Step 1 — Find** the `switch` over IR node types in `evalExpression` (look for existing `GetterNode` case).

**Step 2 — Add the case**:

```dart
case LetNode(:final name, :final value, :final body):
  final v = evalExpression(value, input, runtime);
  return evalExpression(body, {...input, name: v}, runtime);
```

**Note on env:** the resolver's `input` parameter IS the env map. We extend it with the new binding; the outer scope keeps its original `input` unchanged after this expression resolves. No mutation of the caller's map.

**Step 3 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

Expected: existing tests pass; no LetNode coverage yet (added in Task 4 / Task 5 acceptance).

**Step 4 — Commit**

```
git commit -am "feat(eval): resolve LetNode by extending env with name=value"
```

---

## Task 3 — Lowerer recognizes `final` declarations in block bodies

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/screen_lowering.dart` (or wherever block-body `@Screen` is currently lowered — `grep -rn "BlockFunctionBody\|ReturnStatement" packages/desk_sdui_generator/lib/src/screen_lowering/`).

**Step 1 — Audit the current block-body path.** A block-body `@Screen` looks like:

```dart
@Screen('foo')
Widget foo(Vm vm) {
  return Center(child: Text(vm.title));
}
```

Today's lowerer enforces single-`return` block bodies (per `feat(desk_sdui_generator): block-body @Screen, integer division, parens unwrap` commit). Find the check that rejects multi-statement bodies — likely a `statements.length == 1 && statements.first is ReturnStatement` guard. Document the exact file + line in the commit message.

**Step 2 — Extend the recognized shape** to accept sequences like:

```dart
@Screen('foo')
Widget foo(Vm vm) {
  final t = vm.title.toUpperCase();
  return Center(child: Text(t));
}
```

The recognized grammar is now:

```
BlockFunctionBody := (VariableDeclarationStatement)* ReturnStatement
```

For each leading `VariableDeclarationStatement`:
- It MUST be `final` (not `var`, not `late`). Reject `var` with a diagnostic: `"@Screen locals must be 'final' (single-assignment). Use a registered VM method for mutable state."`
- It MUST have exactly one variable declared (no `final a = 1, b = 2;`). Split-declaration form is a separate plan.
- The initializer MUST exist (no `final t;` followed by assignment).

**Step 3 — Lower to nested LetNodes.** Given `final a = X; final b = Y; return Z;`, produce:

```dart
LetNode(name: 'a', value: lower(X), body:
  LetNode(name: 'b', value: lower(Y), body:
    lower(Z)))
```

Implementation sketch (right-fold over the leading declarations):

```dart
IrNode lowerBlockBody(BlockFunctionBody body) {
  final stmts = body.block.statements;
  final returnStmt = stmts.last;
  if (returnStmt is! ReturnStatement || returnStmt.expression == null) {
    throw InvalidScreenBodyError('@Screen body must end with a return statement.');
  }
  IrNode acc = lowerExpression(returnStmt.expression!);
  for (final stmt in stmts.take(stmts.length - 1).toList().reversed) {
    if (stmt is! VariableDeclarationStatement) {
      throw InvalidScreenBodyError(
        '@Screen body may only contain final locals before the return.');
    }
    final decl = stmt.variables;
    if (!decl.isFinal) {
      throw InvalidScreenBodyError(
        "@Screen locals must be 'final' (single-assignment).");
    }
    if (decl.variables.length != 1) {
      throw InvalidScreenBodyError(
        '@Screen locals: declare one variable per statement.');
    }
    final v = decl.variables.single;
    if (v.initializer == null) {
      throw InvalidScreenBodyError(
        '@Screen locals must have an initializer.');
    }
    acc = LetNode(
      name: v.name.lexeme,
      value: lowerExpression(v.initializer!),
      body: acc,
    );
  }
  return acc;
}
```

(Names of types may differ — check `package:analyzer/dart/ast/ast.dart` for the actual `VariableDeclarationList.isFinal` accessor.)

**Step 4 — Reference reads in the body** (e.g. `Text(t)`) already lower through the lowerer's existing `Identifier` path, which produces `RefNode(['t'])`. The resolver's `RefNode` case looks up `'t'` in `input` — which now contains the binding because LetNode extended it. No change needed to identifier lowering or RefNode resolution.

**Step 5 — Verify**

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

Expected: existing block-body tests pass; new LetNode tests added in Task 4.

**Step 6 — Commit**

```
git commit -am "feat(codegen): lower 'final' locals in @Screen block bodies to LetNode"
```

---

## Task 4 — Unit tests for lowering

**Files:**
- Create: `packages/desk_sdui_generator/test/let_node_lowering_test.dart`

**Step 1 — Write end-to-end lowerer tests** following the pattern of existing tests in `packages/desk_sdui_generator/test/` (probably `screen_lowering_test.dart` — read it first for the test harness shape).

Cases to cover:
1. Single `final` binding before return → one LetNode wrapping the return expression.
2. Two sequential `final` bindings → nested LetNodes (outer = first binding, inner = second binding).
3. Reference to a let-bound name in the body → `RefNode(['name'])` inside the LetNode body.
4. Reference to a let-bound name in a later let's value → outer LetNode's body is inner LetNode whose value references outer name.
5. Reject `var t = ...` with the documented diagnostic message.
6. Reject `final a, b;` (uninitialized) with the documented diagnostic message.
7. Reject `final a = 1, b = 2;` (split-declaration) with the documented diagnostic message.
8. Reject blocks with statements other than `VariableDeclarationStatement` / `ReturnStatement` (e.g. an `ExpressionStatement`).

**Step 2 — Verify**

```
cd packages/desk_sdui_generator && dart test test/let_node_lowering_test.dart
```

Expected: all 8 cases pass.

**Step 3 — Commit**

```
git commit -am "test(desk_sdui_generator): cover LetNode lowering — accept + reject cases"
```

---

## Task 5 — Resolver tests

**Files:**
- Create: `packages/desk_sdui/test/let_node_eval_test.dart`

**Step 1 — Write resolver tests** following existing patterns in `packages/desk_sdui/test/`.

Cases to cover:
1. `LetNode('t', LiteralNode(42), RefNode(['t']))` → 42.
2. Nested: `LetNode('a', 1, LetNode('b', 2, BinaryOpNode('+', RefNode(['a']), RefNode(['b']))))` → 3.
3. Inner let shadows outer: `LetNode('x', 1, LetNode('x', 2, RefNode(['x'])))` → 2 (Map spread semantics — last wins).
4. Outer scope unaffected after let: build a LetNode whose body returns RefNode for the let's name, evaluate twice with the same outer `input` — second eval doesn't see the binding from first eval. (Tests that resolver doesn't mutate caller's map.)
5. Let value uses outer-scope binding: with `input = {'outer': 5}`, `LetNode('t', RefNode(['outer']), RefNode(['t']))` → 5.

**Step 2 — Verify**

```
cd packages/desk_sdui && dart test test/let_node_eval_test.dart
```

Expected: all 5 cases pass.

**Step 3 — Commit**

```
git commit -am "test(desk_sdui): cover LetNode resolver — single, nested, shadowing"
```

---

## Task 6 — Demo screen exercising LetNode

**Files:**
- Modify or create: a `.dart` file under `packages/desk_sdui_demo/lib/screens/` — pick an existing simple screen (e.g. one of the counter screens) and add a `final` local that simplifies a repeated expression, OR add a new minimal screen `let_demo.dart` whose body is `final upper = vm.title.toUpperCase(); return Text(upper);`.

**Step 1 — Pick the approach.** Adding a new screen is safer (doesn't risk breaking an existing screen's behavior). Create `packages/desk_sdui_demo/lib/screens/let_demo.dart`:

```dart
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

class LetDemoData {
  const LetDemoData({required this.title});
  final String title;
}

@Screen('let_demo')
Widget letDemo(LetDemoData data) {
  final upper = data.title.toUpperCase();
  final exclaimed = '$upper!';
  return Center(child: Text(exclaimed));
}
```

**Step 2 — Regenerate**

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
```

**Step 3 — Verify** the generated IR contains nested LetNodes (don't just trust the build):

```
grep -A2 "LetNode" packages/desk_sdui_demo/lib/screens/let_demo.sdui.g.dart
```

Expected: two LetNode constructor calls (outer = `upper`, inner = `exclaimed`).

**Step 4 — Verify** `desk_sdui_setup.g.dart` enumerates the new screen:

```
grep "let_demo\|registerLetDemo" packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart
```

Expected: at least one match (the per-screen registration call).

**Step 5 — Commit** the new screen + regenerated artifacts.

```
git add packages/desk_sdui_demo/lib/screens/let_demo.dart \
        packages/desk_sdui_demo/lib/screens/let_demo.sdui.g.dart \
        packages/desk_sdui_demo/lib/screens/let_demo.sdui_reg.g.dart \
        packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart
git commit -m "feat(demo): add let_demo screen exercising LetNode lowering"
```

**Step 6 (optional) — wire into the demo app's screen switcher** if `main.dart` has one. If `main.dart` only renders one screen at a time and switching it would distract from existing demos, skip this step. Just having the screen lowered + registered proves the end-to-end path; running it visually isn't required for this plan's acceptance.

---

## Task 7 — Full-suite verification

**Step 1 — Per-package analyze + test**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done
```

Expected: clean.

**Step 2 — Demo analyze + test**

```
cd packages/desk_sdui_demo
flutter analyze
flutter test
```

Expected: clean.

**Step 3 — If any pre-existing screen broke** from the lowerer change (unlikely — existing single-return bodies still match the recognized grammar with zero leading declarations), inspect the diff and report. Do NOT paper over with hand edits to generated files; the grammar extension must be a strict superset of what was accepted before.

---

## Out of scope (deliberately)

- **Mutable `var` / `late` locals.** Diagnostic-rejected. Use a registered VM method if mutation is needed.
- **Split-declaration form** (`final a = 1, b = 2;`). Diagnostic-rejected. Authors use two statements.
- **Locals inside lambda bodies.** Lands with `LambdaNode` (Feature 2 of the bucket 1+2 roadmap).
- **Locals inside `if`/`switch` arms within block bodies.** The recognized grammar is `(VariableDecl)* Return`. Branching at the statement level remains rejected (`if` is only an expression in @Screen bodies).
- **Reassignment.** Lets are single-assignment by Map-spread construction.

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
