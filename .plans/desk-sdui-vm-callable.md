# desk_sdui — unified callable registry + VM method dispatch

**Goal:** Make screen-driven VM method calls work end-to-end. Today the lowerer emits `EventNode(['vm', 'increment'])` for `onPressed: vm.increment`, the runtime correctly looks up `__methods__['vm.increment']`, and the screen-binding emitter wires `MethodBinding(name: 'vm.increment', invoke: () {})` — but `invoke` is an empty stub. No demo currently exercises it.

**Approach: collapse to one registry.** Stop treating "widget builders" / "value builders" / "method dispatch" as separate runtime mechanisms. Everything is a **named callable**, keyed by `"TypeName.MemberName"` (or just `"TypeName"` for the unnamed ctor), with an optional receiver passed via a reserved `$this` arg.

```dart
'Text'                        : (args) => Text(args['data'], style: args['style']),
'Color'                       : (args) => Color(args['arg0']),
'EdgeInsets.all'              : (args) => EdgeInsets.all(args['arg0']),
'MainAxisAlignment.center'    : (args) => MainAxisAlignment.center,
'Colors.red'                  : (args) => Colors.red,
'String.toUpperCase'          : (args) => (args[r'$this'] as String).toUpperCase(),
'CounterController.increment' : (args) => (args[r'$this'] as CounterController).increment(),
```

One annotation (`@Register`). One registry (`Map<String, Function>`). The IR node kind dictates what the runtime puts in `args` (including `$this` for methods).

**Prereq:** `catalog-rename` merged.

**Acceptance:**

1. `@Register([CounterController, ...])` causes the generator to emit `"CounterController.increment"` and `"CounterController.decrement"` entries in the unified registry.
2. A new `counter_actions` demo screen with working +/- buttons proves the path end-to-end.
3. The `MethodBinding(invoke: () {})` stub is removed from `_buildMethods` in `ir_emitter_dart.dart`; the generated binding no longer carries `MethodBinding` entries for VM methods.
4. `_composeInput` in `sdui_screen.dart` composes `__methods__` at materialization time by walking `inputs.entries` and looking up `"${input.runtimeType}.${methodName}"` for each method the screen references.
5. Build-time diagnostic: a screen references `vm.foo` where `vm`'s registered class has no `foo` method → fail with a clear error listing available methods.
6. Bundles (`kCommonWidgets`, `kCommonMaterialWidgets`, etc.) continue to handle widget/enum/value-type ergonomics. No transitive auto-discovery added.

---

## Task 1 — Generator: emit method entries for non-Widget registered classes

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`

Today's emitter already produces per-method entries for value types whose methods are reached by screen-body walks (the existing `collected.methods` loop emits `emitMethod(method, receiverType: ...)`). Extend the *source* of methods to include:

- **All public instance methods of classes registered in `@Register([...])`** — regardless of whether any current screen body references them. This is the new behavior: an explicit "I registered T" entry expands to all of T's methods, ready for IR-driven dispatch.

Discovery rules:
- Walk `class.methods` (analyzer 13 element API).
- Keep public methods (name doesn't start with `_`).
- Skip inherited `Object` members (`toString`, `hashCode`, `==`, `noSuchMethod`).
- Skip `dispose` if present (lifecycle, not callable).
- Skip getters/setters (only methods).
- Skip static methods (those are emitted as functions, not methods).

For each kept method, emit an entry shaped like:

```dart
rt.register('CounterController.increment', (args) {
  final receiver = args[r'$this'] as CounterController;
  return receiver.increment();
});
```

(The exact emitter helper signature stays close to the existing `emitMethod`; this plan doesn't refactor every emitter — only adds the new discovery path.)

**Not in scope here:** subscript (`operator[]`) — stays as today. Inherited methods — stay as today (only methods declared directly on T are exposed; if you want a parent's methods, register the parent).

---

## Task 2 — Runtime: unify the lookup, expose `register(name, fn)`

**File:** `packages/desk_sdui/lib/src/runtime.dart`

The runtime today has separate `registerWidget`, `registerValueBuilder`, `registerConstant`, `registerMethod`, `registerSubscript`, `registerFunction`. The plan is **NOT** to rip them all out — they're working and tested. Just add the unified entry point:

```dart
final Map<String, Function> _callables = {};

void register(String name, Function fn) {
  _callables[name] = fn;
}

Function? callableFor(String name) => _callables[name];
```

For now, leave the existing per-kind registers in place; have them also populate `_callables` under the hood (each one assigns into the same map with the same key shape). Future cleanup can collapse the API to just `register`.

The new method-binding wiring (Task 3) uses only `callableFor`. New code goes through the unified entry; old code keeps working unchanged.

---

## Task 3 — Runtime: compose `__methods__` from inputs at materialization time

**File:** `packages/desk_sdui/lib/src/sdui_screen.dart`

Replace `_composeInput`'s `binding.methods` loop with input-driven dispatch:

```dart
Map<String, Object?> _composeInput(
  ScreenBinding? binding,
  Map<String, Object?> userInputs,
) {
  final input = <String, Object?>{...userInputs};
  final methods = <String, Function>{};
  for (final entry in userInputs.entries) {
    final value = entry.value;
    if (value == null) continue;
    final typeName = value.runtimeType.toString();
    // For each method the screen references on this input slot, look up
    // "TypeName.MethodName" in the unified registry and bind the receiver.
    for (final methodName in binding?.referencedMethodsFor(entry.key) ?? const []) {
      final fn = widget.runtime.callableFor('$typeName.$methodName');
      if (fn == null) continue;
      methods['${entry.key}.$methodName'] = () => fn({r'$this': value});
    }
  }
  input['__methods__'] = methods;

  // ... reactives unchanged
  return input;
}
```

`binding.referencedMethodsFor(inputName)` is a new accessor that returns the method names the screen body references via `EventNode(['<inputName>', '<method>'])`. The generator already collects these (`methodRefs`) — expose them on the binding indexed by input name.

This entirely replaces the empty `MethodBinding(invoke: () {})` stub path.

---

## Task 4 — Generator: replace `methodRefs` emission with structured map

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/ir_emitter_dart.dart`

Today `_buildMethods` emits a `List<MethodBinding>` with empty invoke stubs. Change to emit a `Map<String, List<String>>` keyed by input name → method names referenced:

```dart
methodRefs: const {
  'vm': ['increment', 'decrement'],
},
```

Update `ScreenBinding`:
- Remove the `methods: List<MethodBinding>` field.
- Add `methodRefs: Map<String, List<String>>` field.
- Add `List<String> referencedMethodsFor(String inputName)` returning `methodRefs[inputName] ?? const []`.

Remove `MethodBinding` class from runtime.dart if nothing else uses it (check first; if anything reads it externally, deprecate gradually).

---

## Task 5 — Build-time diagnostic

**File:** `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`

Add a diagnostic parallel to today's widget diagnostic:

For each `@Screen` function:
- For each input parameter `(name, Type)`, collect the method names referenced via `EventNode([name, methodName])`.
- Check the registered set: is `Type` in any `@Register([...])`? If not, fail:

```
Screen "counter_actions" uses input "vm" of type CounterController but CounterController is not registered.
Add CounterController to a @Register list.
```

- For each referenced method, check if `"Type.methodName"` will be emitted (i.e. the discovery pass in Task 1 includes it). If not:

```
Screen "counter_actions" references method "vm.increment" but CounterController has no public method "increment".
Available methods on CounterController: decrement, reset.
```

---

## Task 6 — Demo: counter with working buttons

**File (new):** `packages/desk_sdui_demo/lib/screens/counter_actions.dart`

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'counter_actions.sdui.g.dart';

class CounterController extends ChangeNotifier {
  int _value = 0;
  int get value => _value;

  void increment() {
    _value++;
    notifyListeners();
  }

  void decrement() {
    _value--;
    notifyListeners();
  }
}

@Screen('counter_actions')
Widget counterActions(CounterController vm) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${vm.value}',
            style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(onPressed: vm.decrement, child: const Text('-')),
              const SizedBox(width: 16),
              ElevatedButton(onPressed: vm.increment, child: const Text('+')),
            ],
          ),
        ],
      ),
    );
```

Register `CounterController` in `sdui_catalog.dart`:

```dart
@Register([
  ...kCommonWidgets,
  ...kCommonMaterialWidgets,
  Cue, Act, CueMotion, PageView,
  CounterController,   // <- new; methods get registered automatically
])
library;
```

In the demo app, wire up:

```dart
final vm = CounterController();
return SduiScreen(
  name: 'counter_actions',
  runtime: runtime,
  inputs: {'vm': vm},
);
```

---

## Task 7 — Tests

**Generator tests:**

- `register_for_sdui_test.dart`: register a non-Widget class with methods, assert the emitted output contains entries like `rt.register('CounterController.increment', ...)`.
- `registration_diagnostic_test.dart`: screen references `vm.missing` → diagnostic fires with expected message; screen references `vm.increment` and `CounterController.increment` exists → diagnostic passes.

**Runtime tests:**

- `runtime_test.dart`: register a callable manually, look it up, invoke with `$this` arg, observe expected return / side effect.
- `sdui_screen_test.dart`: a screen with `EventNode(['vm', 'increment'])` and `inputs: {'vm': testController}` correctly invokes `testController.increment()` when the closure fires.

---

## Task 8 — Verify

```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && dart analyze
```

Inspect:
- `packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart` should contain `rt.register('CounterController.increment', ...)` and `rt.register('CounterController.decrement', ...)`.
- `packages/desk_sdui_demo/lib/screens/counter_actions.sdui.g.dart` should have `methodRefs: const {'vm': ['increment', 'decrement']}` (or whatever subset the screen actually references) and NO `methods: [...]` entries.

Run the demo, navigate to `counter_actions`, tap +/-, verify the counter updates with no runtime errors.

---

## Out of scope

- Per-method opt-out (`@SduiHidden`). YAGNI.
- Inheritance walking (methods on parent classes). Only methods declared on T directly.
- Generic VM classes (`MyController<T>`).
- Static methods on registered classes (those are emitted by the existing functions branch).
- Subscript operator (`operator[]`). Stays as today.
- Collapsing the existing per-kind `registerWidget`/`registerValueBuilder`/etc. APIs into a single `register`. That's downstream cleanup; this plan leaves them in place and just adds the unified `_callables` map under the hood.
- Method arguments. Today's `EventNode` already supports `args` map; the dispatch path forwards them. No new work.
