# SDUI ValueNotifier State Management — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace imperative `setState` callbacks with `ValueNotifier<Counter>` so that button presses update the UI correctly.

**Architecture:** `CounterActions` holds `ValueNotifier<Counter>` and calls `_notifier.value = c` after mutations. `DemoApp` wraps `SduiScreen` in `ValueListenableBuilder`. The framework's `registerPayloadClass` is made idempotent to survive rebuilds.

**Tech Stack:** Flutter, desk_sdui, desk_sdui_generator, fdb

---

## Task 1: Make Payload Registration Idempotent

**Files:**
- Modify: `packages/desk_sdui/lib/src/runtime.dart:131-137`
- Modify: `packages/desk_sdui/lib/src/runtime.dart:142-148`

**Context:** When `SduiScreen` rebuilds (triggered by `ValueListenableBuilder`), it re-resolves the IR tree and re-registers the `Counter` payload class. The current code throws `StateError` on duplicate registration.

- [ ] **Step 1: Make `registerPayloadClass` idempotent**

```dart
void registerPayloadClass(PayloadClass cls) {
  if (_payloadClasses.containsKey(cls.name)) {
    return;
  }
  _payloadClasses[cls.name] = cls;
  cls.methodLookupOrder = _computeMro(cls);
}
```

- [ ] **Step 2: Make `registerPayloadMixin` idempotent**

```dart
void registerPayloadMixin(String name, PayloadClass mixin) {
  if (_payloadClasses.containsKey(name)) {
    return;
  }
  _payloadClasses[name] = mixin;
  mixin.methodLookupOrder = [mixin];
}
```

- [ ] **Step 3: Verify no compilation errors**

Run: `cd packages/desk_sdui && dart analyze`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add packages/desk_sdui/lib/src/runtime.dart
git commit -m "fix: make payload registration idempotent for rebuilds"
```

---

## Task 2: Remove kNotifyChangedKey from SduiScreen

**Files:**
- Modify: `packages/desk_sdui/lib/src/sdui_screen.dart`
- Modify: `packages/desk_sdui/lib/src/cell.dart`

**Context:** With `ValueListenableBuilder` driving rebuilds externally, `SduiScreen` no longer needs the internal rebuild hook.

- [ ] **Step 1: Remove `kNotifyChangedKey` from cell.dart**

Edit `packages/desk_sdui/lib/src/cell.dart` and remove:
```dart
const String kNotifyChangedKey = r'__notifyChanged__';
```

- [ ] **Step 2: Simplify SduiScreen**

Replace the entire contents of `packages/desk_sdui/lib/src/sdui_screen.dart` with:

```dart
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/widgets.dart';

import 'resolve.dart';
import 'runtime.dart';

class SduiScreen extends StatefulWidget {
  const SduiScreen({
    required this.runtime,
    required this.name,
    this.inputs = const {},
    super.key,
  });

  final Runtime runtime;
  final String name;
  final Map<String, Object?> inputs;

  @override
  State<SduiScreen> createState() => _SduiScreenState();
}

class _SduiScreenState extends State<SduiScreen> {
  late Future<IrTree> _ir;

  @override
  void initState() {
    super.initState();
    _ir = widget.runtime.load(widget.name);
  }

  @override
  void didUpdateWidget(SduiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.runtime != widget.runtime) {
      _ir = widget.runtime.load(widget.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IrTree>(
      future: _ir,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return widget.runtime.errorBuilder?.call(ctx, snap.error!) ??
              ErrorWidget(snap.error!);
        }
        if (!snap.hasData) {
          return widget.runtime.loadingBuilder?.call(ctx) ??
              const SizedBox.shrink();
        }
        final binding = widget.runtime.screenFor(widget.name);
        final input = _composeInput(binding, widget.inputs, context);
        return resolveNode(
          ctx,
          snap.data!.root,
          input,
          widget.runtime,
        );
      },
    );
  }

  Map<String, Object?> _composeInput(
    ScreenBinding? binding,
    Map<String, Object?> userInputs,
    BuildContext context,
  ) {
    final input = <String, Object?>{
      'context': context,
      ...userInputs,
    };
    if (binding != null) {
      final methods = <String, Function>{};
      for (final entry in userInputs.entries) {
        final value = entry.value;
        if (value == null) continue;
        final typeName = value.runtimeType.toString();
        for (final methodName in binding.referencedMethodsFor(entry.key)) {
          final fn = widget.runtime.callableFor('$typeName.$methodName');
          if (fn == null) continue;
          methods['${entry.key}.$methodName'] =
              () => fn({r'$this': value});
        }
      }
      input['__methods__'] = methods;

      final reactives = <String, Listenable>{};
      for (final r in binding.reactives) {
        reactives[r.path.join('.')] = r.read(userInputs);
      }
      input['__reactive__'] = reactives;
    }
    return input;
  }
}
```

- [ ] **Step 3: Remove kNotifyChangedKey references from resolve.dart**

In `packages/desk_sdui/lib/src/resolve.dart`, search for all occurrences of `kNotifyChangedKey` and remove:

1. Remove the wrapper around `EventNode` (lines 559-569 approximately):
```dart
    case EventNode():
      return _bindEvent(node, input, runtime, ctx: ctx);
```

2. Remove the wrapper around `ActionSequenceNode` (lines 571-579 approximately):
```dart
    case ActionSequenceNode(:final steps):
      return () async {
        var localEnv = toEnv(input);
        for (final step in steps) {
          localEnv = await _runActionStep(step, localEnv, runtime, ctx: ctx);
        }
      };
```

3. Remove any remaining `kNotifyChangedKey` references.

- [ ] **Step 4: Verify no compilation errors**

Run: `cd packages/desk_sdui && dart analyze`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add packages/desk_sdui/lib/src/runtime.dart packages/desk_sdui/lib/src/sdui_screen.dart packages/desk_sdui/lib/src/resolve.dart packages/desk_sdui/lib/src/cell.dart
git commit -m "refactor: remove kNotifyChangedKey, let external state management drive rebuilds"
```

---

## Task 3: Update CounterActions to Use ValueNotifier

**Files:**
- Modify: `packages/desk_sdui_demo/lib/screens/counter_demo.dart`

**Context:** `CounterActions` needs to hold a `ValueNotifier<Counter>` and re-assign to it after mutations to trigger `ValueListenableBuilder`.

- [ ] **Step 1: Update CounterActions constructor and _notify method**

Edit `packages/desk_sdui_demo/lib/screens/counter_demo.dart` and replace the `CounterActions` class with:

```dart
/// Actions class exercising async patterns and stateful operations.
class CounterActions {
  final ValueNotifier<Counter> _notifier;

  CounterActions(this._notifier);

  void _notify() {
    _notifier.value = _notifier.value;
  }

  Future<void> save(Counter c) async {
    c.busy = true;
    _notify();
    await Future.delayed(const Duration(milliseconds: 100));
    c.busy = false;
    _notify();
  }

  void reset(Counter c) {
    c.count = 0;
    c.step = 1;
    c.history = [];
    c.mode = 'add';
    _notify();
  }

  void incrementCount(Counter c) {
    c.count = c.count + 1;
    _notify();
  }

  void setMode(Counter c, String m) {
    c.mode = m;
    _notify();
  }

  void setStep(Counter c, int s) {
    c.step = s;
    _notify();
  }

  void decrementCount(Counter c) {
    c.count = c.count - c.step;
    _notify();
  }

  void handleSaveError(Counter c) {
    c.mode = 'error';
    _notify();
  }
}
```

- [ ] **Step 2: Add ValueNotifier import**

At the top of `counter_demo.dart`, add:
```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 3: Verify no compilation errors**

Run: `cd packages/desk_sdui_demo && flutter analyze`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add packages/desk_sdui_demo/lib/screens/counter_demo.dart
git commit -m "feat: make CounterActions drive ValueNotifier for state updates"
```

---

## Task 4: Update DemoApp to Use ValueNotifier

**Files:**
- Modify: `packages/desk_sdui_demo/lib/main.dart`

**Context:** `DemoApp` must create `ValueNotifier<Counter>`, pass it to `CounterActions`, and wrap `SduiScreen` in `ValueListenableBuilder`.

- [ ] **Step 1: Replace DemoApp contents**

Replace the entire contents of `packages/desk_sdui_demo/lib/main.dart` with:

```dart
import 'dart:io' show ProcessInfo;

import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:desk_sdui_demo/screens/counter_demo.dart';
import 'package:fdb_helper/fdb_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  if (!kReleaseMode) {
    FdbBinding.ensureInitialized();
  }
  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;
  late final ValueNotifier<Counter> _counter;
  late final CounterActions _actions;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    rt = Runtime();

    final rssBefore = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    registerAllScreens(rt);
    sw.stop();
    final rssAfter = ProcessInfo.currentRss;
    debugPrint('[sdui-probe] registerAllScreens: '
        '${sw.elapsedMicroseconds} µs, '
        'RSS delta ${(rssAfter - rssBefore) ~/ 1024} KB '
        '(before ${rssBefore ~/ 1024} KB, after ${rssAfter ~/ 1024} KB)');

    _counter = ValueNotifier(Counter());
    _actions = CounterActions(_counter);
  }

  void _toggleTheme() => setState(() => _darkMode = !_darkMode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'desk_sdui — counter',
      theme: ThemeData(
        useMaterial3: true,
        brightness: _darkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('desk_sdui — counter'),
          actions: [
            IconButton(
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: ValueListenableBuilder<Counter>(
          valueListenable: _counter,
          builder: (context, counter, _) {
            return SduiScreen(
              runtime: rt,
              name: 'counter_demo',
              inputs: {'c': counter, 'a': _actions},
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no compilation errors**

Run: `cd packages/desk_sdui_demo && flutter analyze`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add packages/desk_sdui_demo/lib/main.dart
git commit -m "feat: wrap SduiScreen in ValueListenableBuilder for observable state"
```

---

## Task 5: Regenerate Generated Code

**Files:**
- Modify: `packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart`
- Modify: `packages/desk_sdui_demo/lib/screens/counter_demo.sdui.g.dart`
- Modify: `packages/desk_sdui_demo/lib/screens/counter_demo.sdui_reg.g.dart`

**Context:** The code generator needs to regenerate the IR tree and registration code to match the updated `CounterActions` constructor signature.

- [ ] **Step 1: Run build_runner**

```bash
cd packages/desk_sdui_demo
flutter pub run build_runner build -d
```

Expected output: `Built with build_runner/aot in Xs; wrote Y outputs.`

- [ ] **Step 2: Verify CounterActions registration**

Open `packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart` and confirm:
```dart
rt.registerValueBuilder('CounterActions', (args) => CounterActions(args['arg0'] as ValueNotifier<Counter>));
```

- [ ] **Step 3: Commit**

```bash
git add packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart packages/desk_sdui_demo/lib/screens/counter_demo.sdui.g.dart packages/desk_sdui_demo/lib/screens/counter_demo.sdui_reg.g.dart
git commit -m "chore: regenerate code for ValueNotifier state management"
```

---

## Task 6: Verify with fdb

**Files:** None (integration test)

- [ ] **Step 1: Kill any running app**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir packages/desk_sdui_demo/.fdb kill
```

- [ ] **Step 2: Launch app via fdb**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
cd packages/desk_sdui_demo
fdb launch --device macos --project .
```

Wait for `APP_STARTED`.

- [ ] **Step 3: Verify initial state**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb describe
```

Expected visible text: `"0"`

- [ ] **Step 4: Tap increment button**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb tap @2
```

- [ ] **Step 5: Verify counter updated**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb describe
```

Expected visible text: `"1"` (and NOT `"0"`)

- [ ] **Step 6: Tap decrement button**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb tap @1
```

- [ ] **Step 7: Verify counter decremented**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb describe
```

Expected visible text: `"0"`

- [ ] **Step 8: Multiple taps**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb tap @2
fdb --session-dir .fdb tap @2
fdb --session-dir .fdb tap @2
```

- [ ] **Step 9: Verify final count**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb describe
```

Expected visible text: `"3"`

- [ ] **Step 10: Kill app**

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
fdb --session-dir .fdb kill
```

---

## Task 7: Clean Up Debug Prints

**Files:**
- Modify: `packages/desk_sdui/lib/src/resolve.dart`
- Modify: `packages/desk_sdui/lib/src/sdui_screen.dart`

**Context:** Remove all `[sdui-debug]` print statements added during debugging.

- [ ] **Step 1: Remove debug prints from resolve.dart**

Search for `debugPrint('[sdui-debug]` in `packages/desk_sdui/lib/src/resolve.dart` and remove all occurrences.

- [ ] **Step 2: Remove debug prints from sdui_screen.dart**

Search for `debugPrint('[sdui-debug]` in `packages/desk_sdui/lib/src/sdui_screen.dart` and remove all occurrences.

- [ ] **Step 3: Verify no compilation errors**

Run: `cd packages/desk_sdui && dart analyze`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add packages/desk_sdui/lib/src/resolve.dart packages/desk_sdui/lib/src/sdui_screen.dart
git commit -m "chore: remove debug print statements"
```

---

## Task 8: Run Test Suite

**Files:** None (verification)

- [ ] **Step 1: Run desk_sdui tests**

```bash
cd packages/desk_sdui
flutter test
```

Expected: All tests pass

- [ ] **Step 2: Run desk_sdui_generator tests**

```bash
cd packages/desk_sdui_generator
dart test
```

Expected: All tests pass

- [ ] **Step 3: Commit if tests pass**

```bash
git commit --allow-empty -m "test: verify all tests pass after ValueNotifier refactor"
```

---

## Spec Coverage Check

| Spec Requirement | Task |
|---|---|
| Make `registerPayloadClass` idempotent | Task 1 |
| Remove `kNotifyChangedKey` from framework | Task 2 |
| `CounterActions` accepts `ValueNotifier<Counter>` | Task 3 |
| DemoApp uses `ValueListenableBuilder` | Task 4 |
| Regenerate code | Task 5 |
| fdb integration works | Task 6 |
| Clean debug prints | Task 7 |
| Tests pass | Task 8 |

## Placeholder Scan

- ✅ No TBD/TODO
- ✅ No vague "handle edge cases"
- ✅ Complete code in every step
- ✅ Exact file paths
- ✅ Exact commands with expected output
