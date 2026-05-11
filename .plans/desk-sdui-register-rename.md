# desk_sdui — `@RegisterForSdui` → `@Register`

**Goal:** Mechanical rename of the annotation class `RegisterForSdui` to `Register`. The shorter name reflects the unified model: `@Register([T])` declares "expose T's named callable surface to the SDUI registry." There's no widget/value/dispatch distinction — every registered type contributes the same kind of entries.

**Why short?** The annotation appears at every catalog site (`@Register([...Widgets, ...Material, MyVM])`). The longer `RegisterForSdui` repeats the package name redundantly — devs already imported `desk_sdui_annotation`, the `ForSdui` suffix adds nothing.

**Rename mapping:**

| Old | New |
|---|---|
| `class RegisterForSdui` (in `annotations.dart`) | `class Register` |
| `RegisterForSdui` (all usages) | `Register` |
| `@RegisterForSdui([...])` (catalog declarations) | `@Register([...])` |
| `TypeChecker.typeNamed(RegisterForSdui, ...)` | `TypeChecker.typeNamed(Register, ...)` |
| Doc comments mentioning the old name | Updated to `Register` |
| Plan files mentioning the old name | Left alone (they're historical) |

**Acceptance:**

1. `grep -rn 'RegisterForSdui' packages/ --include='*.dart' | grep -v '/.dart_tool/' | grep -v 'build/'` returns zero matches.
2. `cd packages/desk_sdui_generator && dart analyze && dart test` passes.
3. `cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && dart analyze` succeeds.
4. The demo's `sdui_catalog.dart` shows `@Register([...])` instead of `@RegisterForSdui([...])`.

---

## Task 1 — Annotation class

**File:** `packages/desk_sdui_annotation/lib/src/annotations.dart`

```diff
- class RegisterForSdui {
-   const RegisterForSdui(this.types);
+ class Register {
+   const Register(this.types);
    final List<Type> types;
  }
```

Update the dartdoc comment on the class. Replace `@RegisterForSdui` with `@Register` in examples.

---

## Task 2 — Re-exports

**File:** `packages/desk_sdui_annotation/lib/desk_sdui_annotation.dart`

If the barrel file exports `RegisterForSdui` by name, update. Most barrel files use `export 'src/annotations.dart';` (no symbol list) — no change needed in that case.

---

## Task 3 — Generator references

**Files:**
- `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`
- `packages/desk_sdui_generator/lib/src/type_collector.dart` (if it references the name)
- Any other generator-side file with `RegisterForSdui` in code or strings

Replace `TypeChecker.typeNamed(RegisterForSdui, inPackage: 'desk_sdui_annotation')` → `TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation')`.

Update any error messages referencing `@RegisterForSdui` to say `@Register` instead.

---

## Task 4 — Test fixtures

**Files:**
- `packages/desk_sdui_generator/test/register_for_sdui_test.dart`
- `packages/desk_sdui_generator/test/registration_diagnostic_test.dart`

Note: the test files themselves can keep the `register_for_sdui_test.dart` filename — renaming the file is a separate concern and breaks `git log` continuity. Inside the files, update `@RegisterForSdui([...])` source fixtures to `@Register([...])` and any string assertions.

If you prefer to also rename the test file for clarity, use `git mv register_for_sdui_test.dart register_test.dart` and update the import in any test runners. Either choice is fine; pick one and apply consistently.

---

## Task 5 — Demo catalog

**File:** `packages/desk_sdui_demo/lib/sdui_catalog.dart`

```diff
- @RegisterForSdui([
+ @Register([
    ...kCommonWidgets,
    ...kCommonMaterialWidgets,
    PageView,
    Cue,
    Act,
    CueMotion,
  ])
  class SduiCatalog {}
```

Same edit anywhere else in the demo where the annotation is applied.

---

## Task 6 — Regen + verify

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

Build succeeds. The generated `desk_sdui_setup.g.dart` should be byte-identical (or differ only in stable ordering) to the pre-rename version — the annotation name doesn't affect emission.

```
cd packages/desk_sdui_generator && dart analyze && dart test
```

All tests pass.

```
git grep -n 'RegisterForSdui' -- ':!*.g.dart' ':!.dart_tool/' ':!build/' ':!.plans/'
```

Empty (plan files allowed to reference old name in historical context).

---

## Out of scope

- Renaming `class SduiCatalog` (the demo carrier class). That's the catalog *carrier*; `@Register` is the *annotation*. Different concepts.
- Changing the annotation's signature (still takes `List<Type>`).
- Adding short import aliases. Devs handle name collisions per project.
