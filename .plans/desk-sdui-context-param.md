# desk_sdui — `BuildContext context` as a `@Screen` parameter

**Goal:** Allow `@Screen` functions to declare a `BuildContext context` parameter so the body can call `Theme.of(context)`, `MediaQuery.sizeOf(context)`, `Navigator.of(context)`, etc. The runtime auto-supplies the live `BuildContext` (the host does NOT pass it via `inputs`). Inherited-widget dependency tracking works automatically because the call happens inside `SduiScreen.build`.

**Why opt-in, not ambient:** Declaring the parameter explicitly avoids the false-friend trap. Without a declared `context` parameter, `Theme.of(context)` fails at build time with "unknown reference". With it, the full context API is uniformly reachable.

**Prereqs:** `vm-callable` merged (needs the unified callable registry and static-method emission on registered classes).

**Acceptance:**

1. A `@Screen` with `BuildContext context` as a parameter:
   - Lowerer recognizes the parameter by **type** (not name; author may call it `ctx`).
   - Lowerer does NOT add it to the user-input contract — host doesn't pass it.
   - Generated `ScreenBinding` has `wantsContext: true`.
2. Runtime `_composeInput` injects `'context': context` (from `SduiScreen.build`'s `BuildContext`) when `binding.wantsContext` is true. Otherwise unchanged.
3. `Theme.of(context)` in a screen body lowers to a call to the `'Theme.of'` registry entry with `arg0` = `RefNode(['context'])`. Runs without errors when `Theme` is registered.
4. Static methods accepting `BuildContext` on registered classes (e.g. `Theme.of`, `MediaQuery.sizeOf`, `Navigator.of`) emit as flat registry entries via the existing static-methods branch from vm-callable.
5. Demo: a new `themed_counter` screen renders the counter with `Theme.of(context).colorScheme.primary` and `.textTheme.headlineLarge`. Tap +/-, counter updates. Toggle theme, screen reflects new theme without manual rebuild.
6. Build-time diagnostic: a screen body references `context` without a `BuildContext` parameter → fail with a clear message.

---

## Task 1 — Lowerer: recognize `BuildContext` parameter

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/screen_lowerer.dart` (or wherever screen parameters are walked)

Locate the parameter walker that builds the input contract for a `@Screen` function. For each parameter:

```dart
// Pseudocode:
if (param.type.isExactlyType(BuildContext)) {
  wantsContext = true;
  // Do NOT add to userInputs / input contract.
  // The parameter name (typically 'context') is reserved as a reactive input key,
  // injected by the runtime at materialization time.
  contextParamName = param.name;  // usually 'context'; preserve actual name
  continue;
}
// ... existing logic for non-context params (becomes a reactive input).
```

`BuildContext` is in `package:flutter/widgets.dart`. Use the existing `TypeChecker` pattern (e.g. `_buildContextChecker = TypeChecker.typeNamed(BuildContext, inPackage: 'flutter')`).

The parameter's **name** is what the body references (`RefNode([name])`). If the author wrote `BuildContext ctx`, the lowerer treats `ctx` as the reserved key; runtime injects `'ctx': context`. Keep this consistent.

---

## Task 2 — Emitter: surface `wantsContext` on `ScreenBinding`

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/ir_emitter_dart.dart`

Add `wantsContext: bool` and `contextParamName: String` (default `'context'` if not present) to the emitted `ScreenBinding`. Example:

```dart
ScreenBinding(
  name: 'themed_counter',
  wantsContext: true,
  contextParamName: 'context',
  inputs: const ['vm'],
  methodRefs: const {'vm': ['increment', 'decrement']},
  // ...
);
```

**File:** `packages/desk_sdui/lib/src/runtime.dart`

Update the `ScreenBinding` class accordingly. Default both fields for backward compat (existing bindings without context).

---

## Task 3 — Runtime: inject context in `_composeInput`

**File:** `packages/desk_sdui/lib/src/sdui_screen.dart`

```dart
Map<String, Object?> _composeInput(
  ScreenBinding? binding,
  Map<String, Object?> userInputs,
  BuildContext context,                  // NEW
) {
  final input = <String, Object?>{...userInputs};
  if (binding?.wantsContext ?? false) {
    final key = binding!.contextParamName;  // typically 'context'
    input[key] = context;
  }
  // ... rest (methods composition + reactive composition) unchanged
}
```

Update the caller in `SduiScreen.build(BuildContext context)` to pass its `context` argument through to `_composeInput`.

---

## Task 4 — Static methods on registered classes: confirm emission path

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`

vm-callable's Task 1 added "all public instance methods of classes registered in `@Register([...])`". Confirm the same discovery walks **public static methods** that aren't constructors. If the existing functions branch already handles statics-on-classes, no work here. If not, extend the discovery to:

- Walk `class.methods` where `method.isStatic == true`.
- Keep public statics (name doesn't start with `_`).
- Emit as a flat entry: `'Theme.of': (args) => Theme.of(args['arg0'] as BuildContext)`.
- Cast based on the declared parameter type; `BuildContext` from `flutter/widgets.dart` is allowed.

Add a generator test fixture: `@Register([Theme])` → emitted output contains `rt.register('Theme.of', ...)`.

---

## Task 5 — Build-time diagnostic for undeclared `context`

**File:** `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`

If a screen body references a name that isn't a declared parameter or a known top-level (e.g. references `context` without a `BuildContext` param), produce:

```
Screen "themed_counter" references "context" but no BuildContext parameter is declared.
Add `BuildContext context` to the @Screen function's parameters.
```

The existing "unknown reference" path probably already fires; specialize the message when the name matches the reserved context name to point devs to the fix.

---

## Task 6 — Catalog: register `Theme`

**File:** `packages/desk_sdui_demo/lib/sdui_catalog.dart`

Add `Theme` to the catalog (alongside any other context-access types you want for the demo; `MediaQuery` and `Navigator` optional for this plan).

```dart
@Register([
  ...kCommonWidgets,
  ...kCommonMaterialWidgets,
  PageView,
  Cue, Act, CueMotion,
  CounterController,
  Theme,                  // <- new
])
library;
```

**Note on getters:** `Theme.of(context).colorScheme.primary` needs `ThemeData.colorScheme` and `ColorScheme.primary` getters in the registry. If the existing getter-walking pipeline already emits getters for registered types (or for types reached from the screen body), this works. If not, add minimal getter-emission for the access chains the demo uses. Out-of-scope to walk *all* getters on `ThemeData`/`ColorScheme` — emit only what's referenced.

---

## Task 7 — Demo screen

**File (new):** `packages/desk_sdui_demo/lib/screens/themed_counter.dart`

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_actions.dart' show CounterController;
import 'package:flutter/material.dart';

part 'themed_counter.sdui.g.dart';

@Screen('themed_counter')
Widget themedCounter(BuildContext context, CounterController vm) => Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${vm.value}',
              style: Theme.of(context).textTheme.headlineLarge,
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
      ),
    );
```

In the demo app, route to `themed_counter` and wire:

```dart
final vm = CounterController();
SduiScreen(
  name: 'themed_counter',
  runtime: runtime,
  inputs: {'vm': vm},          // NOTE: no 'context' key — runtime auto-supplies
);
```

Wrap the demo's `MaterialApp` with theme toggling (light/dark or a colored seed). Verify that toggling rebuilds `themed_counter` without manual subscription — Flutter's inherited-widget mechanism handles it because `Theme.of(context)` runs inside `SduiScreen.build`.

---

## Task 8 — Tests

**Generator tests** (`packages/desk_sdui_generator/test/`):

- `context_param_test.dart`: a `@Screen` with `BuildContext context` parameter → emitted binding has `wantsContext: true`, `inputs` does NOT contain `'context'`.
- `register_for_sdui_test.dart`: `@Register([Theme])` → emitted output contains `rt.register('Theme.of', ...)`.
- Diagnostic: screen references `context` without declaring it → fails with the specialized message.

**Runtime tests** (`packages/desk_sdui/test/`):

- `sdui_screen_test.dart`: a screen with `wantsContext: true` materializes with `context` auto-injected; a callable in the IR receives the live `BuildContext`.

---

## Task 9 — Verify

```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test
```

All green. Run the demo, navigate to `themed_counter`, tap +/-, toggle theme — counter updates and theme follows.

Inspect:
- `packages/desk_sdui_demo/lib/screens/themed_counter.sdui.g.dart` has `wantsContext: true`.
- `packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart` contains `rt.register('Theme.of', ...)`.

---

## Out of scope

- Builder-style widgets (`Builder`, `LayoutBuilder`, `OrientationBuilder`) — body is a closure, SDUI can't lower closures. Inherent limit.
- `Navigator.of(context).push(MaterialPageRoute(builder: ...))` — closure problem again. Use `Navigator.pushNamed(context, '/route')` instead.
- Full getter-walking on `ThemeData`/`ColorScheme`/`TextTheme`/`MediaQueryData`. Emit only what demo references.
- Storing `context` in VM fields — Flutter forbids this in general; SDUI inherits the same rule. No new enforcement.
- Renaming the auto-supplied input key. Reserved key is whatever the author named the parameter (usually `context`).
