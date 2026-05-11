# desk_sdui — `context` as a first-class reserved input

**Goal:** Make `BuildContext context` a first-class, always-available reactive input to `@Screen` bodies. The runtime unconditionally injects the live `BuildContext` (from `SduiScreen.build`) under the reserved key `'context'`. Authors who declare `BuildContext context` in their `@Screen` signature get to call `Theme.of(context)`, `MediaQuery.sizeOf(context)`, `Navigator.of(context)`, etc. Authors who don't declare it pay nothing — the key sits unused in the input map.

**Why first-class instead of opt-in:** A `wantsContext` flag, generated `contextParamName`, and lowerer type-detection add three moving parts to save one host-side `Builder` wrapper. Cheaper to reserve the key and inject unconditionally.

**Prereqs:** `vm-callable` merged (needs static-method emission on registered classes so `Theme.of` etc. become callables).

**Acceptance:**

1. Runtime `_composeInput` unconditionally injects `'context': context` into every screen's materialization input map. Host-supplied `'context'` (if any) overrides.
2. Author writes `@Screen Widget x(BuildContext context, VM vm) => Theme.of(context)...` — host passes `inputs: {'vm': vm}` only.
3. `Theme.of(context).colorScheme.primary` resolves end-to-end when `Theme` is registered (and the access chain getters are reachable via the existing pipeline).
4. Demo: `themed_counter` screen with theme-aware background and text style. Toggling the app theme rebuilds the screen via Flutter's inherited-widget mechanism (no manual subscription).
5. Screen author with `BuildContext context` declared but no matching expressions in the body → standard "unused input" lint behavior (if any); no new diagnostic required.

---

## Task 1 — Runtime: unconditional context injection

**File:** `packages/desk_sdui/lib/src/sdui_screen.dart`

Locate `_composeInput`. Thread the live `BuildContext` from `SduiScreen.build` through:

```dart
@override
Widget build(BuildContext context) {
  // ... existing setup
  final input = _composeInput(binding, widget.inputs, context);  // <- pass context
  // ...
}

Map<String, Object?> _composeInput(
  ScreenBinding? binding,
  Map<String, Object?> userInputs,
  BuildContext context,                       // <- new param
) {
  final input = <String, Object?>{
    'context': context,                       // <- reserved key, always injected
    ...userInputs,                            // host can override (escape hatch)
  };

  // ... existing methods-composition and reactive-composition unchanged
  return input;
}
```

That's the entire runtime change. No `ScreenBinding` field, no lowerer change.

---

## Task 2 — Catalog: register `Theme`

**File:** `packages/desk_sdui_demo/lib/sdui_catalog.dart`

Add `Theme` to the demo catalog:

```dart
@Register([
  ...kCommonWidgets,
  ...kCommonMaterialWidgets,
  PageView,
  Cue, Act, CueMotion,
  CounterController,
  Theme,                                      // <- new
])
library;
```

vm-callable's static-methods emission generates `'Theme.of'`. If getter-walking on the returned `ThemeData` is needed for `.colorScheme.primary` etc. and isn't already automatic, emit on-demand from the screen body's reachability walk (no full type registration).

---

## Task 3 — Demo screen

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

Demo app wiring:

```dart
final vm = CounterController();
SduiScreen(name: 'themed_counter', runtime: runtime, inputs: {'vm': vm});
// host does NOT pass 'context' — runtime injects it
```

Add a theme toggle to the demo's `MaterialApp` (e.g. light/dark switch). Confirm tapping the toggle rebuilds `themed_counter` automatically.

---

## Task 4 — Tests

**File:** `packages/desk_sdui/test/sdui_screen_test.dart` (or wherever runtime tests live)

- A screen with `EventNode`/`CallNode` referencing `'context'` materializes successfully, receives the live `BuildContext`.
- Host-supplied `'context'` in `inputs` overrides the auto-injected one (escape hatch).

**File:** `packages/desk_sdui_generator/test/register_for_sdui_test.dart`

- `@Register([Theme])` → emitted output contains `rt.register('Theme.of', ...)`. (May already exist if vm-callable's test covers it; skip if redundant.)

---

## Task 5 — Verify

```
cd packages/desk_sdui && dart analyze && dart test
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && dart analyze && flutter test
```

All green. Launch the demo, route to `themed_counter`, tap +/-, toggle theme — counter increments, theme follows.

---

## Out of scope

- Builder-style widgets (`Builder`, `LayoutBuilder`, `OrientationBuilder`). Closure bodies, not lowerable. Inherent SDUI limit.
- `Navigator.of(context).push(MaterialPageRoute(builder: …))`. Closure problem. Use `pushNamed`.
- Reserving alternative names — the key is `'context'`, period. Authors can name the parameter `context` only.
- Comprehensive getter-walking on `ThemeData`/`ColorScheme`/`TextTheme`. Emit only what demo references via existing reachability.
- Diagnostic for "wrote `Theme.of(context)` but didn't declare the parameter" — existing "unknown reference" path already handles it; no specialization.
