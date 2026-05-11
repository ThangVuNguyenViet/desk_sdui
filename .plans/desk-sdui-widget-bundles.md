# desk_sdui — explicit registration with build-time diagnostic

**Goal:** Replace the generator's AST-driven auto-registration with an **explicit-registration + build-time diagnostic** model. Consumers list the widgets they want available via `@RegisterForSdui([...])` (typically with help of bundled `const List<Type>` lists). The generator walks every `@Screen` body, compares referenced widget types against the registered set, and **fails the build** if any referenced widget is unregistered.

**Motivation:** Auto-register couples the registration set to whichever widgets happen to appear in static `@Screen` bodies. Refactor away the last reference to `Stack` and it silently vanishes from the registry — network-driven screens that need `Stack` then 500 at runtime. Explicit registration + diagnostic gives a single mental model ("the registry is exactly what you list") plus a safety net that catches missing widgets at build time, not runtime.

**Architecture:**
- `desk_sdui` ships `lib/widget_bundles.dart` exporting `const kCommonWidgets`, `const kCommonMaterialWidgets`, `const kCommonCupertinoWidgets` (`List<Type>`).
- The generator's screen lowering still walks each `@Screen` body and collects the set of widget Types it references (call this the "referenced set").
- The generator's `@RegisterForSdui` reader collects every type listed across all annotations in the build target (the "registered set"). Bundles work because const lists compose into the annotation argument.
- Per-build pass: for each screen, if `referenced \ registered` is non-empty, emit a `package:build` `error`-level log per missing type. Build fails. No registrations are emitted for the auto-discovered set anymore — only what's in `@RegisterForSdui` annotations.
- Tree-shake stays correct: the registered set is a hard upper bound, listed in source.

**Prereq:** analyzer-13 migration landed (commit `ccc57b3`).

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Acceptance:**
1. `import 'package:desk_sdui/widget_bundles.dart';` exposes `kCommonWidgets`, `kCommonMaterialWidgets`, `kCommonCupertinoWidgets`.
2. `desk_sdui_demo` defines a `@RegisterForSdui` covering exactly the widgets its screens use (via the bundles + a small custom list). Chef + counter IR files (`*.sdui.g.dart`, `*.sdui.json`) are byte-identical to their state on `main`.
3. `desk_sdui_setup.g.dart` no longer contains auto-discovered registrations — only the ones derived from `@RegisterForSdui`.
4. Deliberately removing `Stack` from the demo's `@RegisterForSdui` (while a `@Screen` still references it) causes `dart run build_runner build` to fail with a clear error naming the screen and the missing type. Restoring the entry makes the build pass.
5. README in `packages/desk_sdui/` documents the new pattern in one ~60-line section.

---

## Task 1 — Verify `@RegisterForSdui` reader follows const references

**Files (read-only):**
- `packages/desk_sdui_generator/lib/src/registration_emitter.dart`
- `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`

**Step 1.** Locate where the generator reads `RegisterForSdui.types`. If it uses `ConstantReader.listValue` / `DartObject.toListValue()`, const references compose for free — proceed to Task 2.

**Step 2.** If it parses a literal `[...]` AST list, extend it to call `annotation.computeConstantValue()?.getField('types')?.toListValue()` and walk the resulting `DartObject` list. Add a test that `@RegisterForSdui(_top)` with `const _top = <Type>[Column];` registers `Column`.

---

## Task 2 — Ship the widget bundles

**Files:**
- Create: `packages/desk_sdui/lib/widget_bundles.dart`
- Modify: `packages/desk_sdui/lib/desk_sdui.dart` (add the export)

**Step 1 — Write the bundle file:**

```dart
/// Curated `const List<Type>` bundles for use with `@RegisterForSdui`.
///
/// ```dart
/// import 'package:desk_sdui/widget_bundles.dart';
/// import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
///
/// @RegisterForSdui([
///   ...kCommonWidgets,
///   ...kCommonMaterialWidgets,
///   MyCustomButton,
/// ])
/// class _Registrations {}
/// ```
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Stable, framework-agnostic widgets from `package:flutter/widgets.dart`.
const List<Type> kCommonWidgets = <Type>[
  Align, AspectRatio, Center, Column, ConstrainedBox, Container,
  Expanded, FittedBox, Flexible, IntrinsicHeight, IntrinsicWidth, Padding,
  Positioned, Row, SafeArea, SizedBox, Spacer, Stack, Wrap,
  ListView, SingleChildScrollView,
  ClipOval, ClipRRect, ClipRect, DecoratedBox, Icon, Image, Opacity,
  RotatedBox, Text, Transform,
  GestureDetector, InkWell,
  Builder, Divider, Visibility,
];

/// Material design widgets from `package:flutter/material.dart`.
const List<Type> kCommonMaterialWidgets = <Type>[
  AppBar, Card, Chip, CircularProgressIndicator, Drawer,
  ElevatedButton, FilledButton, FloatingActionButton, IconButton,
  LinearProgressIndicator, ListTile, MaterialBanner, OutlinedButton,
  Scaffold, SnackBar, Switch, TextButton, TextField,
];

/// Cupertino design widgets from `package:flutter/cupertino.dart`.
const List<Type> kCommonCupertinoWidgets = <Type>[
  CupertinoActivityIndicator, CupertinoButton, CupertinoNavigationBar,
  CupertinoPageScaffold, CupertinoSwitch, CupertinoTextField,
];
```

**Step 2 — Verify** every Type is const-able (some widgets may be abstract or generic without defaults). Drop any that fail `dart analyze`; document the drop in the commit message.

```
cd packages/desk_sdui && dart analyze lib/widget_bundles.dart
```

**Step 3 — Export** from `packages/desk_sdui/lib/desk_sdui.dart`:

```dart
export 'widget_bundles.dart';
```

---

## Task 3 — Generator: switch auto-register → diagnostic

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/registration_emitter.dart`
- Possibly modify: `packages/desk_sdui_generator/lib/src/type_collector.dart` (if it's where the "referenced widget types" set is collected)
- Modify: `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart` (the per-target aggregation that emits `desk_sdui_setup.g.dart`)

**Step 1 — Locate the AST-driven discovery.** Find where the generator currently collects "Types referenced from `@Screen` bodies" and emits registrations for each. This is the auto-register path.

**Step 2 — Repurpose, don't delete.** Keep the discovery code; change its emission target:
- BEFORE: emit `rt.registerWidget('Stack', ...)` for each discovered Type.
- AFTER: collect the discovered Types into a per-target set, intersect with the `@RegisterForSdui` set, and for every miss call `log.severe('Screen "$name" references unregistered widget $type. Add $type to a @RegisterForSdui list or import one of the bundles from package:desk_sdui/widget_bundles.dart.');`

`log` is the `Builder` log (already available in source_gen builders). `log.severe` causes `build_runner` to fail the build.

**Step 3 — Stop emitting auto-discovered registrations.** The aggregate `desk_sdui_setup.g.dart` should only emit registrations derived from `@RegisterForSdui`. Anything previously auto-emitted is removed from the codegen output.

**Step 4 — Add a unit test** in `packages/desk_sdui_generator/test/` that:
1. Compiles a fixture with a `@Screen` referencing `Stack` and no `@RegisterForSdui` covering it. Asserts the builder reports a `severe`-level log mentioning `Stack`.
2. Compiles the same fixture with `@RegisterForSdui([Stack])` added. Asserts the builder succeeds and `Stack` appears in the generated registrations.

`build_test` exposes `testBuilder(...)` with a `messages` callback for this.

**Step 5 — Verify generator analyzes + tests clean:**

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

---

## Task 4 — Migrate desk_sdui_demo to explicit registration

**Files:**
- Create: `packages/desk_sdui_demo/lib/sdui_coverage.dart`
- Modify: `packages/desk_sdui_demo/lib/main.dart` (if it imports the generated setup; usually no edit needed)

**Step 1 — Write the coverage file:**

```dart
// packages/desk_sdui_demo/lib/sdui_coverage.dart
import 'package:desk_sdui/widget_bundles.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@RegisterForSdui([
  ...kCommonWidgets,
  ...kCommonMaterialWidgets,
  // Add any widget the demo's @Screen bodies reference that isn't in the
  // bundles. Build error names what's missing; iterate until clean.
])
class _SduiCoverage {}
```

**Step 2 — Regenerate.** Build will likely fail the first time, naming widgets the demo screens reference that the bundles don't cover. Add them to the inline list (not the bundle) until the build passes:

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
```

If a missing widget *should* be in a bundle, move it to the appropriate bundle and re-export. Otherwise keep it inline.

**Step 3 — Verify byte-identical screen IR:**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
git diff main -- 'packages/desk_sdui_demo/lib/screens/*.sdui.g.dart' \
                 'packages/desk_sdui_demo/lib/screens/*.sdui.json' \
                 'packages/desk_sdui_demo/lib/screens/*.sdui_reg.g.dart'
```

Expected: zero diff. The IR for each screen depends only on its body, not on the registration set, so it must not change.

`packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart` WILL change shape — that's expected (it now lists exactly the `@RegisterForSdui` set, not the auto-discovered superset).

**Step 4 — Smoke test the diagnostic.** Temporarily remove `Stack` from `kCommonWidgets` (or comment out the relevant bundle entry) and re-run `build_runner build`. Expected: build fails with a clear error naming the screen and `Stack`. Restore, build passes.

Hero blocker (pre-existing): rename `hero.dart` → `hero.dart.disabled` for the duration of any build_runner run that would trip over it. Restore before committing. Do not commit hero.dart edits.

---

## Task 5 — README documentation

**Files:**
- Modify: `packages/desk_sdui/README.md`

**Step 1 — Add a section** titled `## Registering widgets`. Cover:

1. **Why explicit.** One sentence on the registry-is-what-you-list model and the build-time diagnostic.
2. **Common case.** Drop in the bundles:
   ```dart
   @RegisterForSdui([...kCommonWidgets, ...kCommonMaterialWidgets])
   class _Core {}
   ```
3. **Third-party design systems (shadcn_ui, etc.).** Mirror file pattern:
   ```dart
   @RegisterForSdui([
     ...kCommonWidgets,
     ShadButton, ShadCard, ShadInput, ShadSelect,
   ])
   class _ShadcnRegistrations {}
   ```
4. **What happens if you forget.** Show an example build error.

Keep it under ~80 lines. Link to the API doc on `kCommonWidgets` for the full list.

---

## Task 6 — Verify + commit

**Step 1 — Full sanity:**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
(cd packages/desk_sdui && dart analyze) || exit 1
(cd packages/desk_sdui_annotation && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_generator && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_demo && flutter pub get && flutter analyze \
  && dart run build_runner build --delete-conflicting-outputs && flutter test) || exit 1
```

**Step 2 — Commit on `feat/registration-diagnostic`:**

```
git add -A && git commit -m "feat: explicit @RegisterForSdui + build-time diagnostic for missing widgets"
```

Do NOT push, do NOT merge.

---

## Out of scope

- A separate generator-side annotation that auto-includes everything exported from a package. Defeats tree-shaking. Future opt-in for prototyping if anyone asks.
- Per-screen allowlists (the diagnostic operates per-target; one missing widget anywhere fails the whole build). A finer-grained model is possible but not needed yet.
- Migrating the registration_emitter to also diagnose unused registrations (i.e. `registered \ referenced`). Could add later as a `lint`-level warning, not now.

## Open questions

1. Does the existing `RegisterForSdui` reader follow const references? Task 1 confirms.
2. Are any widgets in the bundle lists not const-Type-able? Drop them at Task 2 step 2 and document.
3. What's the build_runner log level for "this build is broken"? Confirm `log.severe` (not `log.warning`) actually fails the build — if not, throw from inside the builder instead.
