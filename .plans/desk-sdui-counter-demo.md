# desk_sdui_demo — counter app with cue animation stress-test

**Goal:** Replace the chef screen entirely with an animation-rich counter app, authored as multiple pre-baked @Screen variants demonstrating cue. Each variant is selectable at runtime; one variant cranks the particle count high enough to stress-test the runtime. The point is to show that **animation can be authored in IR and rendered with no perf regression vs handwritten Flutter**.

**Architecture:**
- Each variant is a separate `@Screen` (`counter_minimal`, `counter_bouncy`, `counter_burst`, `counter_stress`). All four lower to IR at build time — no live codegen.
- Counter state lives in a host `ValueNotifier<int>` exposed through the screen `inputs` map; the screen reads the value and animates on change. (Matches existing memory pattern: host owns state, screen observes.)
- A UI shell with a `SegmentedButton` to pick the variant, a `+` / `-` / "burst x N" trio of buttons, and a stress-test counter that triggers M increments in K ms for the load test.
- The chef screen + its fixtures + `network_only_screen.dart` and tests stay (chef test still validates non-animation widget paths). Only `main.dart` flips its default away from chef.

**Tech stack:** Flutter web, `cue`, existing `desk_sdui` runtime, existing `desk_sdui_generator`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Preconditions:**
- `.plans/desk-sdui-analyzer-8.md` is merged (otherwise cue's dot-shorthand source crashes the generator).
- The two cue commits already on `main` (`47a7252` cue dep, `686c3cd` hero @Screen scratch) can stay — `hero.dart` will be deleted as part of Task 1 since the counter screens replace it.

**Acceptance:** `flutter run -d chrome --target lib/main.dart` opens to the counter app. All four variants render, animate without exceptions, and remain at 60fps on the stress variant for at least 5 seconds of sustained burst input on a typical dev machine.

---

## Task 1 — Clean slate

Delete the chef + hero scaffolding so the demo opens cleanly to the new app. The chef screen + fixtures + tests stay on disk (still valuable as a data-rich regression target); only the `main.dart` route changes.

**Files:**
- Delete: `packages/desk_sdui_demo/lib/screens/hero.dart`
- Delete (if present): `packages/desk_sdui_demo/lib/screens/hero.sdui.g.dart`, `hero.sdui_reg.g.dart`

**Step 1 — Delete hero**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
rm -f packages/desk_sdui_demo/lib/screens/hero.dart
rm -f packages/desk_sdui_demo/lib/screens/hero.sdui.g.dart
rm -f packages/desk_sdui_demo/lib/screens/hero.sdui_reg.g.dart
```

**Step 2 — Commit**

```
git add -A && git commit -m "chore(demo): remove hero scratch screen (replaced by counter app)"
```

---

## Task 2 — Variant 1: `counter_minimal`

A baseline counter — single digit, no animation. Establishes the value-binding pattern and acts as the perf reference.

**Files:**
- Create: `packages/desk_sdui_demo/lib/screens/counter_minimal.dart`

**Step 1 — Author**

```dart
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

class CounterData {
  const CounterData({required this.value});
  final int value;
}

@Screen('counter_minimal')
Widget counterMinimal(CounterData data) {
  return Center(
    child: Text(
      '${data.value}',
      style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
    ),
  );
}
```

**Step 2 — Verify**

```
cd packages/desk_sdui_demo && dart analyze lib/screens/counter_minimal.dart
```

Expected: clean.

**Step 3 — Commit** (after codegen runs in Task 5; defer for now)

---

## Task 3 — Variant 2: `counter_bouncy`

The increment scale-bounces the number with cue.

**Files:**
- Create: `packages/desk_sdui_demo/lib/screens/counter_bouncy.dart`

**Step 1 — Author.** Use fully qualified factory names — no dot-shorthand, to keep lowering boringly mechanical (even though analyzer-8 supports dot-shorthand, the IR is more readable without it).

```dart
import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'counter_minimal.dart' show CounterData;

@Screen('counter_bouncy')
Widget counterBouncy(CounterData data) {
  return Center(
    child: Cue.onChange(
      value: data.value,
      motion: CueMotion.springy(),
      acts: [
        Act.scale(from: 0.6, to: 1.0),
        Act.fadeIn(),
      ],
      child: Text(
        '${data.value}',
        style: const TextStyle(fontSize: 128, fontWeight: FontWeight.w900),
      ),
    ),
  );
}
```

**Step 2 — Verify** — `dart analyze lib/screens/counter_bouncy.dart` clean.

---

## Task 4 — Variants 3 + 4: `counter_burst` and `counter_stress`

`counter_burst` renders a configurable list of confetti chips, each animated with a staggered fade/slide. `counter_stress` cranks the chip count up to several hundred so you can watch frame timing.

**Files:**
- Create: `packages/desk_sdui_demo/lib/screens/counter_burst.dart`
- Create: `packages/desk_sdui_demo/lib/screens/counter_stress.dart`

**Step 1 — Extend `CounterData`** — add a `chips: List<int>` field so the host can vary chip count per variant. Edit `counter_minimal.dart`:

```dart
class CounterData {
  const CounterData({required this.value, this.chips = const []});
  final int value;
  final List<int> chips;
}
```

**Step 2 — Author `counter_burst.dart`** — small swarm of chips, each fades + slides with a per-chip offset; the central number bounces.

```dart
import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'counter_minimal.dart' show CounterData;

@Screen('counter_burst')
Widget counterBurst(CounterData data) {
  return Stack(
    alignment: Alignment.center,
    children: [
      for (final i in data.chips)
        Cue.onMount(
          motion: CueMotion.smooth(),
          acts: [
            Act.fadeIn(),
            Act.slideY(from: 0.3),
            Act.scale(from: 0.5, to: 1.0),
          ],
          child: Padding(
            padding: EdgeInsets.only(left: 6.0 * i, top: 4.0 * i),
            child: const Icon(Icons.star, size: 24, color: Colors.amber),
          ),
        ),
      Cue.onChange(
        value: data.value,
        motion: CueMotion.springy(),
        acts: [Act.scale(from: 0.7, to: 1.0)],
        child: Text(
          '${data.value}',
          style: const TextStyle(fontSize: 128, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}
```

**Step 3 — Author `counter_stress.dart`** — same shape as burst, with a few extra acts per chip to maximize per-frame animation work. The host will feed it a much longer `chips` list (500+).

```dart
import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
import 'counter_minimal.dart' show CounterData;

@Screen('counter_stress')
Widget counterStress(CounterData data) {
  return Stack(
    alignment: Alignment.center,
    children: [
      for (final i in data.chips)
        Cue.onMount(
          motion: CueMotion.smooth(),
          acts: [
            Act.fadeIn(),
            Act.slideY(from: 0.2),
            Act.scale(from: 0.4, to: 1.0),
            Act.rotate(to: 360.0),
          ],
          child: Transform.translate(
            offset: Offset((i % 30 - 15) * 18.0, ((i ~/ 30) - 8) * 18.0),
            child: const Icon(Icons.circle, size: 10, color: Colors.deepPurple),
          ),
        ),
      Cue.onChange(
        value: data.value,
        motion: CueMotion.springy(),
        acts: [Act.scale(from: 0.6, to: 1.0)],
        child: Text(
          '${data.value}',
          style: const TextStyle(fontSize: 144, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}
```

**Step 4 — Verify** — `dart analyze lib/screens/counter_burst.dart lib/screens/counter_stress.dart` clean.

**Step 5 — Note on cue API shapes** — if any of the Cue/Act/CueMotion ctor signatures in this plan don't match cue 0.2.1 exactly (the `from:` named arg, the `springy()` factory, the `onChange.value` param shape), adjust to match the real API. Do NOT invent new variants — keep parameter set minimal so the codegen output stays inspectable. If the API has changed substantially, STOP and report; we'll update the plan rather than guess.

---

## Task 5 — Regenerate IR

**Step 1 — Run codegen**

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

**Step 2 — Verify the generated registration file** for each variant lists the cue widgets and value builders. For example:

```
grep -n "Cue.onMount\|Cue.onChange\|Act.fadeIn\|Act.scale\|CueMotion" \
  packages/desk_sdui_demo/lib/screens/counter_burst.sdui_reg.g.dart
```

Expected: matches present. If any are missing, this is the same kind of codegen gap caught by the cue example plan — STOP and report rather than work around.

**Step 3 — Commit the screens + generated artifacts.**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
git add packages/desk_sdui_demo/lib/screens/counter_*.dart \
        packages/desk_sdui_demo/lib/screens/counter_*.g.dart \
        packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart
git commit -m "feat(demo): counter app variants with cue animation"
```

---

## Task 6 — Host UI: variant switcher + counter controls

**Files:**
- Modify: `packages/desk_sdui_demo/lib/main.dart` (full rewrite — easier than diffing).

**Step 1 — Replace with the counter host.**

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

enum _Variant {
  minimal('counter_minimal',  'Minimal', 0),
  bouncy ('counter_bouncy',   'Bouncy',  0),
  burst  ('counter_burst',    'Burst',   24),
  stress ('counter_stress',   'Stress',  500);

  const _Variant(this.screenName, this.label, this.chipCount);
  final String screenName;
  final String label;
  final int chipCount;
}

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;
  int value = 0;
  _Variant variant = _Variant.bouncy;

  @override
  void initState() {
    super.initState();
    rt = Runtime();
    registerAllScreens(rt);
  }

  void _bump(int delta) => setState(() => value += delta);
  void _reset()         => setState(() => value = 0);

  @override
  Widget build(BuildContext context) {
    final chips = List<int>.generate(variant.chipCount, (i) => i);
    return MaterialApp(
      title: 'desk_sdui — counter',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('desk_sdui — counter'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<_Variant>(
                segments: [
                  for (final v in _Variant.values)
                    ButtonSegment(value: v, label: Text(v.label)),
                ],
                selected: {variant},
                onSelectionChanged: (s) => setState(() => variant = s.first),
              ),
            ),
          ),
        ),
        body: SduiScreen(
          runtime: rt,
          name: variant.screenName,
          inputs: {
            'data': {'value': value, 'chips': chips},
          },
        ),
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'dec',
              onPressed: () => _bump(-1),
              child: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.extended(
              heroTag: 'reset',
              onPressed: _reset,
              label: const Text('Reset'),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'inc',
              onPressed: () => _bump(1),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2 — Verify**

```
cd packages/desk_sdui_demo && flutter analyze
```

Expected: clean.

**Step 3 — Commit**

```
git commit -am "feat(demo): variant switcher + counter controls"
```

---

## Task 7 — Run + manually verify all four variants

**Step 1 — Launch on Chrome**

```
cd packages/desk_sdui_demo
flutter run -d chrome --target lib/main.dart
```

**Step 2 — Walk through each variant.** For each, click `+` repeatedly, click `Reset`, click `-`. Confirm:
- **Minimal**: number updates with no animation, no errors.
- **Bouncy**: every increment triggers a scale-bounce on the number.
- **Burst**: 24 stars fade-in on mount; central number bounces on change.
- **Stress**: ~500 particles render and animate; no frame drops visible during sustained +/- spamming.

**Step 3 — Use Chrome devtools Performance tab** while on the Stress variant, increment 10x rapidly, record. Expected: 60fps maintained or short blips ≤200ms, no sustained main-thread blocking.

**Step 4 — Failure modes** (same triage rules as the cue example plan):
- `Bad state: Widget "Cue.X" not registered` → codegen gap, STOP.
- `Bad state: No value builder for "Act.X"` → codegen gap, STOP.
- `Bad state: resolveRef: cannot traverse segment "X" into Y` → core-accessor leak; the `data.chips` list traversal probably hit it.
- Visible frame stutter on Stress at ≤500 chips on a typical dev machine → real runtime perf issue; report frame timing and we'll dig in.

**Step 5 — Commit** any incidental fixes that came up.

```
git add -A && git commit -m "chore(demo): fixups discovered during manual verification"
```

---

## Out of scope

- Live code editor (dropped — needs a backend or browser-side Dart interpreter, neither in scope).
- Counter persistence across reloads.
- Theming controls.
- Removing the chef screen — it stays as a non-animation regression target. `main.dart` simply doesn't link to it anymore.

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo

flutter pub get
flutter analyze
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d chrome --target lib/main.dart   # manual: cycle variants, hit Stress hard
```
