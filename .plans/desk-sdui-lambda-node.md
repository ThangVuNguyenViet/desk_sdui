# desk_sdui — LambdaNode (closures in screen bodies)

**Goal:** Support `(p) => expr` and `(p) { return expr; }` shapes inside `@Screen` bodies, primarily for use in collection methods (`.where`, `.map`, `.fold`). Today these force a hoist-to-VM-method refactor for any per-element transformation.

**Dependencies:**
- **`LetNode` (Feature 1)** must be merged — LambdaNode re-uses the env extension shape (`{...env, paramName: arg}`).
- **`ActionSequenceNode` (Feature 4)** must be merged — LambdaNode's `inActionContext` gate piggybacks on the flag introduced by Task 3 of that plan.

**Architecture (load-bearing):**
- New `LambdaNode { params, body, isAsync }` IR node.
- Resolver builds a native Dart `Function` that captures the env via Map spread. One-liner for sync; async variant returns `Future`.
- Lowerer recognizes `FunctionExpression` whose body is a single expression (or block with single ReturnStatement). Rejects local-variable declarations inside the body (LetNode-inside-lambda is a future combination).
- **Context gate:** `isAsync == true` is ALLOWED only when `inActionContext == true` (set inside `ActionSequenceNode` step lowering). Otherwise rejected with a diagnostic. This prevents async lambdas from leaking into per-frame paths (signal/build/widget args) while permitting `await items.whereAsync((x) async => ...)` inside an `onPressed` handler.

**Tech stack:** existing IR + new node, existing resolver, existing lowerer with context flag.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR node

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files (encoder + decoder).

**Step 1 — Define the node:**

```dart
/// Synthesizes a Dart `Function` at resolve time. Captures the current env
/// (Map<String, Object?>) and produces a callable that, when invoked, extends
/// the captured env with the call-site param values and resolves `body`.
final class LambdaNode extends ExpressionNode {
  const LambdaNode({
    required this.params,
    required this.body,
    this.isAsync = false,
  });
  final List<String> params;
  final IrNode body;
  final bool isAsync;

  @override
  bool operator ==(Object other) =>
      other is LambdaNode &&
      _listEq(other.params, params) &&
      other.body == body &&
      other.isAsync == isAsync;
  @override
  int get hashCode => Object.hash(Object.hashAll(params), body, isAsync);
  @override
  String toString() =>
      'LambdaNode(${isAsync ? "async " : ""}(${params.join(", ")}) => $body)';
}
```

**Step 2 — Codec:** `'lambda'` tag, payload `{params, body, isAsync}`. Mirror existing patterns.

**Step 3 — Verify + commit.**

```
cd packages/desk_sdui_annotation && dart analyze && dart test
git commit -am "feat(ir): add LambdaNode (sync + async)"
```

---

## Task 2 — Resolver synthesizes the closure

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart`

**Step 1 — Add the case.** The closure captures `input` (the env) by reference; each invocation extends it with the param bindings:

```dart
case LambdaNode(:final params, :final body, :final isAsync):
  if (!isAsync) {
    if (params.length == 1) {
      return (Object? a0) =>
          evalExpression(body, {...input, params[0]: a0}, runtime);
    }
    if (params.length == 2) {
      return (Object? a0, Object? a1) => evalExpression(
            body,
            {...input, params[0]: a0, params[1]: a1},
            runtime,
          );
    }
    // 0-param and >2-param: emit a Function.apply-style fallback.
    return Function.apply(
      (List<Object?> args) {
        var env = input;
        for (var i = 0; i < params.length; i++) {
          env = {...env, params[i]: args[i]};
        }
        return evalExpression(body, env, runtime);
      },
      const [],
    );
  }
  // Async path: closures return Future<Object?>. Only valid in action context;
  // the lowerer already rejected production outside ActionSequenceNode bodies.
  if (params.length == 1) {
    return (Object? a0) async =>
        evalExpression(body, {...input, params[0]: a0}, runtime);
  }
  if (params.length == 2) {
    return (Object? a0, Object? a1) async => evalExpression(
          body,
          {...input, params[0]: a0, params[1]: a1},
          runtime,
        );
  }
  throw StateError('LambdaNode: only 0-2 params supported');
```

**Note on async body:** the resolver itself is sync. An async lambda is allowed because its **invocation site** is async (an `ActionSequenceNode` step), not the build. The closure's body still resolves synchronously per call; the `async` keyword on the outer arrow only changes the *return type wrapping*. Authors who need `await` *inside* the lambda body (`(x) async => await vm.canShow(x)`) need a different shape — that's covered by `ActionStepNode`, not a lambda body. Reject `AwaitExpression` inside LambdaNode body in Task 3.

**Step 2 — Verify + commit.**

---

## Task 3 — Lowerer recognizes FunctionExpression

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart` (or wherever FunctionExpression is currently rejected — `grep -rn "FunctionExpression" packages/desk_sdui_generator/lib/src/`).

**Step 1 — Recognize the AST shape:**

```dart
if (expr is FunctionExpression) {
  return _lowerLambda(expr);
}
```

Where `_lowerLambda(expr)`:
1. Extract param names from `expr.parameters?.parameters`. Reject non-simple params (no default values, no `{named}`, no `[positional]`). Only `(a, b) => ...` style.
2. Body shapes:
   - `ExpressionFunctionBody` → lower its `.expression`.
   - `BlockFunctionBody` with a single `ReturnStatement` → lower its `.expression`.
   - Any other body → reject with diagnostic `LambdaNode bodies must be a single expression (or a block with a single return). Use ActionSequenceNode for async sequences.`
3. Check `body.isAsynchronous`. If true:
   - Verify `inActionContext == true`. If false, reject with diagnostic `Async lambdas are only allowed inside async event handlers (ActionSequenceNode bodies). At <location>, this lambda is being constructed in a per-frame path.`
4. Reject `AwaitExpression` nodes inside the body when not in action context. (Async lambdas in action context may carry `AwaitExpression` provided the lambda's invoker awaits the resulting Future — caller's responsibility.)
5. Emit `LambdaNode(params: [...], body: <lowered>, isAsync: body.isAsynchronous)`.

**Step 2 — Wire `inActionContext` through the lowerer.** The flag was introduced as a stub by the ActionSequenceNode plan (Task 3 Step 5). Promote it to a real read site here. Set true when entering `ActionSequenceNode` step lowering; clear when descending into `ConditionalNode`/`WidgetNode`/`ForNode` args (these are per-frame paths).

The cleanest plumbing: thread the flag through the lowerer's traversal as a field of an inherited context object, OR pass it as a function parameter to recursive lowering calls. Either works; pick the one that fits the existing lowerer's structure (read the file before deciding).

**Step 3 — Verify + commit.**

---

## Task 4 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_generator/test/lambda_node_lowering_test.dart`
- Create: `packages/desk_sdui/test/lambda_node_eval_test.dart`
- Modify: an existing demo screen OR create `lambda_demo.dart` exercising `.where`/`.map`.

**Step 1 — Lowerer tests:**
1. `(p) => p.startsWith('a')` lowers to `LambdaNode(params: ['p'], body: <call>, isAsync: false)`.
2. `(p, q) => p + q` lowers with two-param LambdaNode.
3. `(p) { return p * 2; }` lowers same as the arrow form.
4. Reject `(p) { final t = p; return t; }` (block body with leading let — diagnostic).
5. Reject `(p) async => await vm.canShow(p)` outside action context (diagnostic).
6. Accept `(p) async => await vm.canShow(p)` inside action context (verify by building an ActionSequenceNode whose step contains a call passing this lambda).

**Step 2 — Resolver tests:**
1. Sync 1-param lambda evaluated produces expected value.
2. Captured env: lambda referencing an outer let-bound name resolves it correctly.
3. Shadowing: lambda param shadowing outer name takes precedence inside body.
4. Async 1-param lambda evaluated produces `Future` (await it and check value).
5. `Iterable.where` registered, called with a LambdaNode, returns filtered list.

**Step 3 — Demo:** add a screen that calls `vm.items.where((x) => x.isNotEmpty).toList()` and renders the result. Requires `.where`, `.toList` registered in core-accessors (already in main per Feature 2 plan's accept list — verify with `grep "registerGetter\|registerMethod" packages/desk_sdui/lib/src/core_accessors.dart`).

If `.where` / `.map` / `.toList` are NOT yet registered, register them in `core_accessors.dart` as part of this plan — they're prerequisites for the demo to actually run.

**Step 4 — Regen + verify + commit.**

---

## Task 5 — Full-suite verification

(Same as other plans.)

---

## Out of scope

- Lambdas with local variables (`(p) { final t = ...; return ...; }`). Future: LetNode-inside-LambdaNode combination.
- Closures escaping the build (passed to async APIs that retain them past one resolve pass).
- Lambdas with default param values.
- Lambdas with named/optional positional params.
- Tear-off shorthand (`list.map(f.toUpperCase)` — these are MethodAccess, not FunctionExpression).
- Async lambdas referencing non-VM async (e.g., `Future.delayed` inline). Wrap such things in a VM method.

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
