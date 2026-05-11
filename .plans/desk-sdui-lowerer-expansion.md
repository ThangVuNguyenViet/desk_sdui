# desk_sdui — lowerer expansion: block-body @Screen, `~/`, `ParenthesizedExpression`

**Goal:** Close three concrete lowerer gaps that came up during counter-demo work and were worked around rather than fixed.

1. **Block-body `@Screen` functions** — currently only expression-body (`Widget foo() => ...`) is accepted.
2. **Integer division `~/`** — currently rejected by `expression_lowerer.dart` with "unsupported binary operator".
3. **`ParenthesizedExpression`** — `(a + b) * c` parses as a parenthesized wrapper that the lowerer doesn't unwrap.

**Acceptance:**

1. `@Screen` accepts a block body with a single `return <expr>;` statement and lowers identically to the expression-body form.
2. `a ~/ b` in any expression context lowers to a new `ArithOp.intDiv` and the runtime executes it as `(a ~/ b)`.
3. `(a + b) * c` lowers identically to `a + b` wrapped — parens are transparent.
4. New unit tests cover each.
5. One new demo screen exercises all three.

---

## Task 1 — Block-body `@Screen` (single-return form)

**Files:**
- `packages/desk_sdui_generator/lib/src/screen_lowering/screen_generator.dart` (entry point reading function body)
- `packages/desk_sdui_generator/lib/src/screen_lowering/ast_to_ir.dart` (if body shape is checked here)

Find where the function body is read. Today the code likely does:

```dart
if (body is! ExpressionFunctionBody) {
  throw 'screen body must be expression-bodied';
}
final expr = body.expression;
```

Extend to also accept `BlockFunctionBody` IFF the block contains exactly one statement and that statement is `return <expr>;`. Extract that expression and lower it the same way.

Reject any block with >1 statement or a non-return statement with: `"@Screen body must be a single return statement or expression body; got <kind>"`.

**Test:** Add to `screen_generator_registration_test.dart` (or `closure_lowerer_test.dart`):

```dart
test('block-body @Screen with single return lowers identically', () async {
  const arrowSource = '''
    @Screen('s')
    Widget s() => Text('hi');
  ''';
  const blockSource = '''
    @Screen('s')
    Widget s() {
      return Text('hi');
    }
  ''';
  // Both produce the same IR.
});

test('block-body @Screen with multi-statement rejected', () async {
  // Expect StateError or analyzer rule firing.
});
```

---

## Task 2 — Integer division `~/`

**Files:**
- `packages/desk_sdui_annotation/lib/src/ir/arith_op.dart` — add `intDiv` to enum.
- `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart` — handle `~/` in BinaryExpression switch.
- `packages/desk_sdui/lib/src/resolve.dart` (or wherever ArithOpNode is evaluated) — handle `ArithOp.intDiv`.

Mapping:

```dart
case '~/':
  return ArithOpNode(op: ArithOp.intDiv, left: left, right: right);
```

Runtime evaluator:

```dart
case ArithOp.intDiv:
  return (l as num) ~/ (r as num);
```

**Test:** `expression_lowerer_test.dart`:

```dart
test('integer division ~/', () {
  // 10 ~/ 3 lowers to ArithOpNode(intDiv, 10, 3)
  // runtime evaluates to 3
});
```

---

## Task 3 — `ParenthesizedExpression` unwrap

**File:** `packages/desk_sdui_generator/lib/src/screen_lowering/expression_lowerer.dart`

At the top of `lowerExpression(Expression expr)`:

```dart
if (expr is ParenthesizedExpression) {
  return lowerExpression(expr.expression);
}
```

Parens have no semantic effect — strip them before dispatch.

**Test:**

```dart
test('parenthesized expression unwraps transparently', () {
  // (a + b) * c lowers to ArithOpNode(mul, ArithOpNode(add, a, b), c)
});
```

---

## Task 4 — Demo screen exercising all three

**File:** `packages/desk_sdui_demo/lib/screens/counter_math.dart` (new)

```dart
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

part 'counter_math.sdui.g.dart';

@Screen('counter_math')
Widget counterMath(CounterData data) {
  return Center(
    child: Text(
      '${(data.value * 2 + 1) ~/ 3}',
      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
    ),
  );
}
```

Uses **all three new features**: block body, `~/`, and `( ... )`. If any of the three is broken, build fails.

---

## Task 5 — Verify

```
cd packages/desk_sdui_generator
dart analyze
dart test
```

All tests pass.

```
cd packages/desk_sdui_demo
dart run build_runner build --delete-conflicting-outputs
```

Build succeeds. `counter_math.sdui.json` is produced.

```
dart analyze packages/desk_sdui_demo
```

Clean.

Run the demo app, navigate to `counter_math` screen, verify it renders `((value*2+1) ~/ 3)` correctly.

---

## Out of scope

- Multi-statement function bodies. Keep single-return-only.
- Bitwise operators (`&`, `|`, `^`, `<<`, `>>`). Add when use case appears.
- `if`/`switch` statements inside function bodies (different shape entirely, would need control-flow IR work).
