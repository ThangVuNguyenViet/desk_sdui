# desk_sdui_generator — record & extension-type @Screen parameters

**Goal:** Let @Screen authors declare a screen parameter as a record (`({String headline, int count}) data`) or an extension type (`extension type ChefView(Map<String,Object?> raw)`) instead of a dedicated data class. Codegen auto-flattens record fields into the input map; extension types resolve to their representation field. Saves the boilerplate `class CounterData { final int value; … }` for screens whose data is a thin bag.

**Prereq:** `.plans/desk-sdui-analyzer-8.md` merged.

**Architecture:**
- `type_collector.dart` already enumerates @Screen parameter types and maps each parameter's fields to ref paths. Extend it to handle two new `DartType` cases:
  - **`RecordType`**: enumerate `positionalFields` + `namedFields`, treat each as an input map key (`data.headline`, `data.count`, etc.).
  - **`InterfaceType` where `element is ExtensionTypeElement`**: resolve to the representation type via `extensionTypeElement.representation.type`, then recurse into the existing handling.
- IR shape stays identical to today's class-typed screens. Consumer-facing change is only in the @Screen signature.

**Tech stack:** `analyzer ^13` (RecordType + ExtensionTypeElement are first-class), existing IR + lowerer.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

**Acceptance:**
- A new test screen `counter_record.dart` using `({int value}) data` lowers and renders identically to `counter_minimal.dart` (the version using a `CounterData` class).
- A new test screen `chef_view.dart` using `extension type ChefView(Map<String, Object?> raw)` lowers identically to today's chef screen.
- Existing chef IR byte-identical.

---

## Task 1 — Record-type parameter support

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/type_collector.dart`

**Step 1 — Find the @Screen parameter-handling entry point.** Likely a method that takes a `FormalParameterElement` and walks its type. The class-handling branch (the `InterfaceType` case) is the template.

**Step 2 — Add a `if (paramType is RecordType)` branch** that enumerates fields:

```dart
if (paramType is RecordType) {
  for (final positional in paramType.positionalFields) {
    // positional fields are exposed as $1, $2, ... in Dart. Use the
    // same naming as the runtime side: emit ref paths `data.$1`, etc.
    addField(parameterName: '\${param.name}.\$${i + 1}', fieldType: positional.type);
  }
  for (final named in paramType.namedFields) {
    addField(parameterName: '\${param.name}.${named.name}', fieldType: named.type);
  }
  return;
}
```

Match whatever the existing class-handling branch emits — paths must round-trip with `ref_resolver`.

**Step 3 — Author a test screen** `packages/desk_sdui_demo/lib/screens/counter_record.dart`:

```dart
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

@Screen('counter_record')
Widget counterRecord(({int value}) data) {
  return Center(
    child: Text(
      '${data.value}',
      style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
    ),
  );
}
```

**Step 4 — Regenerate + verify** the IR for `counter_record` looks structurally identical to `counter_minimal`'s IR (same `RefNode(['data','value'])` shape).

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
diff <(grep -E "RefNode|LiteralNode" lib/screens/counter_minimal.sdui.g.dart) \
     <(grep -E "RefNode|LiteralNode" lib/screens/counter_record.sdui.g.dart)
```

Expected: identical except for the screen-name string.

---

## Task 2 — Extension-type parameter support

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/type_collector.dart`

**Step 1 — Resolve representation type.** Before the existing `InterfaceType` handling runs, check whether the element is an `ExtensionTypeElement` and substitute the representation type:

```dart
DartType _unwrapExtensionType(DartType t) {
  if (t is InterfaceType && t.element is ExtensionTypeElement) {
    return (t.element as ExtensionTypeElement).representation.type;
  }
  return t;
}
```

Apply at the entry point of the parameter-walk so the rest of the code is unaware extension types exist.

**Step 2 — Author a test screen** `packages/desk_sdui_demo/lib/screens/chef_view.dart`:

```dart
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

extension type ChefView(Map<String, Object?> raw) {
  String get headline => raw['headline'] as String;
  // ... other getters mirroring ChefData's surface
}

@Screen('chef_view')
Widget chefView(ChefView data) {
  return Text(data.headline);
}
```

**Step 3 — Verify** the lowered IR uses `RefNode(['data','headline'])` — same path as today's chef. The extension type is transparent at lowering time.

---

## Task 3 — Test

**Files:**
- Modify: `packages/desk_sdui_generator/test/type_collector_test.dart`

**Step 1 — Add tests** for both shapes, asserting the resulting input contract matches a hand-built reference.

**Step 2 — Run**

```
cd packages/desk_sdui_generator && dart test
```

---

## Task 4 — Verify byte-identical chef + counter regressions

Standard byte-identical diff against committed IR for every screen that doesn't use the new features. Any diff is a regression.

```
cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs
git diff lib/screens/chef.sdui.g.dart lib/screens/counter_*.sdui.g.dart
```

Expected: zero diff except newly-added `counter_record.sdui.g.dart` + `chef_view.sdui.g.dart`.

---

## Task 5 — Commit

```
git add -A && git commit -m "feat(generator): record & extension-type @Screen params"
```

---

## Open questions

1. **Optional record fields.** Records don't have an `?` per field — every field is required. If we need optional fields, the author has to wrap them in nullable types. Document this in the screen-authoring guide.
2. **Extension-type method dispatch.** The `chef_view.dart` example uses *getters* on the extension type, which are pure and resolve at the analyzer level. If an author writes a method that does runtime work, the lowerer should still see the underlying representation and not try to call the extension method — confirm via test.
3. **Wire format for records.** The runtime side currently expects `Map<String, Object?>` keyed by field name. For record positional fields (`$1`, `$2`, …) the consumer call site must populate the input map with those exact keys. Document or generate a typed builder.

If any of these turn out to be hard blockers in implementation, STOP and report.

## Out of scope

- Sealed-type @Screen parameters with pattern dispatch in the body.
- Mixed positional + named record fields in deeply nested shapes — supported transitively, but no specific test until a real screen needs it.

## Verify commands

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui
(cd packages/desk_sdui_generator && dart analyze && dart test) || exit 1
(cd packages/desk_sdui_demo && dart run build_runner build --delete-conflicting-outputs && flutter test) || exit 1
```
