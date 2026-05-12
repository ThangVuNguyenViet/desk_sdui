# Parser surface: desk_sdui's minimal IR vs flutter_eval

`flutter_eval` runs the dart_eval interpreter, which accepts most of the Dart language. `desk_sdui` lowers a restricted Dart subset to a fixed set of IR node kinds defined in `packages/desk_sdui_annotation/lib/src/ir/ir_node.dart`. Anything outside that set is a codegen error on the author's machine.

This doc has two parts:
1. **What each system accepts** (the side-by-side table).
2. **Why we didn't pick flutter_eval even if we disciplined ourselves to its safe subset** (the perf section).

## The principle behind what we accept vs reject

> The per-element cost of any iteration must be O(1) in native Dart, not O(IR-tree-size) in our interpreter.

The cost rule from the design spec is `O(IR-tree-size + data-shape-size)` — additive. The moment a construct turns it into a product (e.g. re-resolving the IR interpreter once per data-shape element), frame time becomes data-dependent and the rule breaks. Most "❌" rows below trace back to this.

Other axes used below:
- **Allowlist** — the construct would let the payload introduce new behavior not present in the reviewed binary.
- **Not yet** — no architectural objection; the lowerer hasn't been written.

## Side-by-side table — what each system accepts

| Construct | desk_sdui | flutter_eval | Why we drew the line here |
|---|---|---|---|
| **Literals** (int, double, String, bool, null) | ✅ `LiteralNode` / `ConstNode` | ✅ | Trivial. |
| **Lists / Maps / Records** | ✅ `ListNode` / `MapNode` / `RecordNode` | ✅ | Bounded by IR-tree-size. |
| **Const value-type ctors** (`EdgeInsets.all`) | ✅ `ValueCtorNode` | ✅ | Registered via `registerValueBuilder`. |
| **Variable / param reference** | ✅ `RefNode(['book', 'pages'])` | ✅ | O(path-length). |
| **Property / getter chains** | ✅ `MemberAccessNode` / `GetterNode` | ✅ | Lowerer splits data-shape traversal from registered-getter dispatch. |
| **Index access** (`list[i]`, `map[k]`) | ✅ `IndexAccessNode` | ✅ | O(1) native dispatch. |
| **String interpolation** | ✅ `StringInterpNode` | ✅ | Bounded by IR-tree-size. |
| **Arithmetic / comparison / logic ops** (`+`, `~/`, `==`, `&&`, `??`) | ✅ | ✅ | Per-op cost is constant. |
| **Inline conditional** (`a ? b : c`) | ✅ `ConditionalNode` | ✅ | Single branch resolved per build. |
| **Collection-for** (`[for (x in xs) ...]`) | ✅ `ForNode` | ✅ | Walks data once, instantiates one widget per element. Native per-element cost. |
| **Spread** (`[...xs, y]`) | ✅ `SpreadNode` | ✅ | Same shape as for-element. |
| **Method call on registered receiver** | ✅ `MethodCallNode` | ✅ | One hashmap lookup + native dispatch. |
| **Widget construction** | ✅ `WidgetNode` / `BuiltinWidgetNode` | ✅ | Closure produces native widget. |
| **Event handler reference** (`onPressed: vm.increment`) | ✅ `EventNode(['vm', 'increment'])` | ✅ | Tear-off of a registered method; no body to evaluate. |
| **Wildcard patterns** (`_`) | ✅ as `LiteralNode(null)` | ✅ | Lowered at parse time. |
| **Block-body `@Screen`** with single `return` | ✅ | ✅ | Lowered to expression body. |
| **`if` / `else` as statements** | ❌ — only as expressions (`ConditionalNode`) | ✅ | Cost rule. Statement-level control flow implies sequenced side effects. |
| **`for` / `while` / `do` loops with bodies** | ❌ — only collection-for | ✅ | Cost rule. Statement loops imply state mutation per iteration. |
| **Local variable declarations** in a screen body | ❌ | ✅ | Cost rule. Locals require a scope stack and re-resolution. |
| **Anonymous closures with bodies** (`.where((p) => p.startsWith('p'))`) | ❌ — no `LambdaNode` | ✅ | Cost rule. Re-resolves the closure body N times per collection op. |
| **Cascades** (`obj..a()..b()`) | ❌ | ✅ | Sequenced side effects; not expressible in expression-tree IR. |
| **`async` / `await` / `Future` chaining** | ❌ | ✅ (with documented gaps) | Resolver is synchronous per frame. |
| **Generators (`sync*` / `async*`)** | ❌ | ❌ (documented missing in dart_eval) | Both skip. |
| **`try` / `catch` / `throw`** | ❌ | ✅ | Same as statement control flow. |
| **User-defined function declarations** in the payload | ❌ | ✅ | Allowlist. |
| **Class / mixin / extension declarations** in the payload | ❌ | ✅ | Allowlist. |
| **Pattern matching** (`switch` expressions, destructuring beyond `_`) | ❌ | ✅ | Not yet. |
| **Generic instantiation** in the payload (`List<MyType>()`) | ❌ — generics erased at IR level | ✅ | Registered ctors are closures keyed by simple class name. |

## Why not flutter_eval, even with discipline?

A reasonable objection to the above: "fine, but we could just *choose* to use only the safe subset in flutter_eval. The full-Dart support doesn't *force* us to write lambdas inside `.where()`. Why pay the discipline tax to roll our own IR?"

This section ignores safety / allowlist arguments and focuses on the perf-only reason: **even on the safe subset both systems support, flutter_eval is structurally slower per frame than our resolver, and the gap shows up in animation hot paths where it matters most.**

### Per-construct cost, even within the "safe" subset

Take the simplest possible row from the table — constructing a `Column(children: [...])`. Both systems support it cleanly.

**desk_sdui resolve path:**
1. Walk `WidgetNode('Column', args)`.
2. One hashmap lookup: `_widgets['Column']` → `SduiWidgetBuilder` closure.
3. Resolve each arg in `args` (recursive descent over the args map).
4. Call the closure: `(args) => Column(children: args['children'] as List<Widget>)`.
5. AOT-compiled native `Column` ctor runs.

Step 2 is one map get on an already-interned string key. Step 4 is one native closure invocation. The casts inside the closure are AOT-erased. **Per WidgetNode: ~50-100 ns** (from the design spec).

**flutter_eval evaluate path for the same source:**
1. Bytecode dispatch executes the `Column(...)` call site.
2. Look up the `Column` type by `BridgeTypeRef`.
3. For each argument, evaluate the bytecode expression that produces it, boxing the result in a `$Value` wrapper.
4. Invoke the bridge: `$Column.$new(runtime, target, args)`.
5. Inside the bridge, unwrap each `$Value` via `.$value` / `.$reified`, cast, pass to the native `Column` ctor.
6. Wrap the resulting `Column` in `$Column.wrap(...)` to feed it back to the interpreter's value stack.
7. AOT-compiled native `Column` ctor runs (same as ours, but reached after far more work).

Steps 1-3 and 5-6 are pure interpreter overhead that desk_sdui doesn't pay. Public dart_eval benchmarks suggest **5-50× slower per call than native**, depending on shape. For widget construction specifically — small arg lists, no generics — call it ~500-2000 ns per `Column` evaluation, vs our ~100 ns.

For a single screen build that's the difference between a few µs and a few hundred µs. Either way well under 16 ms, so cold-start and one-shot rebuilds are fine.

### Where the gap stops being negligible: animation hot paths

The design spec is explicit about this:

> flutter_eval's interpreter runs continuously — including inside animation callbacks invoked at 60Hz. Per-op interpreter cost compounds with per-frame work, eating frame budget.

A screen with an animated counter (our `counter_stress` demo, ~500 chips animating per frame) rebuilds at frame rate. For each frame:
- **desk_sdui:** the IR was resolved once into a widget tree, and Flutter's framework handles the per-frame diff/rebuild natively. The resolver doesn't re-run on every frame for unchanged subtrees; only reactive bindings re-resolve their slice.
- **flutter_eval (disciplined to the same subset):** the bytecode that constructs the widget tree re-evaluates on every dirty rebuild. Even with an identical source-level subset, every `Column`, `Padding`, `Text`, `SizedBox` goes through interpreter dispatch + `$Value` boxing per frame.

At ~500 nodes × ~1 µs per node × 60 Hz = ~30 ms/sec of interpreter overhead, all of it pure waste relative to a native rebuild. On a phone CPU it's enough to chew into the 16 ms frame budget visibly.

This isn't a "interpreter is slow" cliché — it's specifically about per-frame, per-node overhead that compounds with animation rebuild rates. Pulling the same source through dart_eval bytecode means paying for it every time, while we pay once at lower per-step cost.

### Binary cost is paid regardless

flutter_eval ships the dart_eval interpreter (~1.5-2 MB) and the bridge metadata (`BridgeClassDef` for every exposed type, with full Dart type info) regardless of how restricted the actual payloads are. Our runtime is hashmap + closures, in the tens of KB even with hundreds of entries (measured: 304 KB RSS for 341 registrations — see `runtime-cost-measurements.md`).

If discipline keeps us inside the safe subset, we still pay the full interpreter binary cost. That's a fixed perf tax on app startup, install size, and (on web) initial download.

### The summary

Disciplining yourself to the safe subset eliminates the *correctness* hazards of flutter_eval. It does not eliminate:

1. **Per-node interpreter overhead** that exists for every construct, including the safe ones — ~5-50× our cost per evaluation.
2. **Per-frame compounding** in animations / reactive rebuilds, where that overhead multiplies by rebuild rate.
3. **Binary cost** of the interpreter itself, independent of payload size or restriction.

Codegen-to-IR was chosen over flutter_eval-with-discipline because the gap above is what the cost rule was designed to close. Discipline addresses what flutter_eval *might* do; the resolver design addresses what it *does* even on the simplest possible payload.

## Author guide — safe vs caution table

The constructs above tell you what desk_sdui *accepts*. This table tells you what to *use* and where, framed by performance impact in the call site (build path vs reactive binding vs action handler). The tiers correspond to diagnostics the codegen-time classifier emits (see the [expressiveness roadmap](../../.plans/desk-sdui-bucket-1-and-2-roadmap.md) — Feature 13).

| Tier | Where used safely | Examples | What the toolchain says |
|---|---|---|---|
| **✅ Safe everywhere** | Build, signal bindings, actions | Literals, refs, ternary (`?:`), collection-for, spread, sync lambdas in collection ops, `final` locals (`LetNode`), expression bodies, registered method calls, pattern matching | Silent. Cost is bounded by IR-size + data-shape-size, additive, native dispatch. |
| **✅ Safe in actions, info diagnostic in build/signal** | Statement-form helper functions called from anywhere; per-frame impact depends on data size | `final list = <Widget>[]; for (final item in items) list.add(Chip(item));` factored into a helper called from build | Info: "function `<name>` is O(N) in `<arg>`; called from a build path. Fine for small N; consider collection-for if N grows or N is unknown." |
| **⚠️ Caution everywhere** | Anywhere; toolchain flags the risk regardless of context | `while (! converged) { step(); }` (no static iteration bound), recursion without size-decrease guarantee | Warning: "no upper iteration bound" / "free recursion may not terminate." Author owns correctness. |
| **🔒 Action-only by Flutter contract** | Action handlers only — Flutter forbids these in build | `await` expressions, `async` lambdas with bodies, `try/catch` around await | Silent in action context. Outside action context: rejected by Dart's own type system (`Future<X>` isn't assignable to `X`) before reaching the lowerer. |
| **❌ Never** | Not supported in any context | Payload-defined classes / mixins / extensions, generators (`sync*` / `async*`), runtime type construction, async resolver paths | Hard error at lowering. These are the allowlist boundary; they would re-introduce flutter_eval's safety hazards. |

### How the tiers map to perf properties

- **Tier ✅ Safe everywhere** preserves the original cost rule (`O(IR + data)`, additive). Use freely.
- **Tier ✅ Safe in actions, info in build** is where the cost rule conditionally bends. The data-dependent loop is fine if N is small (a 3-item filter is invisible at 60 Hz). The toolchain informs you so you can decide.
- **Tier ⚠️ Caution everywhere** is correctness, not just perf. Unbounded loops and free recursion can hang the UI even in action handlers — the toolchain wants you to confirm termination.
- **Tier 🔒 Action-only** is enforced jointly by Flutter (sync `build`) and our lowerer (`ActionSequenceNode`-scoped async). You can't accidentally use these in the wrong place.
- **Tier ❌ Never** is the allowlist boundary. These features are why the runtime can be reviewed once and trusted; opening them would mean payloads ship new behavior.

### Suppressing diagnostics

Toolchain diagnostics are non-blocking. If you know your N is bounded by a UI constraint (e.g., max 20 form fields), suppress at the call site:

```dart
// ignore: sdui_potential_cost
Column(children: renderFields(form.fields))
```

The intent of the suppression is documented at the point of trade-off — the reviewer reading your code sees both the warning and your reason for ignoring it.

### Why warn, not reject

We can statically detect data-dependent iteration in a build path. We don't reject it because:

1. **N is often small.** A 3-element loop runs in nanoseconds even interpreted; rejecting it adds friction without protecting anything.
2. **Authors know their data shape; the toolchain doesn't.** A "list of form fields" has bounded N by UI design; a "list of search results" doesn't. Same syntax, different cost reality.
3. **flutter_eval doesn't surface this at all.** Warning is *more* author-friendly than silence — and still more author-friendly than rejection. The toolchain becomes a collaborator, not a gatekeeper.

The cost-rule advantage over flutter_eval persists either way: native value flow, no boxing, ~30-50 KB total bucket-3 runtime cost vs their ~1.5-2 MB, allowlist boundary intact. The warning system is how we keep the advantage *visible* to authors without rejecting natural Dart they have good reasons to write.
