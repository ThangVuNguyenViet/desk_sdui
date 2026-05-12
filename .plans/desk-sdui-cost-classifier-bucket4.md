# desk_sdui — Feature 26: Cost classifier extension for payload classes

**Goal:** Extend Feature 13's cost classifier to also analyze payload class methods and extension methods. Same severity matrix; additional cost class.

**Dependencies:** Feature 13 (cost classifier framework), all of bucket 4 (16-23).

**Architecture:**
- Extend `CostClass` enum with `allocatesPerCall` (new).
- Reuse the same call-site context tracking (build/signal/action) — no new context, same matrix.
- Add a walker pass over `PayloadClassNode.methods`, `PayloadMixinNode.methods`, `PayloadExtensionNode.methods`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Extend `CostClass`

**File:** `packages/desk_sdui_generator/lib/src/cost_classifier/classifier.dart`.

```dart
enum CostClass {
  pureBounded,
  linearInArg,
  unbounded,
  recursiveSizeDecreasing,
  recursiveFree,
  /// Constructs at least one PayloadInstance. Per-call heap allocation.
  /// In tight build-path loops, may dominate frame budget.
  allocatesPerCall,
}
```

---

## Task 2 — Detection walker

Add to the classification walker:

```dart
// In _walk:
case PayloadInstanceCreationNode():
  findings.hasAllocation = true;
  break;
```

`_Findings` adds `bool hasAllocation = false`.

Update classification rule order:
1. Free recursion → `recursiveFree`.
2. Size-decreasing recursion (no unbounded loops) → `recursiveSizeDecreasing`.
3. Unbounded loops → `unbounded`.
4. Data-dependent loops → `linearInArg`.
5. Allocation but no loops → `allocatesPerCall`.
6. Otherwise → `pureBounded`.

(Allocation co-occurring with loops nests: `linearInArg` already implies O(N) per call; if it also allocates, severity escalates by one notch in the matrix — see Task 3.)

---

## Task 3 — Diagnostic matrix update

| Class × call-site | Build | Signal | Action |
|---|---|---|---|
| `allocatesPerCall` | info | info | silent |
| `linearInArg` + allocates | warning | warning | silent |
| `unbounded` + allocates | warning | warning | info |
| (existing rows unchanged) | … | … | … |

Combined "linearInArg + allocates" is detected when both `hasDataDependentLoop` and `hasAllocation` are true. The severity bumps by one notch from the base `linearInArg` row.

---

## Task 4 — Messages

```
- "Method `Order.applyDiscount` allocates a payload instance and is called from
   a build path. Consider memoizing if called > ~100× per frame."
- "Method `Order.filter` is O(items.length) AND allocates per element. Hot
   path; consider materializing once via a registered helper."
```

---

## Task 5 — Tests + demo

Tests:
1. Method that allocates one PayloadInstance + no loops → `allocatesPerCall`.
2. Method that allocates inside a loop over an arg → escalated diagnostic.
3. Pure-bounded payload method (no loops, no allocation) silent everywhere.

Demo: extend `cost_demo.dart` (Feature 13's demo) with an allocating payload method called from build; verify diagnostic emitted at the call site.

---

## Out of scope

- Inter-procedural escape analysis (tracking whether allocated instances escape the call frame). Conservative classification is good enough.
- Configurable severity thresholds.
- Per-call argument-shape inference.

---

## Verify commands

(Standard suite.)
