# desk_sdui — reachability-driven imports in `desk_sdui_setup.g.dart`

**Goal:** Fix a pre-existing generator bug. The top-level setup file emitted by `RegistryBuilder` references types from third-party packages (`Cue`, `Act`, `CueMotion`, `CounterController`, `ViewPadding`, `File`, `Uint8List`, …) inside the catalog block but only imports `package:flutter/{gestures,material,rendering}.dart` and `package:desk_sdui/desk_sdui.dart` plus per-screen binding imports. This makes every demo project with a non-trivial `@Register([...])` annotation fail to compile until the user manually patches imports.

The per-screen `.sdui_reg.g.dart` files already do this correctly (see commit `f1e26f7` — `replace hardcoded cue import with reachability-driven emission`). Same fix needs to apply to the setup file's catalog block.

**Acceptance:**
1. `cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter analyze` produces ZERO errors on `lib/desk_sdui_setup.g.dart` (and zero errors overall in the demo).
2. The setup file's import block contains exactly the package URIs reachable from the catalog types. Hardcoded `flutter/gestures.dart` / `flutter/material.dart` / `flutter/rendering.dart` are kept (catalog code uses many of their types), but the new package URIs (cue, dart:io, dart:typed_data, dart:ui, the demo's own screens for value classes like `CounterController`, …) are added based on what the catalog actually references.
3. If the catalog is empty, no extra imports beyond the existing baseline.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Verify commands:**
```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter analyze
```

---

## Task 1 — Find the existing reachability-driven import logic

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/screen_generator.dart`

### Step 1 — Read commit `f1e26f7` to understand the pattern

```
git show f1e26f7 -- packages/desk_sdui_generator/lib/src/screen_lowering/screen_generator.dart
```

Identify the helper(s) that:
- Walk a `CollectedTypes` (or equivalent) and collect each element's `library.uri`.
- Normalize URIs to importable `package:` / `dart:` URIs.
- Dedupe and sort.
- Emit `import '...';` lines.

If the logic lives inside `screen_generator.dart` only, factor it into a shared location in Task 2. If it's already in a helper module accessible to `registry_generator.dart`, reuse directly.

---

## Task 2 — Extract a shared import-emitter (if needed)

**File (likely new):** `packages/desk_sdui_generator/lib/src/import_emitter.dart`

If the reachability walker in `screen_generator.dart` is not already importable, extract a small helper:

```dart
/// Walks a CollectedTypes (and any extra Elements) and returns a sorted list
/// of unique `import '...';` lines covering every reachable element's library.
///
/// Skips:
///   - `dart:core` (always available)
///   - URIs already covered by [excluded] (e.g. baseline imports the caller
///     emits unconditionally)
///   - any element whose library URI is null / empty
List<String> emitImportsFor({
  required Iterable<Element> elements,
  Set<String> excluded = const {},
})
```

Have `screen_generator.dart` delegate to this helper (and verify its existing tests still pass).

If the screen_generator's existing helper is already shaped this way and just lives in the wrong package-private spot, just bump its visibility to `library`-internal so `registry_generator.dart` can import it. Don't relocate gratuitously.

---

## Task 3 — Wire imports into the setup file's catalog path

**File:** `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`

### Step 1 — Compute reachability set for the catalog

`_emitCatalogBlock(CollectedTypes? ct)` already has `ct`. Gather the elements whose libraries need importing:
- `ct.widgets` — class elements
- `ct.valueTypes` — class elements
- `ct.constants` — field/getter elements (use `.enclosingElement` for the class library)
- `ct.methods` — method elements (use `.enclosingElement`)
- `ct.subscriptables` — DartTypes; use their `element` (when interface)
- `ct.functions` — top-level function elements

Also walk **each constructor's parameter types** for everything in `ct.widgets ∪ ct.valueTypes`, since the generated registry casts arguments to those types (e.g. `args['child'] as Widget`, `args['arg0'] as Rect`, etc.). For each `DartType` param type, recurse into:
- `InterfaceType.element.library` for the head type
- `InterfaceType.typeArguments` element-by-element for generics

This is the same shape the per-screen `.sdui_reg.g.dart` files already do for screen lowering — port that logic if available, mirror it otherwise.

### Step 2 — Emit imports at the right spot

In the `return '''…'''` template at [registry_generator.dart:365-375](packages/desk_sdui_generator/lib/src/registry/registry_generator.dart#L365-L375), replace the hardcoded `flutterImport` interpolation with the union of:
1. The existing baseline (when catalog non-empty): `package:flutter/{gestures,material,rendering}.dart` — keep these unconditionally, they're cheap and the catalog almost always needs Material types.
2. The reachability-driven `import '...';` lines computed above, deduped against the baseline.

Sort all imports alphabetically within each group (`dart:` then `package:` then relative — match the screen_generator's existing ordering convention).

### Step 3 — Avoid duplicate imports with `importLines`

Note line 369: `$flutterImport$importLines` — `importLines` already contains the per-screen binding + reg-file imports. The new catalog-driven set must be deduped against `importLines` too (e.g. if `CounterController` is exported from `counter_actions.dart` and already imported via `show counter_actionsBinding`, you can either widen that `show` clause or add a separate `show CounterController` import — pick whichever the existing import-emitter convention does, don't invent a third style).

### Step 4 — Verify

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

Expected: green.

### Step 5 — Commit

```
git add -A && git commit -m "fix(desk_sdui_generator): reachability-driven imports in setup.g.dart catalog"
```

---

## Task 4 — Regenerate the demo and verify

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
cd packages/desk_sdui_demo && flutter analyze
```

Expected:
- `lib/desk_sdui_setup.g.dart` now contains imports for `package:cue/cue.dart`, `dart:io`, `dart:typed_data`, `dart:ui`, and any other library transitively referenced by the catalog.
- Zero errors. The 4 pre-existing `unnecessary_cast` warnings may stay or may go (they're unrelated; don't chase them).

Commit the regenerated artifacts:

```
git add -A && git commit -m "chore(desk_sdui_demo): regenerate setup.g.dart with reachability imports"
```

---

## Task 5 — Test coverage

**File:** `packages/desk_sdui_generator/test/screen_generator_registration_test.dart` (or wherever `RegistryBuilder.emitRegistryForTest` is exercised today)

Add a test that asserts: given a `catalogTypes` containing a class whose ctor references a third-party type (use the existing `Cue` / `Act` / `CueMotion` setup the tests already use), the emitted output:
- Contains an `import 'package:cue/cue.dart';` line.
- Does NOT contain a hardcoded `package:cue/cue.dart` import that pre-dates this fix.

Match the style of existing tests in the file — don't introduce a new helper pattern.

```
cd packages/desk_sdui_generator && dart test test/screen_generator_registration_test.dart
```

Commit:

```
git add -A && git commit -m "test(desk_sdui_generator): cover setup.g.dart reachability imports"
```

---

## Out of scope

- Removing the hardcoded `flutter/gestures.dart` / `flutter/material.dart` / `flutter/rendering.dart` baseline. They're cheap, virtually every catalog uses them, and stripping them risks unused-import noise. Keep as-is.
- Reordering existing imports for stylistic reasons.
- The unrelated `'Null' is not a subtype of double` runtime cast bug on the `counter_bouncy` default screen.
- Any change to the per-screen `.sdui_reg.g.dart` import emission — that already works.
