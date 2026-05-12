# desk_sdui — Payload function declarations

**Goal:** Let authors define `List<Widget> visibleChips(List<Item> items) { ... }` inside a screen file and call it from `@Screen` bodies. Function bodies can use statements (Features 8-10). Call sites are still allowlist-checked: every leaf call inside the body must resolve to another payload function or a registered method/widget/value-ctor.

**Dependencies:** Features 1 (LetNode), 8 (mutable env), 9 (BlockNode), 10 (statement loops) must be merged. Optional but synergistic: Feature 2 (LambdaNode) for passing payload fns into collection ops.

**Architecture (load-bearing):**
- Per-screen-file local function table at codegen time. Functions are payload-private — never registered globally via `@Register`.
- New IR node `PayloadFunctionNode { name, params, body }` and `PayloadFunctionCallNode { name, args }`.
- Resolver dispatches `PayloadFunctionCallNode` by looking up the function in a per-resolve "local function scope" that the screen sets up before invoking the body.
- **Allowlist invariant:** the lowerer walks each function body recursively, checking that every leaf call goes to either another payload function in the same file OR a registered global. Anything else is a codegen-time error.
- Recursion is allowed; cost classifier (Feature 13) emits diagnostics for free recursion vs size-decreasing recursion.

**Tech stack:** existing IR + 2 new nodes, lowerer extension (function-decl recognition + allowlist walk), resolver extension (local function table threading).

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes + local function table

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the nodes:**

```dart
/// A payload-private function declaration. Lives in a per-file local
/// function table; never registered globally. Call sites use
/// PayloadFunctionCallNode.
final class PayloadFunctionNode extends IrNode {
  const PayloadFunctionNode({
    required this.name,
    required this.params,
    required this.body,
  });
  final String name;
  final List<String> params;
  final IrNode body; // BlockNode or expression
}

final class PayloadFunctionCallNode extends ExpressionNode {
  const PayloadFunctionCallNode({required this.name, required this.args});
  final String name;
  final List<IrNode> args;
}
```

**Step 2 — Container shape.** A `.sdui.g.dart` file emits both the @Screen body IR and the payload function table. Add an IR-level wrapper:

```dart
final class ScreenWithFunctionsNode extends IrNode {
  const ScreenWithFunctionsNode({required this.functions, required this.screenBody});
  final List<PayloadFunctionNode> functions;
  final IrNode screenBody; // IrStatefulNode, BlockNode, or expression
}
```

This is what the screen's `Binding` carries when payload functions are present. The runtime entry sets up the function table from `functions` before resolving `screenBody`.

**Step 3 — Codec:** tags `'payloadFn'`, `'payloadFnCall'`, `'screenWithFunctions'`. Standard payloads.

**Step 4 — Verify + commit.**

---

## Task 2 — Runtime: local function table

**Files:**
- Modify: `packages/desk_sdui/lib/src/runtime.dart` — add an optional "current function table" slot.
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` — dispatch `PayloadFunctionCallNode`.

**Step 1 — Function table.** A per-resolve scope (NOT a global on Runtime — payload functions are file-local, not app-global). The cleanest approach: thread a `Map<String, PayloadFunctionNode>` alongside the env. The simplest refactor that doesn't touch every existing IR node: piggyback on the `RuntimeContext` from Feature 11 (or introduce it here if Feature 11 didn't):

```dart
class RuntimeContext {
  RuntimeContext({this.payloadFunctions = const {}, this.statefulOnComplete});
  final Map<String, PayloadFunctionNode> payloadFunctions;
  final void Function()? statefulOnComplete;
}
```

If Feature 11 already defined RuntimeContext, extend it. Otherwise this plan introduces it.

The resolver entry takes a `RuntimeContext` (default `RuntimeContext()`). Recursive `evalExpression` calls pass it through.

**Step 2 — `PayloadFunctionCallNode` case in the resolver:**

```dart
case PayloadFunctionCallNode(:final name, :final args):
  final fn = ctx.payloadFunctions[name];
  if (fn == null) {
    throw StateError('PayloadFunctionCallNode: no function "$name" in scope '
        '(lowerer bug — allowlist walk should have rejected this call).');
  }
  // Evaluate args in caller's env.
  final argValues = args.map((a) => evalExpression(a, env, runtime, ctx)).toList();
  // Build callee env: only params are visible (no closure capture; payload
  // functions are top-level, not nested closures).
  final calleeEnv = <String, _Cell>{};
  for (var i = 0; i < fn.params.length; i++) {
    calleeEnv[fn.params[i]] = _Cell(argValues[i]);
  }
  // Execute body. If body is a BlockNode (statement-form), use executeStatement
  // and unwrap FlowReturn. If body is an expression, evaluate directly.
  if (fn.body is BlockNode) {
    final flow = executeStatement(fn.body, calleeEnv, runtime, ctx);
    if (flow is FlowReturn) return flow.value;
    return null; // body completed without explicit return — null result
  }
  return evalExpression(fn.body, calleeEnv, runtime, ctx);
```

**Step 3 — Entry point.** Per-screen runtime entry that sees `ScreenWithFunctionsNode` builds the function table:

```dart
Object? resolveScreen(IrNode node, Map<String, _Cell> env, Runtime rt) {
  if (node is ScreenWithFunctionsNode) {
    final ctx = RuntimeContext(
      payloadFunctions: {for (final fn in node.functions) fn.name: fn},
    );
    return evalExpression(node.screenBody, env, rt, ctx);
  }
  return evalExpression(node, env, rt, RuntimeContext());
}
```

**Step 4 — Verify + commit.**

---

## Task 3 — Lowerer: recognize function declarations

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`.

**Step 1 — Walk the screen file's top-level declarations.** The analyzer's `CompilationUnit.declarations` includes the @Screen function plus any other top-level functions. Today, non-@Screen functions are ignored. Change: collect them as payload function candidates.

```dart
final payloadFns = <PayloadFunctionNode>[];
for (final decl in unit.declarations) {
  if (decl is FunctionDeclaration) {
    if (_isScreenAnnotated(decl)) continue; // the @Screen entry point
    payloadFns.add(_lowerPayloadFunctionDecl(decl));
  }
  // Class declarations, etc. — ignored or rejected (existing path).
}
```

**Step 2 — Lower each function declaration:**

```dart
PayloadFunctionNode _lowerPayloadFunctionDecl(FunctionDeclaration decl) {
  final fn = decl.functionExpression;
  final params = fn.parameters?.parameters
          .map((p) => _simpleParamName(p))
          .toList() ??
      const [];
  final body = fn.body;
  final IrNode lowered;
  if (body is ExpressionFunctionBody) {
    lowered = lowerExpression(body.expression);
  } else if (body is BlockFunctionBody) {
    lowered = BlockNode(
      statements: body.block.statements.map(lowerStatement).toList(),
    );
  } else {
    throw InvalidScreenBodyError(
      'Payload functions must have an expression or block body. '
      'Got: ${body.runtimeType}',
    );
  }
  return PayloadFunctionNode(
    name: decl.name.lexeme,
    params: params,
    body: lowered,
  );
}
```

Reject async function declarations (`Future<X> foo() async { ... }`) with a diagnostic — payload functions are sync only. Use an action handler if async is needed.

**Step 3 — Lower call sites.** When lowering an expression, detect calls whose target is a top-level function declared in the same file:

```dart
if (expr is MethodInvocation && expr.target == null) {
  final name = expr.methodName.name;
  if (_payloadFnNames.contains(name)) {
    return PayloadFunctionCallNode(
      name: name,
      args: expr.argumentList.arguments.map(lowerExpression).toList(),
    );
  }
  // Otherwise, existing dispatch (registered method, builtin, etc.)
}
```

`_payloadFnNames` is populated by the pre-walk in Step 1.

**Step 4 — Allowlist invariant walk.** After lowering all function bodies, recursively walk each `PayloadFunctionNode.body` ensuring every leaf call resolves to either:
- Another payload function in `_payloadFnNames`, OR
- A registered global (look up in the codegen's catalog of registered methods/widgets/value-ctors).

If a leaf call doesn't match, emit a diagnostic pointing at the call site:

```
Payload function "buildList" calls "compute" which is neither a registered global
nor another payload function in this file. Payload functions can only compose
already-registered behavior.
```

**Step 5 — Wrap the @Screen body** in `ScreenWithFunctionsNode` if any payload function was found:

```dart
final screenBody = _lowerScreenBody(screenDecl);
final ir = payloadFns.isEmpty
    ? screenBody
    : ScreenWithFunctionsNode(functions: payloadFns, screenBody: screenBody);
```

**Step 6 — Verify + commit.**

---

## Task 4 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_generator/test/payload_function_lowering_test.dart`
- Create: `packages/desk_sdui/test/payload_function_eval_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/payload_fn_demo.dart`

**Step 1 — Lowerer tests:**
1. A top-level function declaration alongside @Screen lowers to a PayloadFunctionNode.
2. The @Screen body calling that function lowers to a PayloadFunctionCallNode (not a registered-method call).
3. Function body using `var`, `if`, `for`, `return` (Features 8-10) lowers correctly.
4. A function body that calls another payload function in the same file: nested PayloadFunctionCallNode.
5. Recursive function: function body calls itself. Lowers; classifier (Feature 13) hooks for warning.
6. Reject: payload function body calls `unregisteredHelper()` that's neither registered nor another payload fn.
7. Reject: payload function declared `async`.

**Step 2 — Resolver tests:**
1. Payload function with two int params returning their sum, invoked from a synthesized `PayloadFunctionCallNode`, returns the sum.
2. Payload function with a mutable loop accumulator (`var s = 0; for (...) s += x; return s;`) returns the correct sum.
3. Recursive function (`int fact(int n) { if (n <= 1) return 1; return n * fact(n-1); }`) computes factorial.
4. Payload function calls another payload function; nested calls work.
5. Args evaluate in caller's env; callee env only has params (no closure capture from caller's locals).

**Step 3 — Demo:**

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'payload_fn_demo.sdui.g.dart';

class PayloadFnController {
  final List<String> items;
  PayloadFnController({required this.items});
}

String describe(int count) {
  if (count == 0) return 'No items';
  if (count == 1) return '1 item';
  return '$count items';
}

@Screen('payload_fn_demo')
Widget payloadFnDemo(PayloadFnController vm) {
  return Text(describe(vm.items.length));
}
```

Regenerate and verify:
- `.sdui.g.dart` contains a `PayloadFunctionNode` named `describe`.
- The screen body's `Text(...)` arg lowers to a `PayloadFunctionCallNode(name: 'describe', args: [<length>])`.
- Rendering the screen with items length 0 / 1 / 5 displays the corresponding string.

**Step 4 — Commit.**

---

## Task 5 — Full-suite verification

(Standard.)

---

## Out of scope

- **Generic payload functions.** Like ctor generics, type args are erased. `List<Widget> chips<T>(...)` strips the `<T>`.
- **Function types as values.** Passing a payload fn as `Function`/`int Function(int)` etc. is not supported. Use `LambdaNode` for that.
- **Async payload functions.** Rejected. Use an action handler.
- **Mutual recursion safety.** Allowlist walk doesn't detect infinite mutual recursion (A calls B calls A); runtime stack overflow is the user-facing failure. Cost classifier (Feature 13) flags free recursion as a warning.
- **Closure capture across declarations.** Each function gets only its params; no outer-scope capture (which would be ambiguous in a top-level file context anyway).
- **Top-level constants.** `const kThreshold = 5;` is NOT lowered by this plan — it's a static-language construct. If needed, register it via `@Register`.

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
