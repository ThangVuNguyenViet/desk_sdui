# desk_sdui — `coverage` → `catalog` mechanical rename

**Goal:** Rename the user-facing concept "coverage" to "catalog" everywhere it appears (code, generated symbols, test fixtures, doc comments). `@RegisterForSdui` declares a *widget catalog*, not a "coverage block." The name "coverage" is leaking compiler-test-suite terminology.

The annotation `@RegisterForSdui` itself does NOT rename. Only the noun "coverage" — internal field names, helper symbols, generated function names — changes.

**Rename mapping (apply globally):**

| Old | New |
|---|---|
| `coverageTypes` (variable, parameter) | `catalogTypes` |
| `_coverageChecker` | `_catalogChecker` |
| `coverageSource` (test fixtures) | `catalogSource` |
| `coverageBlock`, `coverageCall` (emitter locals) | `catalogBlock`, `catalogCall` |
| `_emitCoverageBlock` | `_emitCatalogBlock` |
| `registerSduiCoverage` (emitted function name) | `registerSduiCatalog` |
| `SduiCoverage` (demo carrier class) | `SduiCatalog` |
| `sdui_coverage.dart` (demo file) | `sdui_catalog.dart` |
| Doc comments mentioning "coverage block", "coverage check", "coverage annotation" | "catalog block" / "catalog check" / "catalog annotation" |

**Acceptance:**

1. `grep -rn 'coverage\|Coverage' packages/ --include='*.dart' | grep -v '/.dart_tool/' | grep -v 'build/'` returns zero matches except inside `.g.dart` files which regenerate fresh.
2. `cd packages/desk_sdui_generator && dart analyze && dart test` passes.
3. `cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs` succeeds.
4. `git grep -l SduiCoverage` returns nothing; `git grep -l SduiCatalog` returns the renamed demo file.
5. Generated `desk_sdui_setup.g.dart` contains `void registerSduiCatalog(Runtime rt)` and `registerSduiCatalog(rt);`.

---

## Task 1 — Code rename in generator

Files:
- `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart`

Apply the mapping above. Local variables, private symbol names, emitted code strings. The emitted function `registerSduiCoverage` becomes `registerSduiCatalog`.

Also update doc comments referencing "coverage block" / "coverage check" / "coverage annotation".

---

## Task 2 — Code rename in annotation package doc comments

Files:
- `packages/desk_sdui_annotation/lib/src/annotations.dart`

The dartdoc on `@RegisterForSdui` references `_SduiCoverage` as the example sentinel class. Update example to `_SduiCatalog`. Update prose describing what `registerSduiCoverage` is emitted to use the new name.

---

## Task 3 — Test fixtures

Files:
- `packages/desk_sdui_generator/test/register_for_sdui_test.dart`
- `packages/desk_sdui_generator/test/registration_diagnostic_test.dart`

Rename `coverageSource` → `catalogSource`, `coverageTypes` → `catalogTypes` in test bodies. Update string assertions: `'registerSduiCoverage'` → `'registerSduiCatalog'`. Update test names/descriptions that say "coverage" to say "catalog".

---

## Task 4 — Demo file rename

Files:
- Rename: `packages/desk_sdui_demo/lib/sdui_coverage.dart` → `packages/desk_sdui_demo/lib/sdui_catalog.dart`
- Class inside: `class SduiCoverage {}` → `class SduiCatalog {}`

Use `git mv` so history is preserved.

The file is referenced by build_runner only via annotation discovery; no explicit imports point to it. Confirm with `grep -rn 'sdui_coverage\|SduiCoverage' packages/desk_sdui_demo/lib/`. After rename, both grep terms should return zero hits except inside generated `.g.dart` files (which will regenerate to the new name).

---

## Task 5 — Regen + verify

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
grep registerSduiCatalog lib/desk_sdui_setup.g.dart   # must hit
grep registerSduiCoverage lib/desk_sdui_setup.g.dart  # must miss
dart analyze
```

```
cd packages/desk_sdui_generator && dart test
```

All tests pass.

```
git grep -n 'coverage\|Coverage' packages/ -- ':!*.g.dart' ':!build/' ':!.dart_tool/'
```

Empty.

---

## Out of scope

- Renaming `@RegisterForSdui` itself (it's the right name).
- Renaming `CollectedTypes` or `collectTypesFromAnnotation` (these are about the data type, not the carrier-class concept).
- Renaming the analyzer plugin's `unregistered_symbol` rule (still accurate).
