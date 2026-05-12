# desk_sdui — Generic type carriage in IR

**Goal:** Carry generic type arguments through the IR for ctor invocations where the runtime type matters (`List<MyType>()`, `Map<String, int>()`, `ValueNotifier<int>(0)`). Today generics are erased at the IR level, which causes runtime cast failures when a registered closure expects a typed container.

**Architecture (load-bearing):** Bucket 1 — no new runtime machinery. Extend IR node schemas to optionally carry type-argument names. Registered closures opt in to typeArgs awareness; existing closures keep working unchanged.

**Tech stack:** existing IR (`WidgetNode`, `ValueCtorNode`, `MethodCallNode`), lowerer, generator emitter.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Extend IR node schemas

**Files:**
- Modify: `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_encoder.dart`
- Modify: `packages/desk_sdui_annotation/lib/src/ir/codec/json_decoder.dart`

**Step 1 — Add optional `typeArgs` to three node types.** WidgetNode, ValueCtorNode, MethodCallNode each gain:

```dart
final List<String>? typeArgs;
```

Constructor signature gains `this.typeArgs,` as a named param with default `null`. Equality + hashCode + toString updated to include typeArgs when non-null.

**Important:** `typeArgs == null` is semantically distinct from `typeArgs == []`. `null` means "lowerer didn't see any type args" (legacy / non-generic ctor). `[]` would mean "explicit empty type list" — which is never emitted; treat as `null` if it appears.

**Step 2 — JSON codec:** when encoding, include `"typeArgs": [...]` field only if non-null. When decoding, read the field if present, default to null.

**Step 3 — Backwards compatibility check.** Existing generated `.sdui.g.dart` files use positional/named ctors without typeArgs. Adding `typeArgs` as a named param with default value preserves call-site compatibility — existing emitted code still compiles.

**Step 4 — Verify**

```
cd packages/desk_sdui_annotation && dart analyze && dart test
```

Round-trip tests must pass for both shapes (with and without typeArgs).

**Step 5 — Commit**

```
git commit -am "feat(ir): typeArgs on WidgetNode/ValueCtorNode/MethodCallNode"
```

---

## Task 2 — Resolver passes `__typeArgs__` to registered closures

**Files:**
- Modify: `packages/desk_sdui/lib/src/expression_eval.dart` (or wherever WidgetNode/ValueCtorNode/MethodCallNode args are assembled before invoking the registered closure).

**Step 1 — Identify the args-assembly sites.** For each of the three node types, the resolver builds a `Map<String, Object?>` of evaluated args and passes it to the registered closure. Find each call site (`grep -rn "registerWidget\|registerValueBuilder\|registerMethod\|invokeMethod" packages/desk_sdui/lib/src/`).

**Step 2 — Inject `__typeArgs__`:** at each site, after assembling the args map, if the node has non-null `typeArgs`:

```dart
if (node.typeArgs != null) {
  argsMap['__typeArgs__'] = node.typeArgs;
}
```

The key uses dunder prefix to avoid collision with any plausible user arg name.

**Step 3 — Document the convention.** Add a doc comment near `SduiWidgetBuilder` / `SduiValueBuilder` typedefs explaining:

```dart
/// If the IR ctor invocation carried generic type args (e.g. `List<MyType>()`),
/// they appear in `args` under the reserved key `__typeArgs__` as a
/// `List<String>` of simple type names. Type args are erased to simple names
/// (no library URIs, no nested generics). Builders that don't care about
/// generics may ignore this key.
```

**Step 4 — Verify**

```
cd packages/desk_sdui && dart analyze && dart test
```

Existing tests must pass — no behavior change for ctors without typeArgs.

**Step 5 — Commit**

```
git commit -am "feat(eval): pass __typeArgs__ key to registered closures"
```

---

## Task 3 — Lowerer captures type args from the AST

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart`
- Modify: any place where `WidgetNode` / `ValueCtorNode` / `MethodCallNode` are constructed.

**Step 1 — Find ctor lowering sites.** The lowerer translates `InstanceCreationExpression` (and similar) into a `WidgetNode` or `ValueCtorNode`. For each site, the analyzer AST node carries `typeArguments` (a `TypeArgumentList?`).

**Step 2 — Extract and lower.** When typeArguments is present:

```dart
final typeArgs = node.constructorName.type.typeArguments?.arguments
    .map((t) => _typeArgName(t))
    .toList();
```

Where `_typeArgName(TypeAnnotation t)`:
- If `t` is a `NamedType` with no nested args → return `t.name.lexeme` (simple name).
- If `t` is a `NamedType` with nested args → return `t.name.lexeme` (erase nested generics — bucket 1 doesn't carry them).
- If `t` is `void` / `dynamic` / `Never` → return that literal name as the string.
- If `t` is a function type / record type → throw a diagnostic. (Generic args of those forms aren't supported.)

**Step 3 — Same for `MethodCallNode`.** When lowering a method call with explicit type args (`vm.fetch<MyType>()`), capture them the same way.

**Step 4 — Pass to constructors:**

```dart
return WidgetNode(
  name: ctorName,
  args: args,
  typeArgs: typeArgs, // may be null
);
```

**Step 5 — Verify**

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

**Step 6 — Commit**

```
git commit -am "feat(codegen): lowerer captures explicit type args from AST"
```

---

## Task 4 — Emitter writes `typeArgs:` in generated `.sdui.g.dart`

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/screen_generator.dart` (or wherever the IR-to-Dart-source emitter lives).

**Step 1 — Emit the named param only when non-null.** In the per-node literal emitter:

```dart
if (node.typeArgs != null) {
  buffer.write(', typeArgs: ${_emitStringList(node.typeArgs!)}');
}
```

This keeps existing screens' regenerated output unchanged (no typeArgs → no field emitted).

**Step 2 — Verify** by regenerating the demo and diffing pre/post. Existing screens MUST regen identically (no `typeArgs:` lines added where they weren't before).

**Step 3 — Commit**

```
git commit -am "feat(codegen): emit typeArgs in generated IR literals"
```

---

## Task 5 — Codegen handles registered builders that consume typeArgs

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/registration_emitter.dart` (where `registerValueBuilder` calls are emitted).

**Step 1 — Identify generic ctors in the catalog.** When the type collector walks a registered class and finds a ctor with one-or-more type parameters, the emitted `registerValueBuilder` closure must handle typeArgs.

**Step 2 — Emit a switch-on-typeArg closure.** For a generic ctor like `List<T>` registered with subtypes `MyType`, `String`, `int`:

```dart
rt.registerValueBuilder('List', (args) {
  final typeArg = (args['__typeArgs__'] as List?)?.firstOrNull;
  switch (typeArg) {
    case 'MyType': return <MyType>[];
    case 'String': return <String>[];
    case 'int': return <int>[];
    case null: return <Object?>[];
    default:
      throw StateError('List<$typeArg>: typeArg not registered. '
          'Add MyType to the screen body or register manually.');
  }
});
```

**Step 3 — Where do subtype lists come from?** Two sources, in order:
1. **Auto-discovery** — extend `type_collector.dart` to walk type-arg usages: when a `@Screen` body references `List<MyType>()` or `ValueNotifier<int>(0)`, record `MyType` / `int` as a typeArg of `List` / `ValueNotifier`. Carry this back to the emitter as a `Map<String, Set<String>>` keyed by ctor simple-name.
2. **Author opt-in** — a new annotation `@RegisterGeneric<List, [MyType, String]>()` for cases the walker can't see. Skip implementing this annotation in this plan unless the auto-discovery path proves insufficient; document as follow-up.

**Step 4 — Curated whitelist of generic ctors.** Not every registered ctor needs the switch wrapper — only ones that appear with explicit type args in screen bodies. Build the whitelist from auto-discovery:

```
{
  'List': {'MyType', 'String', 'int', ...},
  'ValueNotifier': {'int', 'String', ...},
  ...
}
```

Emit the switch wrapper only for ctors in the whitelist.

**Step 5 — Verify** the demo regenerates with the new closures (if any generic ctors are used in current demos). If no demo uses generics today, this is just plumbing — verify via Task 6's targeted test.

**Step 6 — Commit**

```
git commit -am "feat(codegen): emit typeArgs-aware closures for generic ctors used in screens"
```

---

## Task 6 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_generator/test/generic_type_carriage_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/generic_demo.dart`

**Step 1 — Lowerer tests:**
1. `List<MyType>()` lowers to `ValueCtorNode(name: 'List', args: {}, typeArgs: ['MyType'])`.
2. `Map<String, int>()` lowers with `typeArgs: ['String', 'int']`.
3. `ValueNotifier<int>(0)` lowers as ValueCtorNode with typeArgs.
4. Non-generic ctor (`Padding(...)`) lowers with `typeArgs: null` (NOT `[]`).
5. Round-trip JSON codec preserves typeArgs (or null).

**Step 2 — Resolver test:** synthesize a node with typeArgs, register a builder that reads `args['__typeArgs__']`, verify it receives the list.

**Step 3 — End-to-end demo screen** (`generic_demo.dart`):

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'generic_demo.sdui.g.dart';

class GenericItem {
  const GenericItem({required this.label});
  final String label;
}

class GenericController {
  final List<GenericItem> items;
  GenericController({required this.items});
}

@Screen('generic_demo')
Widget genericDemo(GenericController vm) {
  return Column(
    children: [
      for (final item in vm.items) Text(item.label),
    ],
  );
}
```

(Note: this demo doesn't actually construct `List<GenericItem>` in the screen body — the list comes from the controller. A more direct typeArgs use case would be `Builder` patterns that construct typed containers in-line. Adapt as needed; the goal is to exercise *some* generic-ctor lowering path. If the demo uses `for-in` over `vm.items`, the generator may not surface a generic ctor; in that case skip the demo screen and rely on the unit tests in Step 1-2.)

**Step 4 — Verify** + commit.

---

## Task 7 — Full-suite verification

(Same as other plans.)

---

## Out of scope (deliberately)

- **Nested generics** (`List<Map<String, int>>`). Type-arg list captures only simple names of the outer-most args.
- **Type inference.** Only explicit type args in source. `var list = <MyType>[]` lowers without typeArgs unless the lowerer can pull from the inferred type — which it can, but capture only when the source has an explicit `<T>`.
- **Generic methods on user types.** Method type args are captured for `MethodCallNode` but the registered method must opt in to handling them. Default registered methods ignore `__typeArgs__`.
- **The `@RegisterGeneric` annotation.** Author opt-in registration; auto-discovery covers the common cases.

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
