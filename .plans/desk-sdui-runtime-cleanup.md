# desk_sdui runtime cleanup — remove demo leakage + tighten contract

## Goal

Strip three pieces of demo-specific / suboptimal code out of `package:desk_sdui` and lock in a clean contract: **input is `Map<String, Object?>`; runtime walks it; no reflection.**

1. Delete `_accessProperty` / `_getProperty` / `_dynamicGet` / `_tryGet` chain in `ref_resolver.dart`. These hard-code foodtech demo field names (`headline`, `dishes`, `featuredItems`, …) inside the runtime library. Replaced by: callers serialize typed data to `Map<String, Object?>` before handing to `SduiScreen.input`.
2. Delete `_resolveFlutterConstant` + its 14 enum/icon helper switches. Constants are already emitted by codegen via `rt.registerConstant` (Phase 3 v2 Tasks 5–7). Replace the runtime's hand-coded whitelist with a lookup through `rt.resolveConstant`.
3. Migrate source `Future<List<int>>` → `Future<Uint8List>` to match the plan edit already landed in `.plans/desk-sdui-2-runtime.md`. Avoids boxing/unboxing on the loader hot path.

Plus: doc the input contract in `package:desk_sdui`'s README so consumers know "we accept Map; bring your own `toJson`."

## Non-goals

- Generating a `toMap` adapter for typed `@Screen` parameters. The `@Screen` function still takes a typed parameter — codegen uses it for path lowering and static checks — but at the render boundary the caller does the serialization (their freezed/dart_mappable/json_serializable already produces `toJson()`).
- Supporting `@JsonKey(name: '…')` renames. Map keys must match Dart field names. If a consumer's `toJson` renames keys, they write a one-liner adapter at the call site.
- Touching Phase 4 plans or porting work.

## Files to edit

**Source (where the deletions happen):**

- `packages/desk_sdui/lib/src/ref_resolver.dart` — primary file. ~190 lines deleted, ~30 modified.
- `packages/desk_sdui/lib/src/runtime.dart` — `IrFetcher.fetch` return type change.
- `packages/desk_sdui/lib/src/loader/ir_fetcher.dart` — abstract method signature.
- `packages/desk_sdui/lib/src/loader/asset_bundle_ir_fetcher.dart` — concrete return type.
- `packages/desk_sdui/lib/src/loader/remote_ir_fetcher.dart` — concrete + `HttpGet` typedef.
- `packages/desk_sdui/test/runtime_test.dart` — test fakes adjust.

**Demo (where the call-site change happens):**

- `packages/desk_sdui_demo/lib/screens/chef.dart` — render-side: pass `chefData.toJson()` (or equivalent map) instead of typed `ChefData`. May require generating a `toJson` on `ChefData` if it doesn't have one.
- Any `home`/other demo screens that currently pass typed objects.

**Docs:**

- `packages/desk_sdui/README.md` — add an "Input contract" section.

## Steps (in order; one commit per logical chunk)

### Step 1 — Survey

Run before editing anything:

```bash
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
grep -rn "_accessProperty\|_dynamicGet\|_tryGet\|_getProperty\|_resolveFlutterConstant\|_resolveIcon\|_resolveCrossAxisAlignment\|_resolveMainAxisAlignment\|_resolveMainAxisSize\|_resolveTextAlign\|_resolveTextBaseline\|_resolveTextOverflow\|_resolveFontStyle\|_resolveFontWeight\|_resolveBoxFit\|_resolveAxis\|_resolveWrapCrossAlignment\|_resolveStackFit\|_resolveClip\|_resolveColor\|_resolveBoxShape\|resolveFlutterRef" packages/
```

Capture the call sites. Anything outside `ref_resolver.dart` and its callers in `resolve.dart` / `expression_eval.dart` needs investigation before deleting.

```bash
grep -rn "Future<List<int>>" packages/
```

Expected: 5–6 hits in source + test files; the plan doc is already updated.

### Step 2 — Delete `_accessProperty` chain, chef demo passes Map

**Edit `packages/desk_sdui/lib/src/ref_resolver.dart`:**

Remove lines ~240–342 (`_getProperty`, `_dynamicGet`, `_tryGet`, `_accessProperty`).

Modify `resolveRef` (lines 7–34) so the final `else` branch (currently `current = _getProperty(current, seg)`) becomes `return null`. After the change, `resolveRef` is a pure map/list walk:

```dart
Object? resolveRef(List<String> path, Map<String, Object?> input) {
  Object? current = input;
  for (final seg in path) {
    if (current == null) return null;
    if (current is Map) {
      final getters = current['__getters__'];
      if (getters is Map && getters.containsKey(seg)) {
        final g = getters[seg];
        if (g is Function) {
          current = Function.apply(g, const []);
          continue;
        }
      }
      current = current[seg];
      continue;
    }
    if (current is List) {
      final i = int.tryParse(seg);
      if (i == null || i < 0 || i >= current.length) return null;
      current = current[i];
      continue;
    }
    return null;  // non-Map non-List leaf — caller passed wrong type
  }
  return current;
}
```

Keep the `__getters__` escape hatch (lines 12–19); it's a deliberate opt-in for computed fields, not demo leakage.

**Edit `packages/desk_sdui_demo/lib/screens/chef.dart`:**

Wherever the demo renders the chef screen, change the call site to pass a map. Two acceptable shapes:

```dart
// Option A — chef data class has toJson() (freezed/json_serializable):
SduiScreen(binding: chefBinding, input: chefData.toJson())

// Option B — hand-roll map:
SduiScreen(binding: chefBinding, input: {
  'headline': chefData.headline,
  'dishes': chefData.dishes.map((d) => {
    'name': d.name, 'price': d.price, 'description': d.description,
    'imageUrl': d.imageUrl, 'numberLabel': d.numberLabel,
  }).toList(),
  // ... only fields chef.dart's @Screen body references
})
```

Pick whichever matches what `ChefData` already supports. If `ChefData` has neither `toJson` nor a `Mappable` adapter, add a `toJson()` method manually — it's a one-off, ~15 lines.

Same treatment for any other demo screen that's currently passing typed objects (home, etc.).

**Verify:**

```bash
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
dart analyze packages/desk_sdui packages/desk_sdui_annotation
flutter analyze packages/desk_sdui_demo
flutter test packages/desk_sdui_demo
dart test packages/desk_sdui
```

All clean. Existing chef rendering tests (if any) still pass. `network_only_screen_test.dart` (Task 11) still passes.

**Commit:** `refactor(desk_sdui): remove _accessProperty — input contract is Map<String, Object?>`

### Step 3 — Delete `_resolveFlutterConstant`, route through `rt.resolveConstant`

**Investigation first** — before editing, run codegen on chef and inspect `chef.sdui.g.dart`:

```bash
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
grep -E "registerConstant" lib/screens/chef.sdui.g.dart | head -30
```

Verify codegen already emits the enum/icon values chef references (e.g. `CrossAxisAlignment.start`, `Icons.arrow_back_ios_new`) as `rt.registerConstant(...)` calls. If yes, the runtime fallback is dead code. If some are missing, that's a codegen gap — file as a follow-up; don't delete those entries from `_resolveFlutterConstant` until codegen covers them.

**Naming convention check** — look at the actual key shape codegen emits. Likely `'Icons.arrow_back_ios_new'` (dotted) or `'Icons.arrow_back_ios_new'` flat. Whatever it is, `resolveFlutterRef` needs to match.

**Edit `packages/desk_sdui/lib/src/ref_resolver.dart`:**

Replace `resolveFlutterRef` (lines 36–45) with:

```dart
Object? resolveFlutterRef(
  List<String> path,
  Map<String, Object?> input,
  Runtime runtime,
) {
  if (path.isEmpty) return null;
  if (path.length >= 2) {
    final key = '${path[0]}.${path[1]}';  // adjust to codegen convention
    final v = runtime.resolveConstant(key);
    if (v != null) {
      // Walk any remaining path segments into the constant (rare, but possible
      // if a constant is itself a struct).
      if (path.length == 2) return v;
      return resolveRef(path.sublist(2), {'__root__': v});
    }
  }
  return resolveRef(path, input);
}
```

The signature gained a `Runtime` arg. Update every caller in `resolve.dart` / `expression_eval.dart` to pass it. (The runtime is already in scope at every call site — it's how widgets get resolved.)

Then delete:
- `_resolveFlutterConstant` (lines 47–70).
- All 14 helper switches `_resolveIcon`, `_resolveCrossAxisAlignment`, ..., `_resolveBoxShape` (lines 72–238).

The file shrinks from ~342 lines to ~50.

**Verify:**

```bash
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
dart analyze packages/desk_sdui
flutter test packages/desk_sdui_demo
```

Chef must still render correctly. Icons must still appear. Any failure = codegen gap; surface it and stop, do not paper over by restoring the hand-coded switch.

**Commit:** `refactor(desk_sdui): delete hand-coded Flutter constant whitelist — use rt.resolveConstant`

### Step 4 — Migrate `Future<List<int>>` → `Future<Uint8List>`

Five files (see Step 1 grep output). Each one:

- Replace `Future<List<int>>` → `Future<Uint8List>` in signatures.
- Add `import 'dart:typed_data';` where missing.
- `http.Response.bodyBytes` is already `Uint8List` — no change to return expressions.
- `ByteData.buffer.asUint8List(...)` is already `Uint8List` — no change to return expressions.

Files:
- `packages/desk_sdui/lib/src/runtime.dart`:81
- `packages/desk_sdui/lib/src/loader/ir_fetcher.dart`:14 (abstract)
- `packages/desk_sdui/lib/src/loader/asset_bundle_ir_fetcher.dart`:10
- `packages/desk_sdui/lib/src/loader/remote_ir_fetcher.dart`:4 (typedef), 14, 21
- `packages/desk_sdui/test/runtime_test.dart`:115 (fake fetcher)

**Verify:**

```bash
dart analyze packages/desk_sdui
dart test packages/desk_sdui
flutter test packages/desk_sdui_demo
```

All clean.

**Commit:** `refactor(desk_sdui): IrFetcher returns Uint8List, not Future<List<int>>`

### Step 5 — Document the input contract

Add to `packages/desk_sdui/README.md` (create the file if it doesn't exist):

```markdown
## Input contract

`SduiScreen.input` accepts `Map<String, Object?>`. Map keys are the Dart field
names referenced inside your `@Screen` function body. Values may be primitives,
nested maps, lists, or computed-on-access functions (see `__getters__` below).

If your domain models already produce JSON-shaped maps (via `freezed`,
`dart_mappable`, `json_serializable`, or hand-rolled `toJson` methods), pass the
output of those directly:

    SduiScreen(binding: chefBinding, input: chefData.toJson())

### Key naming

Map keys must match the Dart field names your `@Screen` references. If your
serializer renames keys (e.g. `@JsonKey(name: 'chef_name')` → snake_case),
adapt at the call site:

    SduiScreen(
      binding: chefBinding,
      input: chefData.toJson().map(
        (k, v) => MapEntry(_camelCase(k), v),
      ),
    )

### Lazy / computed fields

For expensive fields you don't want to eagerly serialize, use the `__getters__`
escape hatch:

    {
      'headline': chefData.headline,
      'dishes': chefData.dishes.map((d) => d.toJson()).toList(),
      '__getters__': {
        'expensiveStats': () => chefData.computeStats(),
      },
    }
```

**Commit:** `docs(desk_sdui): document Map<String, Object?> input contract`

## Verify (after all four commits)

```bash
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
dart analyze packages/desk_sdui packages/desk_sdui_annotation packages/desk_sdui_generator
flutter analyze packages/desk_sdui_demo
dart test packages/desk_sdui packages/desk_sdui_generator
flutter test packages/desk_sdui_demo
```

All green. `ref_resolver.dart` is ~50 lines (down from 342). Zero references to demo data field names anywhere in `packages/desk_sdui/lib/`.

## Out of scope

- Phase 4 porting work.
- Adding a `@SduiData` annotation or codegenning `toMap` for typed `@Screen` parameters. If the boilerplate of writing `toJson` becomes painful, revisit then.
- Supporting non-camelCase keys natively in the path resolver. The adapter-at-call-site pattern is the answer.

## Final report

When complete, report:

- 4 commit SHAs on `main`.
- Line-count delta on `ref_resolver.dart` (expect ~342 → ~50).
- Any codegen gaps surfaced by Step 3 (constants chef uses that aren't emitted via `rt.registerConstant`).
- Any demo screens that needed `toJson` written from scratch (vs. already having one).
