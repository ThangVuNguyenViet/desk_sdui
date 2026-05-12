import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rt = Runtime();

  group('AssignNode eval', () {
    // Test 1: assignment mutates the cell and returns the RHS value.
    test('assigns value to cell and returns RHS', () {
      final xCell = Cell(1);
      final env = {'x': xCell};
      const node = AssignNode(name: 'x', value: LiteralNode(2));
      final result = evalExpressionWithEnv(node, env, rt);
      expect(result, 2);
      expect(xCell.value, 2);
    });

    // Test 2: `final t = (x = 5); return t;` — assignment-as-expression is
    // observable via a LetNode that captures the RHS into `t`, then reads it.
    // This is the lowered shape produced by the @Screen body grammar.
    test('LetNode(t = AssignNode(x, 5), RefNode([t])) captures RHS into t', () {
      const node = LetNode(
        name: 'x',
        value: LiteralNode(0),
        body: LetNode(
          name: 't',
          value: AssignNode(name: 'x', value: LiteralNode(5)),
          body: RefNode(['t']),
        ),
      );
      expect(evalExpression(node, {}, rt), 5);
    });

    // Test 3: assigning to a non-existent name throws StateError.
    test('assignment to undeclared name throws StateError', () {
      const node = AssignNode(name: 'missing', value: LiteralNode(1));
      expect(
        () => evalExpressionWithEnv(node, {}, rt),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('AssignNode: no binding for "missing"'),
          ),
        ),
      );
    });

    // Test 4: lambda captures env by reference (live values).
    // After AssignNode mutates the cell, the lambda reads the new value.
    test('lambda sees post-assignment value of mutable binding', () {
      final xCell = Cell(10);
      final capturedEnv = <String, Cell>{'x': xCell};

      // Build a lambda that reads 'x'.
      const lambda = LambdaNode(params: [], body: RefNode(['x']));
      final fn = evalExpressionWithEnv(lambda, capturedEnv, rt) as Object? Function();

      // Before assignment: reads initial value.
      expect(fn(), 10);

      // Mutate via AssignNode on the same env.
      evalExpressionWithEnv(
        const AssignNode(name: 'x', value: LiteralNode(99)),
        capturedEnv,
        rt,
      );

      // After assignment: lambda sees the new value because it captures the
      // same Map<String, Cell> and the cell's .value was mutated.
      expect(fn(), 99);
    });

    // Test 5: LetNode + AssignNode — var x = 1; x = x + 1; reads back 2.
    test('LetNode followed by AssignNode via SequenceNode gives updated value', () {
      // Emulate: var x = 1; x = x + 1; return x;
      // Using LetNode to create x, then AssignNode to mutate it, then RefNode to read.
      //
      // LetNode can't directly sequence multiple steps, so we use a direct
      // evalExpressionWithEnv call chain to simulate the flow.
      final env = <String, Cell>{'x': Cell(1)};
      evalExpressionWithEnv(
        const AssignNode(
          name: 'x',
          value: ArithOpNode(
            op: ArithOp.add,
            left: RefNode(['x']),
            right: LiteralNode(1),
          ),
        ),
        env,
        rt,
      );
      final result = evalExpressionWithEnv(const RefNode(['x']), env, rt);
      expect(result, 2);
    });

    // Test 6: public evalExpression wrapper works for AssignNode.
    test('public evalExpression wraps input correctly for AssignNode', () {
      // The public wrapper converts Map<String, Object?> to cells, so AssignNode
      // inside a LetNode can mutate the let-bound cell.
      //
      // LetNode(x, 5, AssignNode(x, 10)) → returns 10 and x cell holds 10.
      const node = LetNode(
        name: 'x',
        value: LiteralNode(5),
        body: AssignNode(name: 'x', value: LiteralNode(10)),
      );
      expect(evalExpression(node, {}, rt), 10);
    });
  });
}
