# desk_sdui — remove hardcoded `cue` import band-aid

**Goal:** The generator's `screen_generator.dart` currently emits a hardcoded `import 'package:cue/cue.dart';` in every generated `.sdui_reg.g.dart` file regardless of whether the screen actually uses `cue` types. This was a band-aid added during counter-demo work to keep builds passing. Replace with reachability-driven imports.

**Acceptance:**

1. Generated `.sdui_reg.g.dart` files import only the packages they actually reference (Flutter Material, optionally `cue`, etc.).
2. Demo regen: `build_runner build` produces clean output with no unused-import warnings on the `cue` line for screens that don't use cue.
3. A demo screen that DOES use `cue` types (`counter_bouncy`, `counter_burst`, `counter_record`) still gets the `cue` import.

---

## Task 1 — Audit the current import emission

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/screen_generator.dart`

Find the hardcoded `import 'package:cue/cue.dart';` line in the import block construction. Document why it was added (probably: `cue` types like `Cue`, `Act`, `CueMotion` appear in `kCommonWidgets`-adjacent code and the emitter's reachability walker didn't pick them up reliably).

---

## Task 2 — Replace with reachability-driven import

The emitter already computes the set of types reachable from the screen body. For each reachable type, determine its source package URI (`element.library.source.uri.toString()`) and add that package's `package:foo/foo.dart` to the import set.

Use `package_resolver` or read `element.library.uri` directly to extract the package name. Build an `imports: Set<String>` of `package:` URIs as the type collector runs. Emit one `import 'package:X/X.dart';` line per entry, sorted.

Drop the hardcoded `cue` line entirely.

If a screen references no `cue` types, no `cue` import is emitted. If it references `Cue.onChange`, the type collector sees `Cue` whose library is `package:cue/cue.dart`, and the import is included.

---

## Task 3 — Verify

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

For each generated `.sdui_reg.g.dart`:
- Screens that use cue (`counter_bouncy`, `counter_burst`, `counter_record`): must contain `import 'package:cue/cue.dart';`.
- Screens that don't (`counter_minimal`, `counter_stress`, etc.): must NOT contain that import.

```
dart analyze packages/desk_sdui_demo
```

Zero `unused_import` warnings on `cue` lines.

---

## Out of scope

- Generalizing import emission for value-type packages beyond `cue` (probably already works via the existing type-collector path; this plan only removes the hardcoded line and confirms the general path handles it).
- Sorting import block by directive type (`dart:`, `package:`, relative). Stable alphabetical sort within `package:` is sufficient.
- Removing other hardcoded imports in screen_generator.dart if any exist — handle them in the same pass if found.
