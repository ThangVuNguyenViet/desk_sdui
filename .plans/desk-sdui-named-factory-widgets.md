# desk_sdui — register named widget factory constructors

**Goal:** Fix a latent generator bug: `RegistrationEmitter.emitWidget` only emits a `registerWidget('Foo', …)` line for the **unnamed** constructor. Named factory constructors on widget classes (e.g. `Cue.onMount`, `Cue.onHover`, `Image.network`, `Image.asset`, `Text.rich`) are silently dropped from the registry, so the lowerer correctly emits `WidgetNode(name: 'Cue.onMount', …)` but the runtime cannot resolve it.

Value types already do this correctly — see [registration_emitter.dart:187-194](packages/desk_sdui_generator/lib/src/registration_emitter.dart#L187-L194). This plan ports the same loop to widgets.

**Why now:** The cue-example demo (`hero.dart`) needs `Cue.onMount`. We've also been one screen away from tripping over the same gap with `Image.network` etc. Pure generator-side fix — runtime `registerWidget(String, builder)` is already keyed by qualified string, no runtime change needed.

**Architecture:** Mirror the value-type loop inside `RegistrationEmitter.emitAll`. After the existing unnamed-ctor emit, iterate `widget.constructors`; for each public named ctor (`name` non-empty, `!= 'new'`, `!isPrivate`), emit a second `registerWidget('Cue.onMount', (args) => Cue.onMount(...))` line using the **named ctor's own param list** so `motion`, `acts`, `child`, `key` all flow correctly. Reuse `_buildWidgetArgList` so `children: List<Widget>` casting and `key` handling stay uniform.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Verify commands** (run from repo root unless noted):
```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && dart analyze
```

---

## Task 1 — Refactor `emitWidget` to take a `ConstructorElement`, add per-ctor helper

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`

### Step 1 — Read the current shape

[registration_emitter.dart:31-37](packages/desk_sdui_generator/lib/src/registration_emitter.dart#L31-L37) — `emitWidget(ClassElement)` looks up the unnamed ctor and emits one line.

[registration_emitter.dart:173-176](packages/desk_sdui_generator/lib/src/registration_emitter.dart#L173-L176) — `emitAll` calls `emitWidget(widget)` once per widget class.

### Step 2 — Add a private `_emitWidgetCtor(ConstructorElement, {required String registrationName})` helper

```dart
/// Emit a `rt.registerWidget(...)` line for a specific constructor [ctor].
/// [registrationName] is the qualified name (e.g. 'Cue' or 'Cue.onMount').
/// [callTarget] is the Dart expression used to invoke it
/// (e.g. 'Cue' or 'Cue.onMount').
String _emitWidgetCtor(
  ConstructorElement ctor, {
  required String registrationName,
  required String callTarget,
}) {
  final params = ctor.formalParameters;
  final argsCode = _buildWidgetArgList(params);
  return "rt.registerWidget('$registrationName', "
      "(args) => $callTarget($argsCode));";
}
```

### Step 3 — Rewrite the public `emitWidget` to delegate

```dart
String emitWidget(ClassElement widget) {
  final ctor = _unnamedCtor(widget);
  if (ctor == null) return '// No unnamed constructor for ${widget.name}';
  return _emitWidgetCtor(
    ctor,
    registrationName: widget.name!,
    callTarget: widget.name!,
  );
}
```

(`emitWidget` keeps its current single-line contract so callers that only want the unnamed form are unaffected; existing tests stay green.)

### Step 4 — Commit

```
git add -A && git commit -m "refactor(desk_sdui_generator): extract _emitWidgetCtor helper for per-ctor widget registration"
```

---

## Task 2 — Walk widget constructors in `emitAll`

**File:** `packages/desk_sdui_generator/lib/src/registration_emitter.dart`

### Step 1 — Update the widget loop in `emitAll` to mirror the value-type loop

Find [registration_emitter.dart:173-176](packages/desk_sdui_generator/lib/src/registration_emitter.dart#L173-L176):

```dart
for (final widget in collected.widgets) {
  lines.add(emitWidget(widget));
}
```

Replace with:

```dart
for (final widget in collected.widgets) {
  // 1. Unnamed ctor (skip if widget is abstract with no unnamed factory).
  final unnamed = _unnamedCtor(widget);
  if (unnamed != null) {
    lines.add(_emitWidgetCtor(
      unnamed,
      registrationName: widget.name!,
      callTarget: widget.name!,
    ));
  } else if (!widget.isAbstract) {
    // Concrete widgets must have an unnamed ctor; emit the existing marker
    // comment for visibility.
    lines.add('// No unnamed constructor for ${widget.name}');
  }

  // 2. Public named factory ctors. Includes abstract widgets like `Cue`
  //    whose only instantiation paths are named factories.
  for (final ctor in widget.constructors) {
    final ctorName = ctor.name ?? '';
    if (ctorName.isEmpty || ctorName == 'new') continue; // handled above
    if (ctor.isPrivate) continue;
    final qualified = '${widget.name}.$ctorName';
    lines.add(_emitWidgetCtor(
      ctor,
      registrationName: qualified,
      callTarget: qualified,
    ));
  }
}
```

Rationale per branch:
- `Cue` is `abstract` → `_unnamedCtor` may still return the `factory Cue({...})` (factories count as constructors); the abstract guard only suppresses the "missing ctor" comment.
- Skipping `'new'` matches the analyzer-13 normalization used in `_unnamedCtor` and the value-type loop.
- Private factories (rare on widgets, but possible) are skipped to match the value-type rule.

### Step 2 — Run existing emitter tests

```
cd packages/desk_sdui_generator && dart test test/registration_emitter_test.dart
```

Expected: still green. (The refactor in Task 1 preserves the original `emitWidget` line-for-line; the new behavior only kicks in via `emitAll`.)

### Step 3 — Commit

```
git add -A && git commit -m "fix(desk_sdui_generator): emit registerWidget for named widget factory constructors"
```

---

## Task 3 — Add a focused test for the new behavior

**File:** `packages/desk_sdui_generator/test/registration_emitter_test.dart`

### Step 1 — Fix the hardcoded path while we're here

The file currently has:

```dart
const _demoPackageRoot =
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';
```

Replace with the same CWD-relative pattern used in [register_for_sdui_test.dart:30-32](packages/desk_sdui_generator/test/register_for_sdui_test.dart#L30-L32):

```dart
import 'package:path/path.dart' as p;
// ...
final String _demoPackageRoot = p.normalize(
  p.join(Directory.current.path, '..', 'desk_sdui_demo'),
);
```

Change `const` → `final` accordingly.

### Step 2 — Add a test for the named-ctor emission via `emitAll`

Add a new `group('emitAll — named widget factories', () { … });` block. The test resolves a tiny source that imports `package:cue/cue.dart`, builds a `CollectedTypes` with `Cue` in `.widgets`, calls `emitAll`, and asserts:

```dart
test('emitAll emits registerWidget for each named factory on Cue', () async {
  const source = '''
import 'package:cue/cue.dart';
import 'package:flutter/widgets.dart';

void _ref() {
  // touch types so resolution keeps them
  // ignore: unused_local_variable
  final c = Cue;
}
''';

  final result = await _resolveSource(source);
  // Locate the Cue ClassElement via the resolved unit's imports.
  final cueLib = result.libraryElement.importedLibraries.firstWhere(
    (l) => l.uri.toString() == 'package:cue/cue.dart',
  );
  final cueClass = cueLib.topLevelElements
      .whereType<ClassElement>()
      .firstWhere((c) => c.name == 'Cue');

  final collected = CollectedTypes()..widgets.add(cueClass);
  final out = RegistrationEmitter().emitAll(collected);

  // Unnamed form still present.
  expect(out, contains("rt.registerWidget('Cue',"));
  // At least the named factories the demo uses must appear.
  expect(out, contains("rt.registerWidget('Cue.onMount',"));
  expect(out, contains("rt.registerWidget('Cue.onChange',"));
  // Spot-check that the call target uses the qualified name.
  expect(out, contains('=> Cue.onMount('));
});
```

If `result.libraryElement.importedLibraries` / `topLevelElements` differ for the analyzer version pinned in this repo, use whatever helper the existing tests in this file already use to find an element by name in an imported library — don't invent new traversal patterns. (Look at the value-type tests in the same file for the established style and copy it.)

### Step 3 — Run only this test file

```
cd packages/desk_sdui_generator && dart test test/registration_emitter_test.dart -n 'named widget factories'
```

Expected: PASS.

### Step 4 — Commit

```
git add -A && git commit -m "test(desk_sdui_generator): cover named widget factory registration"
```

---

## Task 4 — Regenerate the demo and sanity-check

**Goal:** Confirm no existing demo screen's generated registry changed in a meaningful way (the new code only ADDS lines for named factories of already-collected widgets), and that the registry now contains entries for any named widget factories actually reachable in the demo.

### Step 1 — Regenerate

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
```

Expected: clean build.

### Step 2 — Analyze

```
cd packages/desk_sdui_demo && dart analyze
```

Expected: no new warnings/errors caused by this change.

> Note: the existing pre-existing bug in `desk_sdui_setup.g.dart` (missing `import 'package:cue/cue.dart';` at the top-level setup file) is **out of scope** here. If that warning is already present on `main`, it stays. Do not chase it in this plan.

### Step 3 — Inspect a generated `.sdui_reg.g.dart`

For any screen in the demo today that already references a widget class with named factories, the regenerated file should now contain extra `registerWidget('X.name', …)` lines. If nothing in the demo currently exercises this, the diff is essentially zero (which is also a valid outcome — the change is dormant until cue-example lands).

Run:
```
git diff -- 'packages/desk_sdui_demo/**/*.sdui_reg.g.dart' 'packages/desk_sdui_demo/**/desk_sdui_setup.g.dart'
```

Report the diff in the PR / status update. If any line looks suspicious (e.g. a registration whose call target wouldn't compile), STOP and report — do not commit until resolved.

### Step 4 — Commit regenerated artifacts (if any)

```
git add -A && git commit -m "chore(desk_sdui_demo): regenerate after named-widget-factory fix"
```

(If the diff is empty, skip this commit.)

---

## Task 5 — Final verification

```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart analyze
```

All green. No regressions.

---

## Out of scope (do NOT touch in this plan)

- Reviving the cue-example branch / `hero.dart` screen — separate follow-up after this lands.
- Fixing the pre-existing `desk_sdui_setup.g.dart` missing-cue-import bug — separate plan.
- Any runtime-side change. `registerWidget(String, …)` already accepts any string key; the runtime resolver looks up `WidgetNode.name` verbatim. No changes needed in `packages/desk_sdui`.
- Redirecting / generative-vs-factory distinction. Treat all public non-`new` named ctors uniformly; analyzer-level `isFactory` is not a meaningful filter here (named generative ctors on a concrete widget are equally valid).
- Generalizing `emitWidget`'s public signature beyond what Task 1 requires. The single-line contract stays — multi-ctor emission lives in `emitAll`.
