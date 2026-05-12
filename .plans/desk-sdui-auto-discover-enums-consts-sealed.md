# desk_sdui — auto-discover enums, static const fields, sealed subtypes

**Goal:** Reduce `@Register([...])` boilerplate by auto-discovering three classes of types from already-collected widgets/value-types, without breaking the allowlist safety property:

1. **Enums** referenced as ctor param types of any collected widget/value-type. Today users must list `MainAxisAlignment`, `CrossAxisAlignment`, etc. manually; after this change, registering `Column` is enough.
2. **Static const fields** of any collected class. Today users must list `Colors.red` explicitly; after this change, registering `Colors` brings all its public static const colors.
3. **Sealed subtypes** of any collected sealed parent class (or referenced as ctor param type of a collected class). Dart 3 `sealed` keyword makes the closed set discoverable via the analyzer.

**Why these three together:** they share the same walker — once we walk ctor param types and class-static-fields for one purpose, the marginal cost of the other two is small. They're also the three lowest-risk auto-discovery rules (finite, bounded, unsurprising). Higher-risk rules (one-hop value-type recursion, full transitive widget discovery) are explicitly out of scope.

**Acceptance:**

1. **Enum auto-discovery:** Removing `MainAxisAlignment`, `CrossAxisAlignment`, `MainAxisSize`, `TextDirection`, `VerticalDirection`, `TextBaseline`, `Clip`, `MainAxisAlignment.center`-style constants from `kCommonWidgets` / demo `@Register` lists still compiles and renders correctly (the same enum constants now flow in transparently because `Column`, `Row`, `Padding`, etc. reference them in their ctor signatures).
2. **Static const auto-discovery:** Adding a `@Register([Colors])` (without listing individual color constants) automatically registers `Colors.red`, `Colors.blue`, etc. Same for `Icons.add`, `Alignment.center`, `Curves.easeIn`. Demonstrate via the demo: add a `Container(color: Colors.red)` use site to a screen, regenerate, runtime renders correctly.
3. **Sealed subtype auto-discovery:** Add a tiny user-defined sealed class in the demo (`sealed class Status { ... } final class Active extends Status {} final class Idle extends Status {}`), register the parent with `@Register([Status])`, confirm both `Active` and `Idle` end up in the registry without explicit listing.
4. **Hard cap on static const explosion:** Classes with more than **200** static const fields (`Icons` is ~1500) emit a single comment `// elided ${cls.name}: $count static consts (over cap; use @Register([Icons.add, ...]) for explicit subset)` and skip auto-emission. User-explicit registrations of individual fields still work.
5. No regressions: existing 133/133 generator tests still pass; demo screens still render.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Verify commands:**
```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter analyze
```

---

## Task 1 — Extend `CollectedTypes` discovery for enums via ctor params

**File:** `packages/desk_sdui_generator/lib/src/type_collector.dart`

### Step 1 — Read the existing walker

Understand how `collectTypesFromAnnotation` populates `CollectedTypes` for the explicit `@Register([T1, T2, ...])` list. Note where types are classified into `.widgets` / `.valueTypes` / `.constants` / etc.

### Step 2 — Add an enum-discovery pass

After the initial classification, for each `cls in collected.widgets ∪ collected.valueTypes`:
- Walk all public constructors (`cls.constructors.where((c) => !c.isPrivate)`).
- For each ctor parameter's `DartType`:
  - Unwrap nullability and type arguments (`List<MainAxisAlignment>` → `MainAxisAlignment`).
  - If the head element is an `EnumElement`, add to a new `collected.enums` set (or reuse `.valueTypes` if the registration emitter treats them identically — look at how the existing constants path emits enum values to decide). Pick whichever existing code path already produces `rt.registerConstant('MainAxisAlignment.center', MainAxisAlignment.center)`-shaped output, and route the discovered enums there.

If the existing emitter has no special enum handling and treats enums as value types with const ctors, just add the enum class to `.valueTypes` and let the existing constants discovery (Task 2) pick up its values.

### Step 3 — Dedup

If the user explicitly registered `MainAxisAlignment` in `@Register([...])`, the discovery walker should be a no-op for that type — `CollectedTypes` adds are set-based already; verify.

### Step 4 — Commit

```
git add -A && git commit -m "feat(desk_sdui_generator): auto-discover enum ctor-param types from registered classes"
```

---

## Task 2 — Auto-discover static const fields of every collected class

**File:** `packages/desk_sdui_generator/lib/src/type_collector.dart`

### Step 1 — Add a static-const-field discovery pass

For each `cls in collected.widgets ∪ collected.valueTypes ∪ collected.enums` (or whatever the post-Task-1 union is):
- Walk `cls.fields.where((f) => f.isStatic && f.isConst && f.isPublic)`.
- Count first. If `count > 200`, emit a `// elided` comment in the generated output (see Acceptance #4) and skip.
- Else, for each, add the `FieldElement` to `collected.constants` so the existing `emitConstant` path picks it up.

For enums specifically: the analyzer exposes enum values via `EnumElement.constants` (or as fields with `isEnumConstant: true`). Use whichever is canonical in the analyzer version pinned here. The cap doesn't apply to enums — even the largest enums in Flutter (`MaterialState` etc.) are well under 200.

### Step 2 — Wire the "elided" marker

The cap-exceeded case needs to produce a single comment line in the generated registration block instead of N lines. Easiest path: add an optional `List<String> notes` to `CollectedTypes`, populate it from the walker when capped, and have `RegistrationEmitter.emitAll` interleave the notes as comments before its constant section. If that's too invasive, just `print()` a build warning and silently skip — the user can always add an explicit `@Register([Icons.add, Icons.remove, ...])` to get specific entries. Pick whichever is less code; document the choice.

### Step 3 — Commit

```
git add -A && git commit -m "feat(desk_sdui_generator): auto-discover static const fields with 200-entry cap"
```

---

## Task 3 — Auto-discover sealed subtypes

**File:** `packages/desk_sdui_generator/lib/src/type_collector.dart`

### Step 1 — Add a sealed-subtype discovery pass

For each `cls in collected.widgets ∪ collected.valueTypes`:
- Walk ctor param types as in Task 1.
- For each param's head `InterfaceType`, check if its `element` is a `ClassElement` with `isSealed == true`.
- If so, look up the sealed subclasses via the analyzer's API (`cls.allSubclasses` if exposed, or walk the same library for `extends`/`implements` references — check what's available in analyzer 13).
- Add each subclass to `.widgets` or `.valueTypes` according to the same Widget-vs-not test the explicit `@Register` path uses.

Also handle the case where the registered class itself is sealed — walk its subclasses directly.

If analyzer 13 doesn't expose a tidy `allSubclasses` API, scope the search to the **same library** as the sealed parent (sealed types must have all subclasses in the same library, so this is exhaustive and cheap).

### Step 2 — Commit

```
git add -A && git commit -m "feat(desk_sdui_generator): auto-discover sealed subtypes referenced by registered classes"
```

---

## Task 4 — Test coverage

**File:** `packages/desk_sdui_generator/test/type_collector_test.dart` (or wherever `collectTypesFromAnnotation` is tested)

Add focused tests for each new behavior:

1. **Enum discovery:** `@Register([Column])` produces a `CollectedTypes` whose `.constants` (or `.enums`) contains `MainAxisAlignment.center`, etc. Resolve a tiny source file with `@Register([Column])` and inspect the result.

2. **Static const discovery:** `@Register([Colors])` produces `.constants` containing `Colors.red`, `Colors.blue` (assert at least 3 known ones).

3. **Cap behavior:** `@Register([Icons])` does NOT explode the constants set; assert either the elided-note is present, or the count of `Icons.*` constants in `.constants` is zero (per your Task-2 choice).

4. **Sealed discovery:** Resolve a source file with a tiny user-defined `sealed class Status` + two finalclass subclasses + `@Register([Status])`, assert both subclasses end up in `.valueTypes`.

Match existing test patterns in the file — `_resolveSource`, `LibraryReader`, `TypeChecker`, etc.

```
cd packages/desk_sdui_generator && dart test test/type_collector_test.dart
```

Commit:

```
git add -A && git commit -m "test(desk_sdui_generator): cover enum/const/sealed auto-discovery"
```

---

## Task 5 — Demo regen + trim explicit registrations

**File:** `packages/desk_sdui_demo/lib/sdui_catalog.dart` (and any nearby explicit constant lists)

### Step 1 — Regenerate to see the new auto-discovered entries

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
```

Inspect the generated `desk_sdui_setup.g.dart` and any `.sdui_reg.g.dart` — confirm that enum constants you'd expect (`MainAxisAlignment.center`, `CrossAxisAlignment.start`, etc.) now appear.

### Step 2 — Optional: trim explicit redundant entries

If the demo's `@Register([...])` lists currently spell out enums that are now auto-discovered, you may delete those entries — they become redundant. Skip if it adds churn without clear value.

### Step 3 — Run the demo and probe again

Same in-app `[sdui-probe]` measurement from `main.dart`. Capture the new entry count (`grep -c "rt\.register" lib/desk_sdui_setup.g.dart`) and report the registry growth delta. This is a sanity check that auto-discovery didn't accidentally explode the registry.

### Step 4 — Commit

```
git add -A && git commit -m "chore(desk_sdui_demo): regenerate after enum/const/sealed auto-discovery"
```

---

## Task 6 — Final verification

```
cd packages/desk_sdui_generator && dart analyze && dart test
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter analyze
```

All green. No regressions on existing screens. Registry growth in the demo is bounded (expect somewhere in the +50 to +200 entries range — `MainAxisAlignment` (3 values) + `CrossAxisAlignment` (5) + `MainAxisSize` (2) + `TextDirection` (2) + `VerticalDirection` (2) + `TextBaseline` (2) + `Clip` (4) etc., plus a few more from widgets we haven't enumerated. Definitely not multiplicative blowup.

---

## Out of scope (do NOT touch in this plan)

- **One-hop value-type ctor recursion** (`BoxDecoration` → `Color`, `Gradient`, …). Discussed and deferred.
- **Auto-registering all of Flutter material.** Discussed and rejected — bundle-size cost.
- **Curated bundle constants** (`kFormWidgets`, `kAnimationPrimitives`). Separate plan.
- **Diagnostic for unused auto-discovered entries.** The 200-entry cap is sufficient guardrail.
- Touching `registration_emitter.dart` beyond the minimum needed to surface the new types — the existing `emitConstant` / `emitValueBuilder` paths should handle everything Task 1-3 adds.
