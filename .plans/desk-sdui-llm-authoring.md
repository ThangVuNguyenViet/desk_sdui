# desk_sdui — LLM-authored screens via Dart codegen

**Goal:** Let an LLM produce `.sdui.json` IR by writing Dart `@Screen` functions instead of emitting IR JSON directly. The existing build pipeline (`build_runner` + generator) turns LLM-emitted Dart into IR. Dart's type system + `@RegisterForSdui` diagnostic + analyzer become the compile-time validator for LLM output, replacing JSON Schema as the contract.

**Why this shape:** LLMs are fluent in Dart/Flutter (training data is enormous) and weak at arbitrary discriminated-union JSON. Their natural failure mode in JSON-emission is hallucinating field names; in Dart-emission it's hallucinating identifiers — which the Dart compiler catches immediately. By making Dart the LLM's output language, we trade "design a JSON Schema for every widget" for "let the compiler enforce the catalog."

**Strategic positioning:** This is NOT a replacement for genui's runtime conversational UI. It's a designer/dev *authoring* tool: chat produces a shippable static `.sdui.json` deliverable. Closer to "Copilot for SDUI screens" than "Cursor-as-end-user-UI."

**Architecture (three components):**

```
┌─────────────────────────┐
│  desk_sdui_compose      │  ← Dart pkg. Owns LLM prompting, catalog
│  (LLM wrapper library)  │     introspection, retry loop, error reformat.
└──────────┬──────────────┘
           │ POST /build {dartSource, ...}
           ▼
┌─────────────────────────┐
│  Builder service        │  ← Web service. Sandboxed Dart project +
│  (sandboxed codegen)    │     build_runner. In: Dart string. Out: IR or errors.
└──────────┬──────────────┘
           │
           ▼
       .sdui.json
```

Component 1 issues HTTP calls to component 2. Component 3 ("error-feedback loop") is the orchestration *inside* `ScreenComposer.compose` that turns builder-service errors into the LLM's next-turn input. It is not a separate package — it's the spec for how 1 and 2 talk to each other.

**Prereq:** Bundles + diagnostic plan landed (provides the compiler-level catalog enforcement this design depends on).

**Repos:**
- Component 1: new package `packages/desk_sdui_compose/` inside the `desk_sdui` repo.
- Component 2: new repo or sub-project — likely `dart_desk_workspace/dart_desk_cloud/builder_service/` (matches the existing cloud sub-project).
- Component 4 (example): `packages/desk_sdui_compose/example/`.

**Acceptance:**
1. `dart run desk_sdui_compose:cli --prompt "a counter screen with a big number and an increment button"` prints a valid `.sdui.json` that the existing runtime can render.
2. When the LLM emits Dart referencing an unregistered widget, the loop iterates with the analyzer error and converges within 3 retries (90%+ of the time on a small benchmark of 20 prompts).
3. The builder service is sandboxed (no arbitrary code execution leaks to host). Demonstrated by attempting `Process.run('rm', ['-rf', '/'])` inside a `@Screen` body and confirming it's contained.
4. End-to-end latency under 10s for the cold case, under 3s for the warm-pool case.

---

## Task 1 — Design spike: builder service API + sandbox choice

This task picks the sandboxing strategy. No implementation yet — design only.

**Files:**
- Create: `packages/desk_sdui_compose/SERVICE_API.md` (specifies the HTTP contract)
- Create: `packages/desk_sdui_compose/SANDBOX.md` (documents the sandbox decision + rejected alternatives)

**Step 1 — Lock the HTTP contract.** The minimum viable shape:

```
POST /build
Content-Type: application/json

{
  "screenSource": "@Screen('counter') Widget counter(CounterData d) => Column(...);",
  "dataModelSource": "class CounterData { final int value; const CounterData(this.value); }",
  "coverageSource": "@RegisterForSdui([...kCommonWidgets]) class _C {}",
  "extraImports": [
    "package:desk_sdui_annotation/desk_sdui_annotation.dart",
    "package:desk_sdui/widget_bundles.dart",
    "package:flutter/material.dart"
  ],
  "deskSduiVersion": "^0.4.0"
}

→ 200 OK
{
  "screenName": "counter",
  "ir": { ... whole .sdui.json contents ... },
  "registrations": ["Column", "Text", "Container"]
}

→ 400 Build Failed
{
  "stage": "analyze" | "lower" | "build_runner",
  "errors": [
    {
      "severity": "error",
      "file": "input.dart",
      "line": 5,
      "column": 12,
      "message": "Undefined name 'ShadFancyButton'. Available registered widgets: ElevatedButton, TextButton, OutlinedButton."
    }
  ]
}
```

**Step 2 — Pick the sandbox.** Evaluate three options:

| Option | Cold start | Steady state | Security | Effort |
|---|---|---|---|---|
| Docker container per request | ~5s | Slow | Strong (kernel isolation) | Low |
| Persistent Docker worker pool | ~5s once | ~1s | Strong | Medium |
| Firecracker microVM | ~200ms | <1s | Strong | High |
| `dart compile` + seccomp jail | <100ms | <1s | Brittle | High + risky |

**Recommendation:** persistent Docker worker pool. Each worker has a template Dart project (`pubspec.yaml` with desk_sdui + flutter + cue + shadcn_ui + common deps) with `.dart_tool/` pre-warmed. Request handler:
1. Pick a free worker.
2. `cat > lib/screen.dart` with the user's Dart source.
3. Run `dart run build_runner build --delete-conflicting-outputs`.
4. Read `lib/screen.sdui.json`, return.
5. Reset the worker (delete `lib/screen.dart`, leave `.dart_tool/` warm).

Reject Firecracker (too much infra for v0) and seccomp jail (too brittle — Dart needs filesystem + spawn for build_runner).

**Step 3 — Capacity sizing.** One worker = ~200MB RAM with pre-warmed `.dart_tool/`. Plan for 10 workers per service instance, autoscale on queue depth.

**Step 4 — Commit** `SERVICE_API.md` + `SANDBOX.md`. No code yet.

---

## Task 2 — Build the sandboxed builder service

**Files:**
- Create: `dart_desk_cloud/builder_service/` (new sub-project)
- Inside: `Dockerfile`, `template_project/` (Dart project skeleton), `bin/server.dart` (HTTP entry), `lib/worker_pool.dart`, `lib/build_runner_invoker.dart`.

**Step 1 — Template project.** A minimal Dart project at `template_project/`:

```
template_project/
├── pubspec.yaml      # desk_sdui + desk_sdui_annotation + desk_sdui_generator + flutter + common deps
├── lib/
│   └── (screen.dart, data_model.dart, coverage.dart written per-request)
└── build.yaml        # configures desk_sdui_generator
```

`dart pub get` at image build time. `.dart_tool/` lives inside the image.

**Step 2 — HTTP server.** Use `shelf` + `shelf_router`:

```dart
final router = Router()
  ..post('/build', _build)
  ..get('/health', _health);

Future<Response> _build(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, Object?>;
  final worker = await pool.acquire();
  try {
    final result = await worker.build(
      screenSource: body['screenSource'] as String,
      dataModelSource: body['dataModelSource'] as String,
      coverageSource: body['coverageSource'] as String,
    );
    return Response.ok(jsonEncode(result.toJson()), headers: _jsonHeaders);
  } on BuildFailure catch (e) {
    return Response(400, body: jsonEncode(e.toJson()), headers: _jsonHeaders);
  } finally {
    pool.release(worker);
  }
}
```

**Step 3 — Worker pool.** Simple semaphore-bounded pool with reset-on-release. Workers are just paths to per-worker directories cloned from `template_project/`.

**Step 4 — Build invoker.** Shell out to `dart run build_runner build --delete-conflicting-outputs`, capture stdout/stderr, parse for errors. Read the resulting `.sdui.json` from disk.

Error parsing is the messy bit: `build_runner` output mixes analyzer diagnostics, generator stack traces, and progress logs. Extract diagnostics structured (the JSON `--define` flag for source_gen may help; otherwise regex on the analyzer's standard error format).

**Step 5 — Smoke test.** A `bin/smoketest.dart` that runs a known-good prompt end-to-end and asserts the returned IR matches a golden. Useful for CI and for capacity tuning.

**Step 6 — Containerize.** `Dockerfile` based on `dart:stable`, copies template, runs `dart pub get`, exposes :8080.

**Step 7 — Deploy target.** Cloud Run / Fly.io / equivalent. Defer infra choice to whatever `dart_desk_cloud/` already uses.

---

## Task 3 — Build `desk_sdui_compose` (the LLM wrapper)

**Files:**
- Create: `packages/desk_sdui_compose/`
- Inside: `lib/desk_sdui_compose.dart` (barrel), `lib/src/screen_composer.dart`, `lib/src/llm/llm.dart` (abstract LLM interface), `lib/src/llm/gemini_adapter.dart`, `lib/src/llm/claude_adapter.dart`, `lib/src/builder_client.dart`, `lib/src/system_prompt.dart`, `bin/cli.dart`.

**Step 1 — `LlmAdapter` interface.** Minimal abstraction:

```dart
abstract interface class LlmAdapter {
  Future<String> generate({
    required String systemPrompt,
    required List<LlmTurn> history,
    required String userPrompt,
  });
}

class LlmTurn {
  const LlmTurn({required this.role, required this.content});
  final LlmRole role; // user, assistant
  final String content;
}
```

Provide 2 concrete adapters (Gemini, Claude). Both stream-or-await; expose only the await form for v0.

**Step 2 — System prompt builder.** Composes a prompt from:
- Catalog list (e.g. `[Column, Row, Stack, Text, ElevatedButton, ...]`) — passed as a `List<String>` of widget names from the host's `@RegisterForSdui`.
- Data shape (Dart class source as a string).
- Lowerer constraints (currently: must use arrow-body `=>`, no `~/`, no parenthesized expressions, no block bodies). This list grows/shrinks as the lowerer evolves — keep it in `lib/src/lowerer_caveats.dart`.

Example output:

```
You are writing a Flutter @Screen function for the desk_sdui codegen pipeline.

CONSTRAINTS:
- The function MUST use arrow-body syntax (Widget foo(D d) => ...).
- The function body MUST NOT use: integer division (~/), parenthesized expressions, block-body statements.
- You may only use these widgets: Column, Row, Stack, Text, ElevatedButton, ...
- The data parameter has this shape:
  class CounterData { final int value; final String title; }

OUTPUT FORMAT: A single Dart code block containing the @Screen function. No commentary.
```

**Step 3 — `ScreenComposer`.** The main entry point:

```dart
class ScreenComposer {
  ScreenComposer({
    required this.builderClient,
    required this.llm,
    required this.catalog,    // List<String> widget names
    this.maxRetries = 3,
  });

  final BuilderClient builderClient;
  final LlmAdapter llm;
  final List<String> catalog;
  final int maxRetries;

  Future<ComposeResult> compose({
    required String prompt,
    required String dataModelSource,
  }) async {
    final history = <LlmTurn>[];
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final dartSource = await llm.generate(
        systemPrompt: buildSystemPrompt(catalog: catalog, dataModelSource: dataModelSource),
        history: history,
        userPrompt: attempt == 0 ? prompt : 'The build failed. Errors:\n${history.last.content}\nFix the code.',
      );
      final extracted = extractDartBlock(dartSource);
      try {
        final ir = await builderClient.build(screenSource: extracted, dataModelSource: dataModelSource, /* ... */);
        return ComposeSuccess(ir: ir, dartSource: extracted, attempts: attempt + 1);
      } on BuildFailure catch (e) {
        history.add(LlmTurn(role: LlmRole.assistant, content: extracted));
        history.add(LlmTurn(role: LlmRole.user, content: e.toLlmFeedback()));
      }
    }
    return ComposeFailed(attempts: history);
  }
}
```

**Step 4 — `BuilderClient`.** Thin HTTP wrapper over the Task 2 service. Just `http.post` with JSON in/out + typed error class.

**Step 5 — CLI.** `bin/cli.dart` reads `--prompt`, `--data-model` (path to a Dart file), `--catalog` (comma-separated widget names or path to a coverage file), prints the resulting IR JSON.

```
dart run desk_sdui_compose:cli \
  --prompt "a counter screen with a big number and an increment button" \
  --data-model example/counter_data.dart \
  --catalog example/coverage.dart
```

**Step 6 — Test.** Mock `BuilderClient` + `LlmAdapter`; assert the retry loop fires on failures and the final result is propagated correctly. A separate integration test (gated by an env var) hits a real LLM + a localhost builder service.

---

## Task 4 — End-to-end example

**Files:**
- Create: `packages/desk_sdui_compose/example/`
- Inside: `lib/main.dart` (renders the LLM-generated IR via the existing `desk_sdui` runtime), `lib/coverage.dart` (the example's `@RegisterForSdui` list), `bin/generate.dart` (CLI script that runs the composer and writes `assets/counter.sdui.json`).

**Step 1 — Generate a screen.**

```
cd packages/desk_sdui_compose/example
dart run bin/generate.dart --prompt "counter with big number" --output assets/counter.sdui.json
```

**Step 2 — Render it.** `lib/main.dart` loads the JSON from assets, mounts the runtime, displays the screen. No codegen for *this* screen — it came from the LLM at generate-time, not at build-time.

**Step 3 — Demo loop.** Add a second prompt: "make the number purple." Re-run the generator. Reload the app. Watch the screen update without a Dart rebuild for the screen itself.

---

## Task 5 — Verify + commit

**Step 1 — Sanity:**

```
cd packages/desk_sdui_compose && dart analyze && dart test
cd ../desk_sdui_compose/example && flutter analyze && flutter test
cd ../../../dart_desk_cloud/builder_service && dart analyze && dart test
```

**Step 2 — Manual end-to-end:** start the builder service locally, run the CLI, inspect the output IR, render it in the example app.

**Step 3 — Commit:**

```
git add -A && git commit -m "feat: LLM-authored screens via Dart codegen (desk_sdui_compose + builder service)"
```

---

## Out of scope

- Multi-screen / multi-file composition. v0 is one `@Screen` function per request.
- Streaming responses from the builder service. The IR is a whole-document deliverable; streaming buys nothing here.
- LLM-driven *data model* generation. The data shape is an input; the LLM only writes the screen body.
- Hot-reload-style live preview during composition. Each iteration is a full build; that's the cost of compile-time guarantees.
- Auth / multi-tenancy / billing for the builder service. v0 is single-tenant, dev-only.
- LLM-emitted IR JSON as a fallback. We bet on Dart-only; if it doesn't work, that's the design failure, not a path to keep open.

## Open questions

1. **How much catalog context fits in the LLM's system prompt?** Bundles plan lists ~70 widgets. With shadcn_ui or material extras added, 200+. At what point do we need to chunk the catalog or use retrieval?
2. **Is `extractDartBlock` robust enough?** LLMs sometimes emit prose around code, sometimes nest code in markdown, sometimes wrap in `<dart>` tags. Need a parser that's tolerant of all three.
3. **What happens when the LLM hallucinates a widget that's in the catalog but with a misspelled name (`ElavatedButton`)?** Build error → retry loop → LLM probably fixes it. But: should the system prompt include known close-spelling traps? Probably not until empirical data shows it's a problem.
4. **Multi-turn refinement UX.** Beyond build-error retries, the user might want "make the button blue" after a successful build. Does the next prompt start fresh or append to history? v0: start fresh. Defer the conversational refinement story.
5. **How does this interact with the augmentations plan (currently blocked)?** It doesn't — augmentations is an internal codegen-emission change. LLM-authored Dart doesn't care whether the result is a part file or an augmentation library.
