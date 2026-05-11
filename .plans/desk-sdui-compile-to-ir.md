# desk_sdui — `compileToIr` package

**Goal:** Ship a Dart package that exposes a single function: given a Dart `@Screen` source string (plus its data model class and a `@RegisterForSdui` declaration), return the resulting `.sdui.json` IR or a structured list of build errors.

```dart
import 'package:desk_sdui_build/desk_sdui_build.dart';

final result = await compileToIr(
  screenSource: '@Screen("counter") Widget counter(D d) => Text("${d.value}");',
  dataModelSource: 'class D { final int value; const D(this.value); }',
  coverageSource: '@RegisterForSdui([Text]) class _C {}',
);

switch (result) {
  case CompileSuccess(:final ir):     // Map<String, Object?> = the IR JSON
  case CompileFailure(:final errors): // List<CompileError>
}
```

**Why:** `build_runner` needs the full Dart SDK and a project on disk — it can't run inside a Flutter web/mobile app. By shipping the compile as a plain Dart function, any Dart-capable host (server, CLI, CI script, Cloud Function, designer tool backend) can use desk_sdui's Dart→IR pipeline without inventing its own protocol.

**Out of our scope:** how the host invokes this function (HTTP handler / CLI binary / subprocess / FaaS handler), how the host sandboxes untrusted callers, how the host authenticates, how the host scales. Those are deploy-shape choices that vary per integration.

**Prereq:** Bundles + diagnostic merged into main (at `f720e91`).

**Repo:** new package `packages/desk_sdui_build/` inside `desk_sdui`.

**Acceptance:**

1. `compileToIr(screenSource: <valid>)` returns an IR byte-identical to what an in-tree `build_runner` invocation produces for the same source.
2. `compileToIr(screenSource: <references unregistered widget>)` returns `CompileFailure` with structured errors naming the screen and the missing widget.
3. `compileToIr(screenSource: <analyzer error>)` returns `CompileFailure` with structured analyzer diagnostics.
4. The function is self-contained: no network, no env-var requirements, no caller-provided pubspec. The host imports the package and calls the function.

---

## Task 1 — Pick the implementation path

Two viable approaches; pick one based on a 30-minute spike.

**Path A: subprocess `build_runner`.** Function writes the caller's sources into a temp directory containing a pre-baked template project (bundled as package assets), spawns `dart run build_runner build`, reads the IR from disk, returns. Pros: trivially correct — same pipeline as today. Cons: slow (~1-3s per call), requires a Dart SDK on PATH at runtime.

**Path B: direct lowering via `analyzer` + `source_gen`.** Function constructs an in-memory `AnalysisContext` over the caller's Dart source, hands the resolved library to the existing generator's `Generator` subclass, returns the produced IR. Pros: fast (~100ms), no subprocess, no SDK on PATH. Cons: requires extracting the generator's lowering pass from its `BuildStep` harness; analyzer needs a synthesized package_config + Flutter SDK pointer.

**Spike step:** in the existing generator, find where `Generator.generate(LibraryReader, BuildStep)` is called. Confirm whether the `BuildStep` is used for anything beyond resolving the library (writing outputs, reading neighbors, etc.). If it's just library resolution + emit, Path B is feasible. Otherwise default to Path A.

Commit the spike finding as a one-paragraph addendum to this plan, then proceed.

---

## Task 2 — Implement

`packages/desk_sdui_build/lib/desk_sdui_build.dart` exposes `compileToIr` and the `CompileResult` / `CompileSuccess` / `CompileFailure` / `CompileError` types. Internals follow whichever path Task 1 selected.

**Tests:**
- A known-good source → asserts the returned IR matches a golden produced by the in-tree `build_runner` pipeline on the same input.
- Unregistered-widget source → asserts the structured diagnostic.
- Analyzer-error source → asserts structured analyzer diagnostics.

**Verify:** `cd packages/desk_sdui_build && dart analyze && dart test` clean.

---

## Out of scope

- Any transport (HTTP, gRPC, CLI). The host decides.
- Any sandboxing. The host decides.
- Per-call dependency overrides. v0 bundles a fixed dependency set (desk_sdui + flutter + the common widget libs). Callers needing more reach modify the package's bundled template (Path A) or extend the synthesized package_config (Path B), then re-publish.
- Multi-screen / multi-file requests. One `@Screen` per call.
- Streaming or partial results. The IR is whole-document.

## Open questions

1. **Flutter SDK requirement.** Both paths likely need Flutter on the host (analyzer must resolve `package:flutter/widgets.dart`). If Path B turns out to need an env-var or a hardcoded path, document the requirement.
2. **Generator's hardcoded `cue` import** (band-aid from the counter-demo plan). The package inherits it. Cleanup is queued separately.
3. **Memory pressure.** Each `compileToIr` call on Path B holds an `AnalysisContext` in memory. If the host is a long-running server, contexts should be pooled or recycled. v0 leaves it to the host.
