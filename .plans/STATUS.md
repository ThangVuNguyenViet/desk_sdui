# desk_sdui — feature status

Single source of truth for what's shipped vs pending. Update when a feature lands or a plan is dispatched. The roadmap files
(`desk-sdui-bucket-1-and-2-roadmap.md`, `desk-sdui-bucket-4-dart-eval-feature-parity.md`) define the "why" and "how"; this file
tracks the "where are we."

Last updated: 2026-05-18.

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
| 8 | `AssignNode` + mutable env (cells) | shipped | — (pruned) |
| 9 | `BlockNode` + control flow signals | shipped | — (pruned) |
| 10 | Statement loops (`WhileNode`, `DoNode`, imperative `ForNode`) | shipped | — (pruned) |
| 11 | `IrStatefulNode` | shipped | — (pruned) |
| 12 | Payload function declarations | shipped | — (pruned) |
| 13 | Cost classifier | shipped | — (pruned) |
| 14 | Setter codegen for `@Register` | shipped | — (pruned) |

## Bucket 4 — payload-defined types (`bucket-4-dart-eval-feature-parity.md`)

All features shipped. 207 tests pass, 0 analyzer errors.

| # | Feature | Status | Plan |
|---|---|---|---|
| 15 | Runtime class descriptors + `PayloadInstance` | shipped | `desk-sdui-payload-class-descriptors.md` |
| 16 | Payload class declarations + constructor lowering | shipped | `desk-sdui-payload-class-declarations.md` |
| 17 | Instance method dispatch | shipped | `desk-sdui-payload-method-dispatch.md` |
| 18 | Instance field access (read + write) | shipped | `desk-sdui-payload-field-access.md` |
| 19 | `is` / `as` / subtype checks | shipped | `desk-sdui-is-as-subtype-checks.md` |
| 20 | Mixin linearization + dispatch | shipped | `desk-sdui-payload-mixins.md` |
| 21 | Extension method dispatch | shipped | `desk-sdui-payload-extensions.md` |
| 22 | Operator overloading | shipped | `desk-sdui-operator-overloading.md` |
| 23 | First-class function values (`PayloadFunctionValue`) | shipped | `desk-sdui-first-class-functions.md` |
| 24 | Type introspection (`runtimeType`) | shipped | `desk-sdui-type-introspection.md` |
| 25 | Allowlist re-verification pass | shipped | `desk-sdui-allowlist-reverify.md` |
| 26 | Cost classifier extension for payload classes | shipped | `desk-sdui-cost-classifier-bucket4.md` |

### Suggested dispatch order

All waves complete. Implementation followed the dependency graph below:

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

**Foundation first**: 15 landed first. After 15, 16 and 19 unblocked the rest. 17-18 were independent;
20-23 fanned out from 17 and ran in parallel waves. 25-26 closed the bucket.

## Orthogonal / housekeeping

| Plan | Status | Notes |
|---|---|---|
| `desk-sdui-augmentations.md` | blocked on Dart | Augmentation library syntax needs `--enable-experiment=macros`; front_end crashes. Re-test when Dart upgrades macro infra. Spike worktree at `desk_sdui-wt-augmentations` (branch `feat/augmentations` @ `cf056c8`). |
| push `main` to remote | pending | No remote configured; nothing to push to yet. Set up `origin` first. |

## Lowerer gaps surfaced but not yet planned

Discovered while consolidating the demo into one screen (2026-05-13). No plan files exist yet.

- Record literals (`(x, y)`) and destructuring (`final (a, b) = pair`)
- Cascade operator `..` in expression position (today only via `SequenceNode` codegen path)
- Multi-statement block-bodied lambdas (`onPressed: () { stmt1; stmt2; }`)
- Block-bodied `@Screen` requires explicit `return`; cannot lower bare statement-form bodies

These should become individual plans before bucket 4 if any payload-class demo depends on them.
