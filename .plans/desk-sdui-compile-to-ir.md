# desk_sdui — expose `compileToIr` from the generator package

**Goal:** Add a top-level function to the existing `desk_sdui_generator` package that takes a Dart source string and returns the corresponding `.sdui.json` IR (or structured build errors). No new package. No CLI. No transport. The server just imports `desk_sdui_generator` and calls the function.

```dart
import 'package:desk_sdui_generator/desk_sdui_generator.dart';

final result = await compileToIr(
  screenSource: '@Screen("counter") Widget counter(D d) => Text("${d.value}");',
  dataModelSource: 'class D { final int value; const D(this.value); }',
  catalogSource: '@RegisterForSdui([Text]) class _C {}',
);

switch (result) {
  case CompileSuccess(:final ir):     // Map<String, Object?>
  case CompileFailure(:final errors): // List<CompileError>
}
```

**Why:** The generator already implements Dart → IR via `source_gen`. The only reason `build_runner` is involved today is asset wiring. A server that already runs Dart can skip `build_runner` entirely and invoke the lowering pass directly. Shipping this as a function on the existing package is strictly less surface than a new package or CLI.

**Prereq:** Bundles + diagnostic merged into main. Generator analyzes clean, all tests pass.

**Acceptance:**

1. `compileToIr(screenSource: <valid>)` returns an IR byte-identical to what an in-tree `build_runner` invocation produces for the same source.
2. `compileToIr(screenSource: <references unregistered widget>)` returns `CompileFailure` with structured errors naming the screen and the missing widget.
3. `compileToIr(screenSource: <analyzer error>)` returns `CompileFailure` with structured analyzer diagnostics.
4. Adds zero new dependencies to `desk_sdui_generator`.

---

## Task 1 — Extract the lowering pass from its `BuildStep` harness

The existing `desk_sdui_generator` has a `Generator` subclass whose `generate(LibraryReader, BuildStep)` is the entry point invoked by `build_runner`. The `BuildStep` is used for asset I/O, neighbor reading, and progress logs.

**Step 1 — Audit the `BuildStep` usage** inside the lowering pass. Map each call site to:
- **Asset I/O** (`buildStep.writeAsString`, `buildStep.readAsString`) — restructure so the lowering returns a value instead of writing.
- **Resolution** (`buildStep.resolver.libraryFor`) — replace with a direct `AnalysisContext` lookup.
- **Logging** — keep, route through a `Logger` field passed in.

**Step 2 — Refactor.** Extract the lowering into a pure function that takes a resolved `LibraryElement` and returns an `IrResult` value. The existing `Generator.generate` wrapper becomes a thin adapter that calls the pure function and writes the result via `BuildStep`. The `build_runner` path is unchanged; the new pure function becomes the substrate for `compileToIr`.

**Step 3 — Verify** existing tests still pass and the demo regen byte-identical:

```
cd packages/desk_sdui_generator && dart analyze && dart test
cd ../desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
git diff --stat -- 'packages/desk_sdui_demo/lib/screens/*.sdui.g.dart'
```

Expected: zero diff.

---

## Task 2 — Implement `compileToIr`

Public entry point in `packages/desk_sdui_generator/lib/desk_sdui_generator.dart`:

```dart
Future<CompileResult> compileToIr({
  required String screenSource,
  String? dataModelSource,
  String? catalogSource,
});
```

Internals:

1. Write the source strings into an in-memory `OverlayResourceProvider` rooted at a synthetic path.
2. Construct an `AnalysisContext` over that overlay (re-using the host's `package_config.json` — analyzer auto-discovers it).
3. Resolve the synthetic library.
4. Invoke the pure lowering function from Task 1.
5. Return `CompileSuccess(ir: ...)` or `CompileFailure(errors: ...)`.

**Verify:**
- Known-good source → IR matches a golden produced by `build_runner` on the same input.
- Unregistered widget → structured `CompileFailure` with expected message.
- Syntax error → structured analyzer diagnostics.

---

## Task 3 — Document the host pattern

Add a `## Server-side compilation` section to `packages/desk_sdui_generator/README.md` showing the `compileToIr` call. ~30 lines. No CLI, no scaffolded "starter" server.

---

## Out of scope

- A new package. The function lives in `desk_sdui_generator` because that's where the lowering already is.
- A CLI. Anyone wanting one writes ~30 lines against the function.
- Sandboxing. Host concern.
- Per-call dependency overrides. The host's pubspec is the dependency surface.
- Multi-screen / multi-file requests.

## Open questions

1. **Does the existing `BuildStep`-coupled generator depend on `build_runner`'s caching, or is it purely transient state?** If transient, Task 1 is mechanical. If there's caching coupling, surface it during the audit.
2. **`AnalysisContextCollection` with an overlay** — has to find the host's `package_config.json` to resolve `package:desk_sdui_annotation/...`. Confirm this works when called from a host that declares `desk_sdui_generator` as a dependency.
3. **Generator's hardcoded `cue` import band-aid** still rides on this. Cleanup queued separately.
