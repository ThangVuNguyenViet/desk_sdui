# desk_sdui — Cost classifier + codegen-time diagnostics

**Goal:** A codegen-time analyzer that assigns each payload function (and each screen body) a **cost class**, then emits diagnostics at call sites based on `context × class`. Lets bucket 3's expressiveness ship with informed authoring — the toolchain surfaces where per-frame cost is at risk; the author decides what to do about it.

**Dependencies:** ideally lands after Features 10 (loops) and 12 (payload functions) so the classifier has full input. Can land earlier with a reduced rule set, but the most valuable diagnostics need both.

**Architecture (load-bearing):**
- Pure codegen-time analyzer. Runs over the lowered IR before emission. Zero runtime contribution.
- Two inputs per call site:
  1. **Cost class of the callee** (Pure-bounded / Linear-in-arg / Unbounded / Recursive-free / Recursive-size-decreasing).
  2. **Call-site context** (Build / Signal / Action) — tracked by the lowerer's existing `inActionContext` flag plus a new `inSignalContext` flag.
- A diagnostic matrix maps the pair to a severity (silent / info / warning).
- Diagnostics emitted via the analyzer's `Reporter` so they surface in `dart analyze` / IDE.
- Standard `// ignore: sdui_potential_cost` suppression works because the diagnostic codes are registered with the lint system.

**Tech stack:** new analyzer module, no IR changes, no resolver changes, lowerer adds the context-tracking flag.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Classify payload functions

**Files:**
- Create: `packages/desk_sdui_generator/lib/src/cost_classifier/classifier.dart`.

**Step 1 — Define the cost class enum:**

```dart
enum CostClass {
  /// No loops; or loops with literal iteration counts. Constant per call.
  pureBounded,
  /// Has at least one loop iterating over a parameter or registered-method
  /// result with iterable shape. O(N × body) per call.
  linearInArg,
  /// Has a `while (cond)` where cond depends only on internal mutable state
  /// — no statically-derivable iteration bound.
  unbounded,
  /// Recursive call passes a strictly smaller arg (e.g. `fact(n - 1)`).
  /// Treated as linear-in-arg.
  recursiveSizeDecreasing,
  /// Recursive call without size-decrease guarantee. Treated as unbounded.
  recursiveFree,
}
```

**Step 2 — Classification walk.** Given a `PayloadFunctionNode` (or screen body), walk its IR and produce a `CostClass`. Pseudocode:

```dart
CostClass classify(IrNode body, {required String? selfName}) {
  final findings = _Findings();
  _walk(body, findings, selfName: selfName);
  if (findings.hasFreeRecursion) return CostClass.recursiveFree;
  if (findings.hasSizeDecreasingRecursion && !findings.hasUnboundedLoop) {
    return CostClass.recursiveSizeDecreasing;
  }
  if (findings.hasUnboundedLoop) return CostClass.unbounded;
  if (findings.hasDataDependentLoop) return CostClass.linearInArg;
  return CostClass.pureBounded;
}
```

`_walk` traverses every node:
- `WhileNode` / `DoNode`: classify by condition expression's data dependency. If condition reads ONLY internal mutable state (lifted-out cells with no source from params), → unbounded. If condition references a param or a registered method's result → linear-in-arg with a *data-dependent* loop. Conservative: when in doubt, classify as unbounded.
- `ImperativeForNode` / collection-for (`ForNode`): same logic on `condition`. Collection-for over a param iterable → linear-in-arg.
- `PayloadFunctionCallNode` where `name == selfName`: recursion. Check the args:
  - For each arg expression, walk it and see if it's a clear "size-decrement" (`name - literal`, `name.length - 1`, etc.). If yes for at least one arg whose original param was iterated/looped on → size-decreasing.
  - Otherwise → free.
- Composition: when a payload function calls another payload function, *don't* recursively classify the callee here — that's already done. Just note the call.

**Limitations to document:**
- Inter-procedural classification is *not* transitive in this plan. A function calling a `linearInArg` callee inside its loop is NOT automatically `linearInArg²`. The simple heuristic catches the most common patterns (loops in this function) and is honest about its scope.
- Conditional/branched recursion (`if (cond) return fn(x)` else base) — checks the call sites; if any is non-size-decreasing, classify as free recursion.
- "Registered method's result iterable shape" — the classifier knows which registered methods return `Iterable`/`List` from the codegen catalog. Add a flag in the registration record: `returnsCollection: bool`. Maintain by hand for the curated set in `core_accessors.dart`; default false otherwise.

**Step 3 — Tests.** Unit tests for each class on synthetic IR inputs. Cover at least:
1. `Widget foo() { return Text('a'); }` → pureBounded.
2. `String foo(List<int> xs) { var s = ''; for (var x in xs) s += '$x'; return s; }` → linearInArg.
3. `int run(int x) { var i = 0; while (vm.notDone()) i++; return i; }` → unbounded (cond depends on a registered method call's bool result, treated as state-dependent).
4. `int fact(int n) { if (n <= 1) return 1; return n * fact(n - 1); }` → recursiveSizeDecreasing.
5. `int foo(int n) { return foo(n + 1); }` → recursiveFree.

**Step 4 — Commit.**

---

## Task 2 — Track call-site context

**Files:**
- Modify: `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart` — extend the existing `inActionContext` flag.

**Step 1 — Define call-site contexts:**

```dart
enum CallSiteContext {
  /// Inside an @Screen body or a WidgetNode arg (sync, per-frame).
  build,
  /// Inside a reactive binding / computed slot (sync, per-signal-tick).
  signal,
  /// Inside an ActionSequenceNode step or other event handler.
  action,
}
```

**Step 2 — Plumb the flag.** The lowerer's traversal already passes a `LoweringContext` (or equivalent). Extend it with `callSiteContext`:

- Default at @Screen entry: `build`.
- Entering an `ActionSequenceNode` step's call lowering: `action`.
- Entering a reactive binding (signal-driven slot — currently uses a different code path; check `reactive_hoist_pass.dart`): `signal`.
- Reset to `build` when descending back into WidgetNode args from a non-action subtree.

Pseudocode:

```dart
class LoweringContext {
  LoweringContext({this.callSiteContext = CallSiteContext.build, this.inActionContext = false});
  CallSiteContext callSiteContext;
  bool inActionContext;
  // ...
}

// On ActionSequenceNode descent:
final stepCtx = ctx.copyWith(
  callSiteContext: CallSiteContext.action,
  inActionContext: true,
);
```

**Step 3 — Record diagnostic emission sites.** At each `PayloadFunctionCallNode` lowering, record `(calleeName, callerName, callSiteContext, sourceLocation)`. The diagnostic pass (Task 3) consumes this record after all function bodies are classified.

**Step 4 — Verify + commit.**

---

## Task 3 — Emit diagnostics

**Files:**
- Create: `packages/desk_sdui_generator/lib/src/cost_classifier/diagnostics.dart`.
- Modify: the generator's reporter integration.

**Step 1 — The diagnostic matrix:**

```dart
Severity? diagnosticFor(CostClass cls, CallSiteContext ctx) {
  return switch ((cls, ctx)) {
    (CostClass.pureBounded, _) => null, // silent
    (CostClass.linearInArg, CallSiteContext.build) => Severity.info,
    (CostClass.linearInArg, CallSiteContext.signal) => Severity.info,
    (CostClass.linearInArg, CallSiteContext.action) => null,
    (CostClass.unbounded, CallSiteContext.build) => Severity.warning,
    (CostClass.unbounded, CallSiteContext.signal) => Severity.warning,
    (CostClass.unbounded, CallSiteContext.action) => Severity.info,
    (CostClass.recursiveSizeDecreasing, CallSiteContext.build) => Severity.info,
    (CostClass.recursiveSizeDecreasing, CallSiteContext.signal) => Severity.info,
    (CostClass.recursiveSizeDecreasing, CallSiteContext.action) => null,
    (CostClass.recursiveFree, _) => Severity.warning, // anywhere
  };
}
```

**Step 2 — Message templates:**

```dart
String messageFor(CostClass cls, CallSiteContext ctx, String fnName) {
  return switch ((cls, ctx)) {
    (CostClass.linearInArg, CallSiteContext.build) =>
      '"$fnName" is O(N) in its arg. Called per frame in build. '
      'Consider collection-for or moving to an event handler.',
    (CostClass.linearInArg, CallSiteContext.signal) =>
      '"$fnName" is O(N) in its arg. Called per signal tick.',
    (CostClass.unbounded, CallSiteContext.build) =>
      '"$fnName" has no statically-derivable upper bound. '
      'In a per-frame path; this may stall builds.',
    (CostClass.unbounded, CallSiteContext.signal) =>
      '"$fnName" has no statically-derivable upper bound. '
      'In a signal-tick path; this may stall reactive rebuilds.',
    (CostClass.unbounded, CallSiteContext.action) =>
      '"$fnName" has no statically-derivable upper bound. '
      'In an action handler — confirm termination.',
    (CostClass.recursiveFree, _) =>
      '"$fnName" is recursive without a size-decreasing argument. '
      'Stack overflow risk; confirm termination.',
    (CostClass.recursiveSizeDecreasing, _) =>
      '"$fnName" recursive with size-decreasing arg. O(depth × body) per call.',
    _ => '',
  };
}
```

**Step 3 — Emit via the analyzer's source-gen reporter.** Each diagnostic carries a code (`sdui_potential_cost.linear_in_build`, `sdui_potential_cost.unbounded_in_build`, etc.) so authors can suppress with `// ignore: sdui_potential_cost.unbounded_in_build`.

```dart
void emitCostDiagnostics(
  List<CallSiteRecord> sites,
  Map<String, CostClass> classes,
  Reporter reporter,
) {
  for (final site in sites) {
    final cls = classes[site.calleeName];
    if (cls == null) continue;
    final sev = diagnosticFor(cls, site.context);
    if (sev == null) continue;
    final msg = messageFor(cls, site.context, site.calleeName);
    reporter.emit(severity: sev, code: _codeFor(cls, site.context), location: site.location, message: msg);
  }
}
```

**Step 4 — Wire into the build pipeline.** The classifier + emitter run after lowering, before emission. If any `warning`-severity diagnostic is emitted, the codegen continues (warnings don't fail the build) — surfacing them is the value, not blocking.

**Step 5 — Commit.**

---

## Task 4 — Tests + demo

**Files:**
- Create: `packages/desk_sdui_generator/test/cost_classifier_test.dart`
- Create: `packages/desk_sdui_demo/lib/screens/cost_demo.dart`

**Step 1 — Classifier tests** (from Task 1, Step 3 — those are unit tests on synthesized IR; verify each example's class is correct).

**Step 2 — Diagnostic emission tests:**
1. Linear function called from build → info-severity diagnostic emitted with the documented message.
2. Same function called from action → no diagnostic.
3. Unbounded function called from build → warning.
4. Unbounded called from action → info.
5. Free-recursion called anywhere → warning.
6. Pure-bounded called from anywhere → silent.

**Step 3 — Demo with intentional diagnostics:**

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'cost_demo.sdui.g.dart';

// Pure-bounded — silent.
String label(int n) {
  return 'count: $n';
}

// Linear-in-arg — info in build, silent in action.
int sumPositives(List<int> items) {
  var s = 0;
  for (var i = 0; i < items.length; i++) {
    if (items[i] > 0) {
      s = s + items[i];
    }
  }
  return s;
}

// ignore: sdui_potential_cost.linear_in_build (silenced)
class CostController {
  final List<int> nums = const [1, -2, 3, -4, 5];
}

@Screen('cost_demo')
Widget costDemo(CostController vm) {
  // EXPECTED: 1 info diagnostic on this line: "sumPositives is O(N) in its arg..."
  return Column(children: [
    Text(label(sumPositives(vm.nums))),
  ]);
}
```

Verify by running `dart analyze` / `dart run build_runner build` and observing the diagnostic.

**Step 4 — Commit.**

---

## Task 5 — Full-suite verification

(Standard.)

---

## Out of scope

- **Configurable severity per project** (`analysis_options.yaml` integration). Could add later; for now severities are hard-coded.
- **Inter-procedural transitivity.** A linear function called inside a loop in another function isn't classified as quadratic. Document the limitation.
- **Per-call argument-shape inference.** "This call site passes a 3-element literal, so it's effectively bounded" — not detected.
- **Cost classes for registered methods.** Author can opt in via an annotation on `@Register`: `@Register(costClass: CostClass.linearInArg)`. Out of scope for this plan; defer until it matters.
- **Tightening on each release.** Today this is a static set of rules; expanding the matrix or adding new categories happens via plans that follow.

---

## Verify commands

```
cd /Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui

for p in packages/desk_sdui_annotation packages/desk_sdui packages/desk_sdui_generator; do
  (cd "$p" && dart analyze && dart test) || exit 1
done

(cd packages/desk_sdui_demo \
  && dart run build_runner build --delete-conflicting-outputs \
  && flutter analyze \
  && flutter test) || exit 1
```
