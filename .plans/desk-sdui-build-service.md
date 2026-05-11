# desk_sdui — remote Dart→IR build service

**Goal:** A sandboxed runner that takes a Dart `@Screen` function (plus its data model class and a `@RegisterForSdui` declaration) and returns the corresponding `.sdui.json` IR. Invocable from any non-Dart-SDK caller.

**Why:** `build_runner` + analyzer + pub need the full Dart SDK — not shippable inside a Flutter web/mobile app. To expose desk_sdui's Dart→IR pipeline to designer tools, CI scripts, LLM-driven authoring tools, or any other caller without a local Dart SDK, codegen has to run elsewhere.

**Architecture:** Docker container with a pre-built template Dart project (pubspec resolved, `.dart_tool/` warm). For each request the runner writes the caller's Dart sources into the template, runs `dart run build_runner build`, returns the resulting `.sdui.json` or structured build errors. Invocation transport (HTTP, CLI-over-SSH, local subprocess, FaaS trigger) is a deployment choice — out of scope here.

**Prereq:** Bundles + diagnostic merged into main (at `f720e91`). This provides the build-time `@RegisterForSdui` catalog enforcement that gives the service its safety story.

**Repo:** new sub-project `dart_desk_workspace/dart_desk_cloud/builder_service/`.

**Acceptance:**

1. Given a valid Dart `@Screen` source, the service returns the same IR that an in-tree `build_runner` invocation would produce. Byte-identical against a golden produced from a local build of the same Dart source.
2. Given Dart that references an unregistered widget, the service returns a structured error naming the screen and the missing widget (the same diagnostic the bundles plan added).
3. Given Dart with an analyzer error, the service returns structured analyzer diagnostics, not a stack trace.
4. A `@Screen` body that tries `Process.run('rm', ['-rf', '/'])` cannot affect the host or other concurrent requests.

---

## Task 1 — Build the sandboxed runner

A standalone CLI binary that reads a request payload from stdin and writes a response payload to stdout. No transport layer. Each invocation runs to completion inside one Docker container.

**Files:**
- `dart_desk_cloud/builder_service/Dockerfile`
- `dart_desk_cloud/builder_service/template_project/` (pubspec + build.yaml, deps pre-resolved at image-build time)
- `dart_desk_cloud/builder_service/bin/run.dart` (the binary that reads stdin → writes response to stdout)

The Dockerfile bakes `dart pub get` into the image so steady-state requests skip pub resolution. The runner writes the caller's Dart into the template's `lib/`, shells out to `dart run build_runner build`, parses the result, prints the response, exits.

**Verify:** a smoke test invokes the binary with a known-good Dart source and asserts the IR matches a golden produced by the in-tree `build_runner` on the same input.

---

## Task 2 — Transport wrapper (deferred; pick when there's a real caller)

Wrapping the Task-1 binary as an HTTP service, a Cloud Run handler, a CLI-over-SSH endpoint, or whatever is needed by the first real integration is a small wrapper. Defer the choice until we know the first caller. The binary itself is the substrate; the transport is a thin shell.

---

## Task 3 — End-to-end check from the demo

After Task 1 lands, validate the substrate by:
1. Hand-writing a Dart `@Screen` source.
2. Running it through the runner.
3. Diffing the resulting IR against an in-tree `build_runner` output for the same source.

Expected: byte-identical. If not, the runner is producing different IR from the canonical pipeline and the bug must be fixed before any caller integrates.

---

## Out of scope

- Transport. Pick when there's a real caller; the Task-1 binary is invocation-shape-agnostic.
- LLM integration. The service is caller-agnostic; LLM is one possible caller among many. Whoever wants LLM-driven authoring writes their own wrapper around the runner.
- Per-language client libraries. The request/response is a small JSON envelope; clients are trivial to write per language.
- Per-request `pubspec.yaml` overrides. v0 ships with a fixed dependency set baked into the image. Upgrading deps = redeploy.
- Multi-screen / multi-file composition. One `@Screen` per request.
- Hot-reload. Every request is a full build.

## Open questions

1. **Dependency surface.** Which packages should the template `pubspec.yaml` include? Minimum: desk_sdui, desk_sdui_annotation, desk_sdui_generator, flutter. Likely also: cue, shadcn_ui, common animation/layout libs. Decide based on the first real caller's catalog.
2. **`.dart_tool/` warming across requests.** Worker reuse vs. fresh container per request — Task 2 problem, not Task 1.
3. **The generator's hardcoded `cue` import** (band-aid from the counter-demo plan). The runner inherits it; harmless for cue-using callers, but ugly. Cleanup is queued as a separate todo.
