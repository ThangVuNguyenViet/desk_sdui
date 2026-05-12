# desk_sdui — Feature 22: Operator overloading

**Goal:** Payload classes can declare `operator ==`, `int get hashCode`, `operator +`, `operator []`, etc. Standard Dart operator methods.

**Dependencies:** Feature 17 (method dispatch).

**Architecture:** No new IR nodes — operators lower to `PayloadMethodCallNode` with reserved method names (`'=='`, `'+'`, `'[]'`, `'hashCode'`, etc.). Resolver routes binary/unary/index expressions to `PayloadMethodCallNode` when LHS is a `PayloadInstance`.

**Repo:** `/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/`

---

## Task 1 — Lowerer routing

`BinaryExpression`, `PrefixExpression`, `IndexExpression`, `PropertyAccess('hashCode')`:
- If LHS/operand is a `PayloadInstance` (statically known via the lowerer's class registry), lower to `PayloadMethodCallNode(receiver: LHS, methodName: '<op-symbol>', args: ...)`.
- Otherwise, keep existing lowering (`ArithOpNode`, `CompareOpNode`, `IndexAccessNode`, `GetterNode`).

Operator-name mapping:
- `+`, `-`, `*`, `/`, `~/`, `%`, `<<`, `>>`, `&`, `|`, `^` → binary, lower to method named after the symbol.
- `-x`, `~x` → unary, method name `'unary-'`, `'~'` respectively. (Matches dart_eval's convention; matches Dart spec's `operator unary-`.)
- `x[i]` → `'[]'`. `x[i] = v` → `'[]='`.
- `==` and `hashCode` → `'=='`, `'hashCode'`.

---

## Task 2 — Resolver

No new cases needed — `PayloadMethodCallNode` already handles dispatch. For operators not overridden on the payload class:
- `==` falls back to identity equality (Dart's default `Object.==`).
- `hashCode` falls back to identity hash.
- `+`/`-`/`*`/`[]` etc. on an unoverridden payload class throws `NoSuchMethodError` — matches Dart semantics.

---

## Task 3 — Codegen lint: `==` and `hashCode` paired

When lowering a class that overrides `==` but not `hashCode` (or vice versa), emit a codegen warning:

> Class `Order` overrides `==` but not `hashCode`. Two equal instances must produce the same hashCode.

Suppression via `// ignore: sdui_eq_hashcode`.

---

## Task 4 — Default `toString`

If a payload class doesn't declare `toString`, synthesize a default at class registration:

```dart
'<className>(${fields.entries.map((e) => "${e.key}: ${e.value}").join(", ")})'
```

Implemented inside `PayloadInstance.toString` already (Feature 15). No codegen work needed — the runtime default applies whenever the user calls `someInstance.toString()`.

---

## Task 5 — Tests + demo

Tests: `+` on a payload class; `==` overridden gives logical equality; `==` not overridden gives identity; `[]` indexer dispatches to `operator []`; `hashCode` warning for `==`-only override.

Demo: `class Vector2 { final double x, y; Vector2(this.x, this.y); Vector2 operator +(Vector2 o) => Vector2(x + o.x, y + o.y); }`; use `v1 + v2` in a screen.

---

## Out of scope

- `noSuchMethod` override on payload classes — proxy-pattern support; defer.
- Tear-off of operators.
- Bitwise operators (`<<`, `>>`, etc.) — same shape; add piecemeal if needed.

---

## Verify commands

(Standard suite.)
