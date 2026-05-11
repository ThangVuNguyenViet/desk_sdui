# desk_sdui_generator — analyzer upgrade (v7 → v13)

**Goal:** Upgrade `desk_sdui_generator` to `analyzer ^13` + `analyzer_plugin ^0.14.9` + `source_gen ^4` + `build ^4` so it can lower any Dart 3.7+ pub package (e.g. `cue` uses dot-shorthand throughout its source).

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Branch state right now (already on disk, do NOT redo):**
- `packages/desk_sdui_generator/pubspec.yaml` — already bumped to `analyzer: ^13.0.0`, `analyzer_plugin: ^0.14.9`, `build: ^4.0.0`, `source_gen: ^4.0.0`, `build_runner: ^2.7.0`, `build_test: ^3.0.0`, `very_good_analysis: ^10.0.0`. `dart pub get` succeeds.
- `packages/desk_sdui_generator/test/golden/` — three golden snapshot files capturing today's chef IR + registrations (`.golden` extension). These are the byte-identical-diff reference for Task 5. **Do not commit them.**

**Empirical error baseline:** `cd packages/desk_sdui_generator && dart analyze` against the upgraded pubspec reports **70 errors** across 12 files. The complete list lives in `/tmp/analyzer8-probe/initial-analyze.txt` — read it first; it is the spec for what needs fixing.

**Acceptance:**
1. `dart analyze` clean for `desk_sdui_generator` (0 errors; 0 warnings; info-level OK).
2. `dart test` passes in `desk_sdui_generator`.
3. `cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs` succeeds AND produces output **byte-identical** to the goldens. (Diff in Task 5.)

---

## API mapping (empirical — derived from the 70 errors)

Replace **everywhere** in the generator + tests. This list is exhaustive for the errors observed.

### `source_gen` (TypeChecker)

| Removed | Replacement |
|---|---|
| `TypeChecker.fromRuntime(T)` | `TypeChecker.typeNamed(T, inPackage: 'desk_sdui_annotation')` |

8 call sites — both `Screen` and `RegisterForSdui` live in `package:desk_sdui_annotation/desk_sdui_annotation.dart`.

### Analyzer AST node property renames (un-renamed back from the v2 churn)

| Removed (was v2 suffix) | Replacement |
|---|---|
| `SimpleIdentifier.staticElement` | `.element` |
| `PrefixedIdentifier.staticElement` | `.element` |
| `ConstructorName.staticElement` | `.element` |
| `NamedType.name2` | `.name` |
| `FunctionDeclaration.declaredElement` | `.declaredFragment?.element` |

### Analyzer Element-model renames

| Removed | Replacement |
|---|---|
| `FunctionElement` | `TopLevelFunctionElement` (top-level @Screen) — adjust `is` checks and type-argument uses |
| `ParameterElement` | `FormalParameterElement` |
| `ConstructorElement.parameters` | `.formalParameters` |
| `MethodElement.parameters` | `.formalParameters` |
| `Element.enclosingElement3` | `.enclosingElement` (analyzer 13 reverted the `3` suffix) |
| `MethodElement.enclosingElement3` | `.enclosingElement` |
| `ConstructorElement.enclosingElement3` | `.enclosingElement` |
| `InterfaceType.lookUpMethod2` | `.lookUpMethod` |
| `InterfaceElement.accessors` | split into `.getters` and `.setters` — call sites need to combine or pick |
| `LibraryElement.source` | `.firstFragment.source` (LibraryElement no longer owns a source; fragments do) |
| `LibraryElement.importedLibraries` | iterate `.fragments` and accumulate `.importedLibraries` per fragment, OR use the `.firstFragment.importedLibraries` shortcut if a single fragment suffices for the call site |

### Analyzer `AnalysisContext` / `ResolvedLibraryResult`

| Removed | Replacement |
|---|---|
| `AnalysisSession.resolveFile2(...)` | `.resolveFile(...)` (alias removed; same signature) |
| `ResolvedLibraryResult.getElementDeclaration(elem)` | `.getFragmentDeclaration(fragment)` — pass the element's `firstFragment` instead of the element |

### Other

| Issue | Fix |
|---|---|
| `NamedExpression` not resolved as a type in `widget_lowerer.dart` / `missing_key_warning.dart` | Add `import 'package:analyzer/dart/ast/ast.dart';` (no longer re-exported transitively in 13) |
| `'Argument' can't be assigned to 'Expression'` in `closure_lowerer.dart` and `widget_lowerer.dart` | In analyzer 13, `FormalParameterList.parameters` returns `NodeList<FormalParameter>`, not `Expression`. Inspect the actual offending iteration — if the site is iterating positional args of a `MethodInvocation`, switch to `argumentList.arguments.cast<Expression>()`. If iterating params of a closure, restructure to expect `FormalParameter` and access its `name.lexeme` / `declaredFragment` |
| Null-receiver warnings on `isEmpty` / `isNotEmpty` / `.name` in `registration_emitter.dart` lines 92, 93, 122, 156 | Add `?` or `!` per the field's actual nullability. Do NOT silence; reason about each one. The receivers are element accessors that became nullable in v2. |

---

## Task 2 — TypeChecker.fromRuntime substitutions (8 sites)

**Files (literal grep-confirmed):**
- `packages/desk_sdui_generator/lib/src/builders.dart:13`
- `packages/desk_sdui_generator/lib/src/registry/registry_generator.dart:39-40`
- `packages/desk_sdui_generator/test/register_for_sdui_test.dart:79, 117, 149, 182, 245`

Every replacement is mechanical, exactly one of:

```dart
static const _checker =
    TypeChecker.typeNamed(Screen, inPackage: 'desk_sdui_annotation');

static const _coverageChecker =
    TypeChecker.typeNamed(RegisterForSdui, inPackage: 'desk_sdui_annotation');
```

Both targets are in `package:desk_sdui_annotation`.

---

## Task 3 — Element-model + AST renames (covers the bulk of the 70 errors)

Walk each affected file in this order. After each file, confirm its errors drop from the analyze report (a per-file `dart analyze lib/src/<file>.dart` works for quick feedback, but a full-package analyze is the source of truth).

Order (pick small files first to validate the mapping before tackling the big ones):

1. `lib/src/builders.dart` (TypeChecker — already handled in Task 2; should be 0 errors here after Task 2)
2. `lib/src/registry/registry_generator.dart` (TypeChecker only)
3. `lib/src/analyzer_plugin/rules/no_side_effects_in_screen.dart` (staticElement → element, 2 sites)
4. `lib/src/analyzer_plugin/rules/unregistered_symbol.dart` (name2 → name)
5. `lib/src/analyzer_plugin/rules/missing_key_warning.dart` (add NamedExpression import)
6. `lib/src/screen_lowering/closure_lowerer.dart` (Argument/Expression — read offending sites; likely a `.parameters` iteration that needs `FormalParameter` typing)
7. `lib/src/screen_lowering/widget_lowerer.dart` (NamedExpression import + Argument/Expression — same shape as closure_lowerer)
8. `lib/src/screen_lowering/screen_generator.dart` (FunctionElement → TopLevelFunctionElement, getElementDeclaration → getFragmentDeclaration, drop unused `element.dart` import)
9. `lib/src/type_collector.dart` (largest file — FunctionElement, declaredElement → declaredFragment?.element, staticElement → element, enclosingElement3 → enclosingElement, parameters → formalParameters, LibraryElement.source)
10. `lib/src/registration_emitter.dart` (parameters → formalParameters, enclosingElement3 → enclosingElement, ParameterElement → FormalParameterElement, FunctionElement → TopLevelFunctionElement, lookUpMethod2 → lookUpMethod, null-receiver fixups)

Then tests:

11. `test/register_for_sdui_test.dart` (TypeChecker.fromRuntime — same as Task 2; resolveFile2 → resolveFile)
12. `test/registration_emitter_test.dart` (resolveFile2, importedLibraries via fragments, accessors → getters/setters, enclosingElement3)
13. `test/screen_generator_registration_test.dart` (resolveFile2)
14. `test/type_collector_test.dart` (resolveFile2, enclosingElement3 → enclosingElement, null-access fixup on line 205)

**Stopping rules:**
- If the analyzer reports an error you don't see in the mapping table above, STOP. Do not improvise. Add a note describing the new error to the plan and proceed only after the table is updated.
- The goal is renames + import fixes — **NOT semantic refactoring.** Behavior must not change. If a v2 API requires you to restructure logic (not just rename), surface it.

---

## Task 4 — Add `DotShorthandPropertyAccess` / `DotShorthandInvocation` handlers (optional but cheap)

This is only strictly required by the cue example (`.plans/desk-sdui-cue-example.md`), not the analyzer upgrade itself. **Skip this task if chef IR remains byte-identical at Task 5 without it** — that means the existing screens don't use dot-shorthand. The cue example plan can add the handlers when it lands.

If you do add them: extend `lib/src/screen_lowering/expression_lowerer.dart` with two new `if (expr is X)` branches mirroring the existing `PropertyAccess` / `MethodInvocation` handling, but using the resolved context type (`expr.staticType.element.name`) as the qualifier. Skipping for now is acceptable.

---

## Task 5 — Verify

**Step 1 — Analyze**

```
cd packages/desk_sdui_generator && dart analyze
```

Expected: 0 errors, 0 warnings. (Info-level deprecations OK if any remain.)

**Step 2 — Tests**

```
dart test
```

Expected: all pass.

**Step 3 — Regenerate the demo**

```
cd ../desk_sdui_demo
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: succeeds without crashing.

**Step 4 — Byte-identical IR diff against the goldens**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
diff packages/desk_sdui_demo/lib/screens/chef.sdui.g.dart \
     packages/desk_sdui_generator/test/golden/chef.sdui.g.dart.golden
diff packages/desk_sdui_demo/lib/screens/chef.sdui_reg.g.dart \
     packages/desk_sdui_generator/test/golden/chef.sdui_reg.g.dart.golden
diff packages/desk_sdui_demo/lib/desk_sdui_setup.g.dart \
     packages/desk_sdui_generator/test/golden/desk_sdui_setup.g.dart.golden
```

Expected: zero diff. (Whitespace-only diff is acceptable if dart_style shifted.) A structural diff is a **stop signal** — investigate before committing.

**Step 5 — Full downstream sanity**

```
cd packages/desk_sdui_demo && flutter analyze && flutter test
cd ../desk_sdui            && dart analyze && dart test
cd ../desk_sdui_annotation && dart analyze && dart test
```

**Step 6 — Commit + cleanup**

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
rm -rf packages/desk_sdui_generator/test/golden
git add packages/desk_sdui_generator/ packages/desk_sdui_demo/ pubspec.yaml
git commit -m "feat(generator): upgrade to analyzer ^13"
```

---

## Out of scope

- Behavior changes. Pure tooling upgrade.
- New AST handlers for cue (Task 4 above is optional; the cue plan owns that if it isn't trivially free here).
- The cue example retry — separate plan (`desk-sdui-cue-example.md`).
