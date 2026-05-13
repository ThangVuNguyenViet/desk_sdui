# desk_sdui — feature status

Single source of truth for what's shipped vs pending. Update when a feature lands or a plan is dispatched. The roadmap files
(`desk-sdui-bucket-1-and-2-roadmap.md`, `desk-sdui-bucket-4-dart-eval-feature-parity.md`) define the "why" and "how"; this file
tracks the "where are we."

Last updated: 2026-05-13.

## Buckets 1 + 2 — sugar + narrow runtime extensions (`bucket-1-and-2-roadmap.md`)

| # | Feature | Status | Plan |
|---|---|---|---|
| 1 | `LetNode` | shipped | — (pruned) |
| 2 | `LambdaNode` | shipped | — |
| 3 | Pattern matching | shipped | — (pruned) |
| 4 | `ActionSequenceNode` | shipped | — (pruned) |
| 5 | Generic type carriage | shipped | — (pruned) |
| 6 | `TryStepNode` | shipped | — (pruned) |
| 7 | Cascades | shipped | — (pruned) |

## Bucket 3 — mutable state + cost-aware codegen (`bucket-1-and-2-roadmap.md`)

| # | Feature | Status | Plan |
|---|---|---|---|
| 8 | `AssignNode` + mutable env (cells) | shipped | `desk-sdui-mutable-env-assign-node.md` |
| 9 | `BlockNode` + control flow signals | shipped | `desk-sdui-block-node.md` |
| 10 | Statement loops (`WhileNode`, `DoNode`, imperative `ForNode`) | shipped | `desk-sdui-statement-loops.md` |
| 11 | `IrStatefulNode` | shipped | `desk-sdui-ir-stateful-node.md` |
| 12 | Payload function declarations | shipped | `desk-sdui-payload-functions.md` |
| 13 | Cost classifier | shipped | — (pruned) |
| 14 | Setter codegen for `@Register` | shipped | `desk-sdui-register-setter-codegen.md` |

## Bucket 4 — payload-defined types (`bucket-4-dart-eval-feature-parity.md`)

Dispatch order is dependency-driven (see roadmap). Each feature has a plan file but **none have been dispatched yet**.

| # | Feature | Status | Plan |
|---|---|---|---|
| 15 | Runtime class descriptors + `PayloadInstance` | pending | `desk-sdui-payload-class-descriptors.md` |
| 16 | Payload class declarations + constructor lowering | pending | `desk-sdui-payload-class-declarations.md` |
| 17 | Instance method dispatch | pending | `desk-sdui-payload-method-dispatch.md` |
| 18 | Instance field access (read + write) | pending | `desk-sdui-payload-field-access.md` |
| 19 | `is` / `as` / subtype checks | pending | `desk-sdui-is-as-subtype-checks.md` |
| 20 | Mixin linearization + dispatch | pending | `desk-sdui-payload-mixins.md` |
| 21 | Extension method dispatch | pending | `desk-sdui-payload-extensions.md` |
| 22 | Operator overloading | pending | `desk-sdui-operator-overloading.md` |
| 23 | First-class function values (`PayloadFunctionValue`) | pending | `desk-sdui-first-class-functions.md` |
| 24 | Type introspection (`runtimeType`) | pending | `desk-sdui-type-introspection.md` |
| 25 | Allowlist re-verification pass | pending | `desk-sdui-allowlist-reverify.md` |
| 26 | Cost classifier extension for payload classes | pending | `desk-sdui-cost-classifier-bucket4.md` |

### Suggested dispatch order

```
                15 (descriptors)
                  │
        ┌─────────┴─────────┐
       16 (class decls)    19 (is/as)   24 (runtimeType)
        │
   ┌────┴────┐
  17 (methods)  18 (fields)
   │
   ├─ 20 (mixins)
   ├─ 21 (extensions)
   ├─ 22 (operators)
   └─ 23 (first-class fns)   ← also needs F2 (LambdaNode)

         25 (allowlist re-verify) — after 16-23
         26 (cost classifier ext) — after F13 + 16-23
```

**Foundation first**: 15 must land before anything else. After 15, 16 and 19 unblock the rest. 17-18 are independent of each
other; 20-23 fan out from 17 and can run in parallel.

**Parallel-safe batches** once dependencies are met:
- Wave 1: 15 (solo)
- Wave 2: 16, 19, 24 (3 parallel)
- Wave 3: 17, 18 (2 parallel)
- Wave 4: 20, 21, 22, 23 (4 parallel)
- Wave 5: 25, 26 (2 parallel)

## Orthogonal / housekeeping

| Plan | Status | Notes |
|---|---|---|
| `desk-sdui-augmentations.md` | pending | Analyzer 13 augmentation support — independent of buckets |
| `desk-sdui-post-merge-followups.md` | partially shipped | 5 follow-ups from the 2026-05-12 merge; status per-item lives in the file |

## Lowerer gaps surfaced but not yet planned

Discovered while consolidating the demo into one screen (2026-05-13). No plan files exist yet.

- Record literals (`(x, y)`) and destructuring (`final (a, b) = pair`)
- Cascade operator `..` in expression position (today only via `SequenceNode` codegen path)
- Multi-statement block-bodied lambdas (`onPressed: () { stmt1; stmt2; }`)
- Block-bodied `@Screen` requires explicit `return`; cannot lower bare statement-form bodies

These should become individual plans before bucket 4 if any payload-class demo depends on them.
