# desk_sdui — Mutable env + `AssignNode`

**Goal:** Allow `int x = 0; x = x + 1;` in `@Screen` bodies and payload functions. Locals become mutable cells. Foundation for statement loops (Feature 10), payload functions with accumulators (Feature 12), and stateful screens (Feature 11).

**Dependencies:** `LetNode` (Feature 1) must be merged. This plan changes how LetNode allocates its binding (cell-backed instead of value-backed).

**Architecture (load-bearing):**
- Env type changes from `Map<String, Object?>` to `Map<String, _Cell>`, where `_Cell.value` is a mutable Dart field holding a native value (no `$Value` wrapping).
- `LetNode` allocates a fresh `_Cell(initialValue)`. Reads (`RefNode([name])`) dereference: `env[name]!.value`. Writes (`AssignNode`) mutate `env[name]!.value = newValue`.
- Existing `final` lowerings still allocate cells, but the lowerer marks them as write-locked (any AssignNode targeting a final-bound cell is a codegen error).
- All existing IR nodes that consume env are touched: `RefNode`, `EventNode`, `LambdaNode` capture, `ActionSequenceNode` step bindings.
- Per-read cost goes from "one hashmap get" to "one hashmap get + one field read" (~70 ns vs ~50 ns). Constant factor; additive, not multiplicative. Cost rule preserved.

**Tech stack:** existing IR + new node, all resolver nodes that touch env, lowerer's variable-binding tracking.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Introduce `_Cell` and migrate env type

**Files:**
- Create: `packages/desk_sdui/lib/src/cell.dart` (package-private).
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` — all env references.
- Modify: `packages/desk_sdui/lib/src/ref_resolver.dart` — dereference on read.
- Modify: callers of `evalExpression` that construct an env from outside (`SduiScreen`, runtime entry points).

**Step 1 — Define `_Cell`:**

```dart
/// Mutable single-value holder. Backs every variable binding in an
/// @Screen body / payload function. Holds a native Dart value — no
/// $Value boxing. `final` bindings allocate `_Cell` with `writable: false`;
/// AssignNode against a non-writable cell is a codegen-time error
/// (enforced in the lowerer; runtime trusts the codegen guarantee).
class _Cell {
  _Cell(this.value);
  Object? value;
}
```

Exported as `package:desk_sdui/src/cell.dart` but not from the public barrel — internal only.

**Step 2 — Migrate the env type.** Change `Map<String, Object?>` → `Map<String, _Cell>` everywhere in the resolver. This touches:
- `evalExpression(node, env, runtime)` signature.
- Every recursive call.
- `RefNode` lookup: `env[name]?.value` (was `env[name]`).
- `LetNode` extension: `{...env, name: _Cell(value)}` (was `{...env, name: value}`).
- `ActionSequenceNode` step bind: `_Cell(awaitedValue)`.
- `LambdaNode` env capture: captures the `Map<String, _Cell>` — note this means lambdas see *current* values of mutable bindings at call time, not values at lambda creation. This is the desired semantic for "natural Dart feel" (closures over mutables read live).

**Step 3 — External entry points.** `SduiScreen` and other consumers pass `Map<String, Object?>` as inputs. Build a small adapter that wraps each input in a `_Cell`:

```dart
Map<String, _Cell> _toEnv(Map<String, Object?> inputs) {
  return {for (final e in inputs.entries) e.key: _Cell(e.value)};
}
```

Apply once at the resolver entry point. Public API stays `Map<String, Object?>` — only the internal env is cells.

**Step 4 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

Expected: all existing tests pass — semantically identical for `final`-only code.

**Step 5 — Commit**

```
git commit -am "refactor(eval): env type Map<String, Object?> → Map<String, _Cell>"
```

---

## Task 2 — Add `AssignNode` to the IR

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the node:**

```dart
/// `name = value`. Mutates the cell bound at `name` in the current env.
/// Codegen guarantees `name` resolves to a writable cell (lowerer rejects
/// assignment against `final`-bound names).
final class AssignNode extends ExpressionNode {
  const AssignNode({required this.name, required this.value});
  final String name;
  final IrNode value;

  @override
  bool operator ==(Object other) =>
      other is AssignNode && other.name == name && other.value == value;
  @override
  int get hashCode => Object.hash(name, value);
  @override
  String toString() => 'AssignNode($name = $value)';
}
```

**Step 2 — Codec:** `'assign'` tag, payload `{name, value}`.

**Step 3 — Resolver case:**

```dart
case AssignNode(:final name, :final value):
  final cell = env[name];
  if (cell == null) {
    throw StateError('AssignNode: no binding for "$name" (lowerer bug — should have rejected)');
  }
  final v = evalExpression(value, env, runtime);
  cell.value = v;
  return v;
```

Assignment expressions return their RHS value in Dart. We do the same — this enables `final t = (x = 5);` shapes if anyone wants them.

**Step 4 — Verify + commit.**

---

## Task 3 — Lowerer: track writability, lower assignments

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`.

**Step 1 — Track variable kinds.** Extend the lowerer's binding-tracking to record per-name: `kind ∈ {final, var}`. Sources:
- `VariableDeclarationStatement(final ...)` → final
- `VariableDeclarationStatement(var ...)` → var (NEW: previously rejected)
- `VariableDeclarationStatement(<TypeAnnotation> ...)` with explicit type (e.g. `int x = 0`) → var (Dart's default mutability with explicit type)
- Lambda params, action step bind-results → var (callers may overwrite; rarely useful but consistent)

The tracking is per-scope. When entering a block (BlockNode or @Screen body), push a new scope frame. Lookups walk outwards.

**Step 2 — Recognize `var` / `int x = ...` declarations.** Today the LetNode-aware lowerer rejects non-`final` declarations (per Feature 1, Task 3 Step 2's diagnostic). Drop that rejection — accept both `final` and mutable forms. Both lower to `LetNode`; the difference is whether subsequent `AssignNode`s targeting that name are allowed.

**Step 3 — Lower `AssignmentExpression`:**

```dart
if (expr is AssignmentExpression) {
  final lhs = expr.leftHandSide;
  if (lhs is SimpleIdentifier) {
    final name = lhs.name;
    final binding = _lookupBinding(name);
    if (binding == null) {
      throw InvalidScreenBodyError(
        'Assignment to "$name": no local binding visible at this site. '
        'Was the variable declared in an outer scope that does not reach here?',
      );
    }
    if (binding.kind == BindingKind.finalBinding) {
      throw InvalidScreenBodyError(
        'Cannot assign to final local "$name". Declare it with `var` or an explicit type.',
      );
    }
    return AssignNode(name: name, value: lowerExpression(expr.rightHandSide));
  }
  // Cascade-style or property assignment — handled by Cascades feature (Feature 7).
  throw InvalidScreenBodyError(
    'Only simple-identifier assignments (`x = expr`) are supported in screen bodies.',
  );
}
```

**Step 4 — Compound assignments.** `x += 5` lowers to `AssignNode('x', ArithOpNode('+', RefNode(['x']), LiteralNode(5)))`. Apply same for `-=`, `*=`, `/=`, `~/=`, `%=`. The existing ArithOpNode handles the binary op.

**Step 5 — Pre/post increment.** `x++` lowers to a sequence: read old value, assign new value, return old (post) or new (pre). Use `LetNode` to hoist the old value if anyone observes the result; usually the result is discarded (`x++;` as a statement), so a simple AssignNode is sufficient.

For statement-form (`x++;` as `ExpressionStatement`): `AssignNode('x', ArithOpNode('+', RefNode(['x']), LiteralNode(1)))`.

For expression-form where the result is consumed (`final t = x++;`): post-increment requires capturing the pre-value. Skip in this plan — emit a diagnostic `Pre/post increment as an expression is not supported. Use \`x++;\` as a statement, or \`x = x + 1; final t = x - 1;\` to capture the pre-value.` Add later if a real use case appears.

**Step 6 — Verify + commit.**

---

## Task 4 — Tests + demo

**Files:**
- Create: `packages/desk_sdui/test/assign_node_eval_test.dart`
- Create: `packages/desk_sdui_generator/test/assign_node_lowering_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/mutable_local_demo.dart`

**Step 1 — Resolver tests:**
1. `LetNode('x', LiteralNode(1), BlockNode([AssignNode('x', LiteralNode(2)), RefNode(['x'])]))` — but BlockNode is Feature 9; emulate via sequencing in tests.
   - Actually: in this plan, AssignNode lives inside expression contexts that already support sequencing — typically wrapped by a LetNode (which evaluates value first, then body). Simpler test: `evalExpression(AssignNode('x', 5), env)` against an env where `x: _Cell(1)` mutates `env['x'].value` to 5.
2. Assignment returns the RHS value.
3. Assignment to a non-existent name throws StateError (lowerer bug indicator).
4. Lambda captures a mutable binding; lambda invocation reads current value AFTER an external assignment.

**Step 2 — Lowerer tests:**
1. `var x = 0; x = x + 1; return x;` lowers to LetNode → SequenceNode-ish chain or directly to a sequence via BlockNode shim — depends on what's available. If BlockNode (Feature 9) isn't ready, the recognized body grammar is still `(VariableDecl)* Return`, so multi-statement bodies with assignments mid-stream aren't yet possible. **Note this gap in the plan** — full mutation flows require Feature 9. For this plan, the grammar accepts:
   ```
   var x = 0;
   final t = (x = x + 1);  // assignment-as-expression in a final init
   return Text('$t');
   ```
   That's a stretchy use case. The real value comes when Feature 9 lands. **Decision:** ship this plan with the diagnostic in place but only test the most narrow case (single `var` declaration, then assignment-as-expression in a final init), and add the multi-statement tests under Feature 9.

   Updated lowerer test cases:
   - `var x = 0; final t = (x = x + 1); return Text(t);` lowers to LetNode(x, 0, LetNode(t, AssignNode(x, +(x, 1)), Widget(...))).
   - `final y = 5; y = 6;` rejected with the documented diagnostic.
   - `x = 0;` without prior declaration rejected.

2. Compound assignment `x += 3` lowers as documented.
3. `x++` as expression-statement lowers as documented.
4. `final t = x++` rejected (post-increment-as-expression diagnostic).

**Step 3 — Demo screen.** Pure-mutation demos are hard without Feature 9. Skip the demo for this plan — it's covered when Feature 9 lands and adds BlockNode bodies. Note in the commit message that the full demo lives with Feature 9.

**Step 4 — Verify + commit.**

---

## Task 5 — Full-suite verification

(Standard.)

---

## Out of scope

- **Multi-statement mutation flows.** Need BlockNode (Feature 9).
- **Field assignment** (`vm.field = x`). Requires registered setters; lives with Cascades' setter dispatch.
- **Indexed assignment** (`list[i] = x`). Future.
- **Pre/post increment as expressions** — only as statements.
- **Initial-value type coercion.** `int x = 'string'` is a static-type bug; resolver doesn't check.

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
