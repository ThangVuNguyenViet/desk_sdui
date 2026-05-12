# desk_sdui — `IrStatefulNode` (cross-build local state)

**Goal:** Let screen bodies own simple mutable state without a separate ViewModel class. Declare `var counter = 0;` at the screen-body root; bump it from an event handler; rebuild observes the new value.

**Dependencies:** Features 8 (mutable env) + 9 (BlockNode) must be merged.

**Architecture (load-bearing):**
- New IR node `IrStatefulNode { fields, body }` containing field declarations and the build body.
- New IR node `IrStatefulFieldNode { name, initializer, isFinal }` per declared field.
- Runtime emits a generated `StatefulWidget` + `State<>` per `@Screen` that declares root-level mutable fields. State owns a `Map<String, _Cell>` of field cells, initialized once in `initState`.
- `build()` resolves the screen's body against the cell map merged with VM inputs.
- Event-handler mutations to those cells persist across builds. The State calls `setState` after each event handler completes so Flutter rebuilds.

**Tech stack:** existing IR + 2 new nodes, generator emits Stateful wrapper, lowerer recognizes root-level field declarations.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: codec files.

**Step 1 — Define the nodes:**

```dart
/// A screen whose body owns mutable cross-build state. Generated as a
/// StatefulWidget + State<>. Fields are initialized once in initState;
/// every subsequent build resolves `body` against an env that includes
/// the field cells.
final class IrStatefulNode extends IrNode {
  const IrStatefulNode({required this.fields, required this.body});
  final List<IrStatefulFieldNode> fields;
  final IrNode body;
}

final class IrStatefulFieldNode extends IrNode {
  const IrStatefulFieldNode({
    required this.name,
    required this.initializer,
    required this.isFinal,
  });
  final String name;
  final IrNode initializer;
  final bool isFinal;
}
```

**Step 2 — Codec:** `'stateful'` payload `{fields, body}`; `'statefulField'` payload `{name, initializer, isFinal}`.

**Step 3 — Verify + commit.**

---

## Task 2 — Resolver: nothing changes at the eval layer

`IrStatefulNode` is a screen-level wrapper consumed by the per-screen Widget builder, NOT by `evalExpression`. The resolver never sees it as a sub-expression. The state cells live in the generated `State<>` and are merged into env at the call site.

**Step 1 — Add a small helper** in `expression_eval.dart` for "merge cells into an env":

```dart
Map<String, _Cell> mergeStateCells(
  Map<String, _Cell> base,
  Map<String, _Cell> stateCells,
) {
  return {...base, ...stateCells}; // state shadows inputs of same name
}
```

(Trivial — could be inlined at the call site.)

**Step 2 — Commit.**

---

## Task 3 — Generator: emit StatefulWidget + State<> wrapper

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/screen_generator.dart` (or wherever per-screen Widget classes are emitted).

**Step 1 — Detect IrStatefulNode at the screen top.** When the lowerer produces an `IrStatefulNode` (per Task 4 below), the generator emits a different shape than the existing stateless screen:

```dart
class _SduiHomeWidget extends StatefulWidget {
  const _SduiHomeWidget({required this.runtime, required this.inputs, super.key});
  final Runtime runtime;
  final Map<String, Object?> inputs;

  @override
  State<_SduiHomeWidget> createState() => _SduiHomeWidgetState();
}

class _SduiHomeWidgetState extends State<_SduiHomeWidget> {
  late final Map<String, _Cell> _stateCells;

  @override
  void initState() {
    super.initState();
    _stateCells = {};
    // For each field in IrStatefulNode.fields:
    final initEnv = _toEnv(widget.inputs);
    // Evaluate initializer in env that already has previously-initialized fields.
    // Field initializers in declaration order:
    _stateCells['counter'] = _Cell(evalExpression(<initializer node>, initEnv, widget.runtime));
    // ...
  }

  @override
  Widget build(BuildContext context) {
    final env = {
      ..._toEnv(widget.inputs),
      ..._stateCells, // state shadows inputs of the same name
    };
    return resolveScreen(<IrStatefulNode.body>, env, widget.runtime);
  }
}
```

`_toEnv(Map<String, Object?>)` is the `package:desk_sdui/src/cell.dart` helper from Feature 8.

**Step 2 — setState after event handlers.** Mutations from `ActionSequenceNode` / inline event handlers happen *outside* `build`. The State must call `setState(() {})` after each event handler completes to schedule a rebuild.

The cleanest hook: wrap the resolved event-handler closure. The resolver, when resolving an event-slot expression (e.g. an `ActionSequenceNode`), receives the env. The generated State wraps each handler:

```dart
// In a method called from build, before passing the resolved widget tree to Flutter:
Widget _resolveBody(env) {
  return _withSetStateOnEvents(resolveScreen(body, env, runtime));
}
```

But that's invasive (walking the resolved widget tree to wrap callbacks). Simpler approach: change the resolver's `ActionSequenceNode` case to take an optional `onComplete` callback that the generated State provides, defaulting to no-op for stateless screens:

```dart
// In Runtime or a per-screen builder:
void Function()? statefulOnComplete; // set by State<>; null in stateless screens

case ActionSequenceNode(:final steps):
  return () async {
    var localEnv = input;
    for (final step in steps) {
      // ... existing step logic ...
    }
    statefulOnComplete?.call();
  };
```

The State sets `statefulOnComplete = () => setState(() {})` at build time (captured into a local before passing to the resolver) so each handler completion triggers rebuild.

**Cleanest API:** add a per-resolve `RuntimeContext` parameter that carries this hook + the widget's `BuildContext` (which we already need for `context.push(...)`). Refactor the resolver entry to accept a context object; default in non-stateful paths is `RuntimeContext.empty()`.

**Step 3 — Sync event handlers.** Inline sync handlers (`onPressed: () { counter++; }`) lower to a `LambdaNode` (sync, no body statements other than expression-statements — actually wait, statements aren't a Feature 2 LambdaNode allowance). For Feature 11, EXTEND LambdaNode to accept sync block bodies that contain statement-form code (assignments, if/else). Tag with `isAsync: false, hasBlockBody: true`. The resolver evaluates the block via `executeStatement`. The State wraps the result the same way.

Implementation note: this is a small extension to LambdaNode, not a new node. If the lowerer sees a sync block body with assignments, it lowers to `LambdaNode(params, BlockNode([...]), isAsync: false)`. The resolver, when the body is a BlockNode, dispatches via `executeStatement` and threads `setState` via `statefulOnComplete`.

**Step 4 — Verify by building a counter demo and observing setState ticks** (Task 5).

**Step 5 — Commit.**

---

## Task 4 — Lowerer: recognize root-level fields

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`.

**Step 1 — Walk the @Screen body's top-level statements.** Today the LetNode-aware lowerer recognizes `(VariableDecl)* Return` at the top of a block body. Extend to recognize a leading run of declarations as **stateful fields** if any of them is `var` (mutable), or if a marker annotation is present (deferred).

Pseudocode:

```dart
IrNode lowerScreenBody(BlockFunctionBody body) {
  final stmts = body.block.statements;
  final fields = <IrStatefulFieldNode>[];
  var i = 0;
  while (i < stmts.length && _isFieldDecl(stmts[i])) {
    final decl = stmts[i] as VariableDeclarationStatement;
    final v = decl.variables.variables.single;
    fields.add(IrStatefulFieldNode(
      name: v.name.lexeme,
      initializer: lowerExpression(v.initializer!),
      isFinal: decl.variables.isFinal,
    ));
    i++;
  }
  final bodyStmts = stmts.skip(i).map(lowerStatement).toList();
  final bodyNode = bodyStmts.length == 1
      ? bodyStmts.single
      : BlockNode(statements: bodyStmts);
  if (fields.isEmpty) {
    return bodyNode; // stateless; existing path.
  }
  return IrStatefulNode(fields: fields, body: bodyNode);
}

bool _isFieldDecl(Statement s) =>
    s is VariableDeclarationStatement &&
    s.variables.variables.length == 1 &&
    s.variables.variables.single.initializer != null;
```

**Note on `final` root-level decls.** With Feature 1's LetNode, top-level `final t = vm.title` lowered to LetNode-wrapping-the-rest. That semantic — "re-compute on every build" — is sometimes wanted (memoization-free derived values). With Feature 11, all root-level decls become `IrStatefulField`. To preserve LetNode for read-only derivation, distinguish:
- `final x = vm.title;` → lowers to LetNode (derived per-build).
- `var x = 0;` → lowers to IrStatefulField (cross-build state).
- `final x = computeOnce();` where `computeOnce` is expensive → author wants memoization → use `var` instead, even though they don't mutate.

So the rule is purely syntactic: `var` → field; `final` → LetNode. This is the simplest discriminator and matches the way Flutter authors think about state lifecycle.

**Step 2 — Field initializers reference earlier fields.** Within `initState`, fields initialize in declaration order. The generator emits them in that order; each initializer evaluates against an env that contains previously-initialized fields. Document this in the generated comment.

**Step 3 — Verify + commit.**

---

## Task 5 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_demo/lib/screens/stateful_counter_demo.dart`
- Create: `packages/desk_sdui_generator/test/stateful_node_lowering_test.dart`

**Step 1 — Lowerer tests:**
1. `var counter = 0; return Text('$counter');` lowers to IrStatefulNode with one field, body is a ReturnNode wrapping a string-interp expression.
2. `var a = 0; var b = a + 1; return ...;` lowers to two fields; second's initializer references first.
3. `final t = vm.title; return Text(t);` lowers to LetNode (NOT IrStatefulNode) — `final` keeps the per-build semantic.
4. Mixed: `final t = vm.title; var x = 0; return Text('$t $x');` — top `final` is LetNode-wrapped; `var` is a field. Order matters: the LetNode wraps the IrStatefulNode wraps the rest. Verify the lowered tree shape.

Actually #4 is ambiguous: should `final t` ALSO be a field (since fields come first per the lowerer rule)? Decision: **leading runs of `var` decls are fields; ANY `final` between them or after breaks the field run.** So `final t = ...; var x = 0;` → `t` is a LetNode, `x` is a normal local (NOT a stateful field). This preserves the "fields come at the top of the screen" mental model. Document this rule.

**Step 2 — Demo (the canonical no-VM counter):**

```dart
@Screen('stateful_counter_demo')
Widget statefulCounterDemo() {
  var count = 0;
  return Scaffold(
    body: Center(child: Text('Count: $count', style: const TextStyle(fontSize: 32))),
    floatingActionButton: FloatingActionButton(
      onPressed: () { count = count + 1; },
      child: const Icon(Icons.add),
    ),
  );
}
```

Verify:
- Generated code includes a StatefulWidget + State<> wrapper for this screen.
- Tapping the FAB increments and rebuilds.

**Step 3 — Marionette integration test** (if Marionette is set up for this demo): tap FAB N times, expect Text shows `Count: N`. If not set up, skip — the lowerer + generator behavior is the main acceptance criterion.

**Step 4 — Commit.**

---

## Task 6 — Full-suite verification

(Standard.)

---

## Out of scope

- **`initState`/`dispose` lifecycle hooks.** No way to register cleanup from payload code. If anyone needs it, register a VM.
- **AnimationController ownership.** Established pattern is "host owns AnimationController, exposes `Animation<double>` as reactive listenable" — that's a VM concern, not IrStatefulNode.
- **GlobalKey / FocusNode ownership.** Same — VM-side.
- **Reactive listening to signals from payload state.** Cells are not signals. If you need to listen to a signal, the VM exposes it; payload reads `vm.signal.value` and the existing reactive-binding path triggers rebuilds.
- **Persisting state across hot-reload or process restart.** State is in-memory only.
- **Cross-screen state.** Each `@Screen` instance gets its own State<>. Sharing state across screens is a VM concern.

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
