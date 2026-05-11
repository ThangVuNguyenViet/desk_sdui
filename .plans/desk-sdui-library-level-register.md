# desk_sdui — library-level `@Register`

**Goal:** Allow `@Register([...])` to be placed as a *library-level* annotation, eliminating the carrier-class boilerplate.

Before:
```dart
@Register([Text, Column, ElevatedButton])
class _SduiCatalog {}
```

After (preferred):
```dart
@Register([Text, Column, ElevatedButton])
library;
```

The carrier-class form continues to work — this is purely additive.

**Why:** The carrier class is a placeholder with no semantic purpose. Library-level annotations (Dart 3.0+) are the natural home for catalog declarations because they describe the *file*, not a class.

**Prereq:** `catalog-rename` plan merged (this plan uses `SduiCatalog` / `catalogTypes` naming).

**Acceptance:**

1. A library declared with `@Register([...]) library;` is detected by the generator and contributes types identically to the class form.
2. Both library-level and class-level forms can coexist in the same package; the union of their types is registered.
3. The diagnostic ("widget X is referenced but not registered") works against the combined set.
4. Existing carrier-class catalogs continue to work unchanged.
5. New unit test covers library-level discovery.

---

## Task 1 — Extend the reader

**File:** `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`

Currently:
```dart
for (final annotated in libReader.annotatedWith(_catalogChecker)) {
  final el = annotated.element;
  if (el is! ClassElement) continue;
  // ...
}
```

`LibraryReader.annotatedWith` from `source_gen` only walks top-level *declarations*, not the library directive itself. Add a parallel scan for library-level annotations — alongside the class-level loop:

```dart
// Library-level @Register (Dart 3.0+).
for (final meta in lib.metadata.annotations) {
  final obj = meta.computeConstantValue();
  if (obj == null) continue;
  if (!_catalogChecker.isExactlyType(obj.type!)) continue;
  final partial = collectTypesFromAnnotation(lib, obj);
  catalogTypes.unionWith(partial);
}
```

Notes:
- In analyzer 13, `LibraryElement.metadata` returns a `Metadata` value; `.annotations` is the list of `ElementAnnotation`. Confirm exact API by reading analyzer if unsure.
- `collectTypesFromAnnotation` currently takes `(ClassElement, DartObject)`. Generalize the first parameter to `Element` (or `Element2`, whichever is current) since it only uses it for context, not class-specific behavior. If it does use class-specific fields, generalize accordingly.

---

## Task 2 — Test coverage

**File:** `packages/desk_sdui_generator/test/register_for_sdui_test.dart`

Add a new test group `library-level @Register`:

1. **Test:** library-level annotation only — types are picked up.
2. **Test:** library-level + class-level coexist — union is registered.
3. **Test:** diagnostic uses combined set — a screen referencing a library-registered widget passes; a screen referencing an unregistered widget still fails.

Reuse the test harness already in this file (`_resolveSource`, `collectTypesFromAnnotation`).

---

## Task 3 — Documentation

**File:** `packages/desk_sdui_annotation/lib/src/annotations.dart`

Update the dartdoc on `Register` to show both forms. The preferred form is library-level; the class form is documented as the alternative pattern:

```dart
/// ## Usage
///
/// Preferred (library-level, Dart 3.0+):
///
/// ```dart
/// @Register([Text, Column, ElevatedButton])
/// library;
/// ```
///
/// Alternative (carrier class — for files that don't own the library directive):
///
/// ```dart
/// @Register([Text, Column, ElevatedButton])
/// class _SduiCatalog {}
/// ```
///
/// Both forms produce the same registry contribution. Multiple catalogs in
/// the same package are unioned.
```

---

## Task 4 — Update the demo

**File:** `packages/desk_sdui_demo/lib/sdui_catalog.dart`

Convert from class form to library form. Note: `library;` directive must precede imports.

```dart
@Register([
  ...kCommonWidgets,
  ...kCommonMaterialWidgets,
  PageView,
  Cue,
  Act,
  CueMotion,
])
library;

import 'package:cue/cue.dart';
import 'package:desk_sdui/widget_bundles.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';
```

---

## Task 5 — Verify

```
cd packages/desk_sdui_generator
dart analyze
dart test
```

All tests pass.

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

Build succeeds. The generated `desk_sdui_setup.g.dart` is byte-identical (or differs only in stable registration order) to the pre-rename version — same types via a different annotation site.

```
dart analyze packages/desk_sdui_demo
```

Clean.

---

## Out of scope

- Removing the class-form support. Both forms coexist permanently.
- Renaming `@Register`.
- Multi-file aggregation rules beyond simple union.
