# desk_sdui — Feature 16: Payload class declarations + constructor invocation

**Goal:** Lower `class Order { String id; double total; Order(this.id, this.total); }` declared in a `@Screen` file to a `PayloadClassNode`. Lower `Order('x', 9.99)` to `PayloadInstanceCreationNode`.

**Dependencies:** Feature 15 (PayloadClass descriptors). Feature 12 (PayloadFunctionNode used for methods).

**Architecture:** New IR nodes for class shape + ctor invocation. Lowerer recognizes top-level `ClassDeclaration`. Codegen emits `rt.registerPayloadClass(...)` in the setup file. Resolver dispatches ctor invocation to allocate `PayloadInstance`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — IR nodes

**File:** `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart` + codec.

```dart
final class PayloadClassNode extends IrNode {
  const PayloadClassNode({
    required this.name,
    this.supertypeName,
    this.mixinNames = const [],
    required this.fields,
    required this.ctors,
    required this.methods,
  });
  final String name;
  final String? supertypeName;
  final List<String> mixinNames;
  final List<PayloadFieldDeclNode> fields;
  final List<PayloadCtorNode> ctors;
  final List<PayloadFunctionNode> methods;
}

final class PayloadFieldDeclNode extends IrNode {
  const PayloadFieldDeclNode({required this.name, this.initializer, required this.isFinal});
  final String name;
  final IrNode? initializer;
  final bool isFinal;
}

final class PayloadCtorNode extends IrNode {
  const PayloadCtorNode({required this.name, required this.params, required this.fieldInits, this.body});
  final String name;                              // '' for default
  final List<String> params;
  final List<PayloadFieldInitNode> fieldInits;    // `this.x` + initializer-list `: x = expr`
  final IrNode? body;                             // BlockNode (Feature 9)
}

final class PayloadFieldInitNode extends IrNode {
  const PayloadFieldInitNode({required this.fieldName, required this.value});
  final String fieldName;
  final IrNode value;
}

final class PayloadInstanceCreationNode extends ExpressionNode {
  const PayloadInstanceCreationNode({required this.className, this.ctorName = '', required this.args});
  final String className;
  final String ctorName;
  final Map<String, IrNode> args;
}
```

Codec tags: `'payloadClass'`, `'payloadField'`, `'payloadCtor'`, `'payloadFieldInit'`, `'payloadInstanceCreate'`.

---

## Task 2 — Resolver: ctor invocation

**File:** `packages/desk_sdui/lib/src/expression_eval.dart`.

```dart
case PayloadInstanceCreationNode(:final className, :final ctorName, :final args):
  final cls = runtime.payloadClasses[className];
  if (cls == null) throw StateError('No payload class "$className"');
  // 1. Allocate field cells with initializers (declaration order).
  final fields = <String, _Cell>{};
  for (final f in cls.fieldInitializers.entries) {
    fields[f.key] = _Cell(evalExpression(f.value, env, runtime));
  }
  // 2. Apply ctor: bind args to params, run field inits, run body.
  final ctor = _findCtor(cls, ctorName);
  final calleeEnv = <String, _Cell>{};
  // Bind args by name (or position — match Dart's calling convention).
  for (var i = 0; i < ctor.params.length; i++) {
    calleeEnv[ctor.params[i]] = _Cell(_evalArg(args, ctor.params[i], i, env, runtime));
  }
  // Apply `this.x` and initializer-list field inits.
  for (final init in ctor.fieldInits) {
    fields[init.fieldName] = _Cell(evalExpression(init.value, calleeEnv, runtime));
  }
  // Run ctor body if present (`this` bound to the in-progress instance).
  if (ctor.body != null) {
    final instance = PayloadInstance(type: cls, fields: fields);
    final bodyEnv = {...calleeEnv, 'this': _Cell(instance)};
    executeStatement(ctor.body!, bodyEnv, runtime);
  }
  return PayloadInstance(type: cls, fields: fields);
```

---

## Task 3 — Lowerer: ClassDeclaration → PayloadClassNode

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart`.

Walk the compilation unit; for each `ClassDeclaration`:
- Reject `abstract`, `sealed`, `interface` modifiers with diagnostic.
- Reject `extends` of a non-payload, non-Object type.
- Collect fields (`FieldDeclaration` members) → `PayloadFieldDeclNode`. Reject `static` fields.
- Collect constructors → `PayloadCtorNode`. Reject `factory`, `const`, redirecting ctors.
- Collect methods (`MethodDeclaration`) → `PayloadFunctionNode` (via Feature 12 path).
- Lower `with` clause → `mixinNames` (matched to declared `MixinDeclaration`s — Feature 20).

The screen-file IR is wrapped: if any class declarations exist, the compilation unit's IR becomes:

```dart
ScreenWithClassesNode {
  List<PayloadClassNode> classes;
  List<PayloadFunctionNode> functions; // from Feature 12
  IrNode screenBody;
}
```

(Subsumes Feature 12's `ScreenWithFunctionsNode` — extend that node to also carry classes, OR introduce a sibling that wraps both.)

---

## Task 4 — Codegen: emit registerPayloadClass

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`.

For each `PayloadClassNode`, emit a Dart literal that constructs the `PayloadClass` runtime descriptor + calls `rt.registerPayloadClass(...)`. The IR node maps directly to the runtime struct.

```dart
rt.registerPayloadClass(PayloadClass(
  name: 'Order',
  fieldInitializers: {
    'id': /* IR for initializer */,
    'total': /* IR */,
  },
  methods: {
    'applyDiscount': /* PayloadFunctionNode */,
  },
  ctorParams: ['id', 'total'],
  ctorBody: null, // or BlockNode IR
));
```

The mro is computed at runtime in `registerPayloadClass`; codegen doesn't precompute it.

---

## Task 5 — Tests + demo

Lowerer tests (5 cases): minimal class, class with named ctors, reject abstract/sealed, reject factory ctor, reject static field.

Resolver tests: instantiate via PayloadInstanceCreationNode, verify field values, named ctor selection, ctor body executes (using a registered side-effect method).

Demo: `class Money { final int cents; const Money(this.cents); }` (drop the `const` — payload classes can't be const; rephrase as `Money(this.cents);`). Use in a screen.

---

## Out of scope

- factory ctors, redirecting ctors, const ctors, abstract / sealed classes.
- Class-level annotations.
- Initializer-list assertions (`Order(this.id) : assert(id.isNotEmpty);`).

---

## Verify commands

(Standard 4-package suite.)
