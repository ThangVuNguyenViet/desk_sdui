# desk_sdui demo — cue animation example screen

**Goal:** Add a runnable example screen in `desk_sdui_demo` that uses the `cue` animation package via desk_sdui's auto-registration codegen — proving zero hand-written adapters are needed for value-class/widget composition APIs.

**Architecture:** Add `cue` as a dep, write a new `@Screen` (`hero`) composing `Cue.onMount`, `Actor`, `Act.fadeIn`, `Act.slideY`, `CueMotion.smooth`. Regenerate; codegen should auto-emit `registerWidget` / `registerValueBuilder` entries for every cue type referenced. Wire as a second route in `main.dart` alongside the existing chef screen.

**Tech stack:** Flutter, `cue` (pub.dev), existing `desk_sdui_generator`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Precondition:** Plan `desk-sdui-core-accessors.md` must be merged first (the new `GetterNode` lowering does not affect cue usage, but rebuilding the demo against the old IR will produce mismatched artifacts).

---

## Task 1 — Add the dep

**Files:**
- Modify: `packages/desk_sdui_demo/pubspec.yaml`

**Step 1 — Add `cue:` to `dependencies:`.** Pin to the latest published version (look up with `dart pub deps` or check pub.dev):

```yaml
dependencies:
  cue: ^<latest>
```

**Step 2 — Resolve**

```
cd packages/desk_sdui_demo && flutter pub get
```

**Step 3 — Commit**

```
git add -A && git commit -m "chore(demo): add cue dependency"
```

---

## Task 2 — Write the @Screen

**Files:**
- Create: `packages/desk_sdui_demo/lib/screens/hero.dart`

**Step 1 — Author the screen.** Use **fully qualified** factory names (`Act.fadeIn()`, `CueMotion.smooth()`) — NOT Dart 3 dot-shorthand — to keep the lowerer's job mechanical and the IR readable.

```dart
import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

class HeroData {
  const HeroData({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

@Screen('hero')
Widget hero(HeroData data) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Cue.onMount(
          motion: CueMotion.smooth(),
          acts: [
            Act.fadeIn(),
            Act.slideY(from: 0.2),
          ],
          child: Text(
            data.title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        Cue.onMount(
          motion: CueMotion.smooth(),
          acts: [
            Act.fadeIn(),
            Act.slideY(from: 0.4),
          ],
          child: Text(
            data.subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      ],
    ),
  );
}
```

**Step 2 — Verify** the file parses:

```
cd packages/desk_sdui_demo && dart analyze lib/screens/hero.dart
```

Expected: clean. If analyzer reports any of the cue ctor signatures differently from what's used here (e.g. `from` named arg missing, `CueMotion.smooth` requires positional duration), adjust the screen to match. **Do NOT proceed to codegen if analyze fails** — codegen will silently emit broken IR.

**Step 3 — Commit**

```
git add -A && git commit -m "feat(demo): add hero @Screen using cue animation package"
```

---

## Task 3 — Regenerate IR + registrations

**Files:**
- Re-emit: `packages/desk_sdui_demo/lib/screens/hero.sdui.g.dart`
- Re-emit: `packages/desk_sdui_demo/lib/screens/hero.sdui_reg.g.dart`
- Re-emit: `packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart`

**Step 1 — Run codegen**

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

**Step 2 — Verify the generated reg file imports cue and registers each referenced cue type.** Expected to find — in `hero.sdui_reg.g.dart` — `registerWidget('Cue.onMount', ...)`, `registerValueBuilder('Act.fadeIn', ...)`, `registerValueBuilder('Act.slideY', ...)`, `registerValueBuilder('CueMotion.smooth', ...)`:

```
grep -n "Cue.onMount\|Act.fadeIn\|Act.slideY\|CueMotion.smooth" \
  packages/desk_sdui_demo/lib/screens/hero.sdui_reg.g.dart
```

Expected: at least one match per name.

**Step 3 — Verify `desk_sdui_setup.g.dart` calls `registerHeroDependencies`** (or whatever the per-screen entry point is named — check chef's pattern in the same file):

```
grep -n "hero\|registerHero" packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart
```

**Step 4 — If any of the cue types do NOT appear in the generated registration file, this is a real codegen bug — STOP and report it.** That would mean the generator does not handle whatever cue is doing (likely candidates: list-of-values args, dot-shorthand resolution, factory-vs-ctor classification). Do not paper over with a hand-written `@RegisterForSdui` annotation — surface it so we can fix codegen.

**Step 5 — Commit** the generated artifacts:

```
git add packages/desk_sdui_demo/lib/screens/hero.sdui.g.dart \
        packages/desk_sdui_demo/lib/screens/hero.sdui_reg.g.dart \
        packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart
git commit -m "feat(demo): regenerate IR + registrations for hero screen"
```

---

## Task 4 — Wire as a second route in `main.dart`

**Files:**
- Modify: `packages/desk_sdui_demo/lib/main.dart`

**Step 1 — Replace `_DemoAppState` body** with a screen switcher. Two `SegmentedButton` entries: "Chef" and "Hero". The same `Runtime` instance serves both (one `registerAllScreens(rt)` call at init covers every @Screen in the project — including hero — because the generated `desk_sdui_setup.g.dart` enumerates all of them).

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/data/fixtures.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});
  @override
  State<DemoApp> createState() => _DemoAppState();
}

enum _Demo { chef, hero }

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;
  _Demo selected = _Demo.chef;

  @override
  void initState() {
    super.initState();
    rt = Runtime();
    registerAllScreens(rt);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'desk_sdui demo',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('desk_sdui'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<_Demo>(
                segments: const [
                  ButtonSegment(value: _Demo.chef, label: Text('Chef')),
                  ButtonSegment(value: _Demo.hero, label: Text('Hero (cue)')),
                ],
                selected: {selected},
                onSelectionChanged: (s) => setState(() => selected = s.first),
              ),
            ),
          ),
        ),
        body: switch (selected) {
          _Demo.chef => SduiScreen(
              runtime: rt,
              name: 'chef',
              inputs: {
                'data': _chefDataToMap(),
                'controller': {
                  'tapBack': () => debugPrint('tapBack'),
                  'toggleBookmark': () => debugPrint('toggleBookmark'),
                },
              },
            ),
          _Demo.hero => SduiScreen(
              runtime: rt,
              name: 'hero',
              inputs: {
                'data': {
                  'title': 'Welcome to desk_sdui',
                  'subtitle': 'Animations powered by cue, lowered through codegen.',
                },
              },
            ),
        },
      ),
    );
  }
}

// (keep the existing _chefDataToMap() helper from main.dart unchanged)
```

**Step 2 — Verify**

```
cd packages/desk_sdui_demo && flutter analyze
```

Expected: clean.

**Step 3 — Commit**

```
git commit -am "feat(demo): screen switcher with chef + hero (cue) examples"
```

---

## Task 5 — Run the demo and verify the animation plays

**Step 1 — Launch on Chrome**

```
cd packages/desk_sdui_demo
flutter run -d chrome --target lib/main.dart
```

**Step 2 — Switch to the "Hero (cue)" tab.** Expected: the title fades + slides in, then the subtitle fades + slides in slightly later. No exceptions in the console.

**Step 3 — Possible failure modes & what they mean:**
- `Bad state: Widget "Cue.onMount" is not registered` → Task 3 step 4 caught a real codegen bug; do not work around, escalate.
- `Bad state: No value builder for "Act.fadeIn"` → same, codegen gap.
- `Bad state: resolveRef: cannot traverse segment "X" into Y` → core-accessors plan's resolver shrink is still too aggressive; report the segment and receiver type.
- Cue compile errors against the ctor signatures (e.g. `from` is not a named param) → cue's API has shifted since the WebFetch snapshot used to draft this plan; update the screen to match the real cue 1.x API and re-run from Task 2.

**Step 4 — Confirm no regression** in the chef screen by switching back.

**Step 5 — Commit any IR regenerations** that resulted from fixing ctor signatures along the way. Otherwise this task is verification-only.

---

## Out of scope

- Network-driven cue screens (loading IR from a `.sduiir` asset / HTTP). The point of this example is to validate the *lowering* path; serialization round-tripping is covered by existing codec tests.
- The `.act([...])` Widget extension — requires the deferred method-call-on-widget work; this plan uses cue's canonical Cue/Actor/Act composition form.
- Imperative `CueController` usage. Memory's "host owns AnimationController" pattern applies identically to CueController; documenting it is a separate plan.

## Verify commands (full suite)

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo

flutter pub get
flutter analyze
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d chrome --target lib/main.dart   # manual: switch tabs, observe animation
```
