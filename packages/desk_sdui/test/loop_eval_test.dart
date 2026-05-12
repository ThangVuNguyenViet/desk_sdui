import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rt = Runtime();

  // ---------------------------------------------------------------------------
  // WhileNode
  // ---------------------------------------------------------------------------

  group('WhileNode', () {
    // Test 1: `var i = 0; while (i < 5) { i = i + 1; }` runs 5 iterations.
    test('counter while(i < 5) runs 5 times', () {
      final i = Cell(0);
      final env = <String, Cell>{'i': i};
      final node = WhileNode(
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(5),
        ),
        body: AssignNode(
          name: 'i',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['i']),
            right: const LiteralNode(1),
          ),
        ),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(i.value, 5);
    });

    // Test 2: WhileNode with false initial condition — body never runs.
    test('while(false) body never runs', () {
      final x = Cell(99);
      final env = <String, Cell>{'x': x};
      final node = WhileNode(
        condition: const LiteralNode(false),
        body: const AssignNode(name: 'x', value: LiteralNode(0)),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 99); // unchanged
    });

    // Test 3: WhileNode with break exits early.
    test('while with break exits early', () {
      final i = Cell(0);
      final env = <String, Cell>{'i': i};
      // while (i < 100) { if (i == 3) break; i = i + 1; }
      final node = WhileNode(
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(100),
        ),
        body: BlockNode(statements: [
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.eq,
              left: const RefNode(['i']),
              right: const LiteralNode(3),
            ),
            then: const BreakNode(),
          ),
          AssignNode(
            name: 'i',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['i']),
              right: const LiteralNode(1),
            ),
          ),
        ]),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>()); // break is consumed by the loop
      expect(i.value, 3);
    });

    // Test 4: WhileNode with continue skips rest of body, re-checks condition.
    test('while with continue skips rest of body', () {
      final i = Cell(0);
      final sum = Cell(0);
      final env = <String, Cell>{'i': i, 'sum': sum};
      // while (i < 5) {
      //   i = i + 1;
      //   if (i == 3) continue;  // skip sum += i when i == 3
      //   sum = sum + i;
      // }
      // Expected: sum = 1 + 2 + 4 + 5 = 12 (i==3 is skipped)
      final node = WhileNode(
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(5),
        ),
        body: BlockNode(statements: [
          AssignNode(
            name: 'i',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['i']),
              right: const LiteralNode(1),
            ),
          ),
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.eq,
              left: const RefNode(['i']),
              right: const LiteralNode(3),
            ),
            then: const ContinueNode(),
          ),
          AssignNode(
            name: 'sum',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['sum']),
              right: const RefNode(['i']),
            ),
          ),
        ]),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(sum.value, 12);
    });

    // Test 5: WhileNode with return propagates FlowReturn out of the loop.
    test('while with return propagates FlowReturn', () {
      final i = Cell(0);
      final env = <String, Cell>{'i': i};
      final node = WhileNode(
        condition: const LiteralNode(true),
        body: BlockNode(statements: [
          AssignNode(
            name: 'i',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['i']),
              right: const LiteralNode(1),
            ),
          ),
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.eq,
              left: const RefNode(['i']),
              right: const LiteralNode(2),
            ),
            then: const ReturnNode(value: LiteralNode(42)),
          ),
        ]),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowReturn>());
      expect((result as FlowReturn).value, 42);
      expect(i.value, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // DoNode
  // ---------------------------------------------------------------------------

  group('DoNode', () {
    // Test 6: DoNode body runs at least once even when condition initially false.
    test('do-while body runs once even with false initial condition', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = DoNode(
        body: const AssignNode(name: 'x', value: LiteralNode(1)),
        condition: const LiteralNode(false),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 1); // body ran once
    });

    // Additional: DoNode runs multiple times when condition is true.
    test('do-while runs until condition false', () {
      final i = Cell(0);
      final env = <String, Cell>{'i': i};
      final node = DoNode(
        body: AssignNode(
          name: 'i',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['i']),
            right: const LiteralNode(1),
          ),
        ),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(3),
        ),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(i.value, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // ImperativeForNode
  // ---------------------------------------------------------------------------

  group('ImperativeForNode', () {
    // Test 7: Standard counted loop runs N times.
    test('for(int i=0; i<5; i++) runs 5 times', () {
      final counter = Cell(0);
      final env = <String, Cell>{'counter': counter};
      // for (var i = 0; i < 5; i = i + 1) { counter = counter + 1; }
      final node = ImperativeForNode(
        init: const LetStatementNode(
            name: 'i', value: LiteralNode(0), isFinal: false),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(5),
        ),
        update: AssignNode(
          name: 'i',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['i']),
            right: const LiteralNode(1),
          ),
        ),
        body: AssignNode(
          name: 'counter',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['counter']),
            right: const LiteralNode(1),
          ),
        ),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(counter.value, 5);
    });

    // Test 8: null condition + body with break (infinite-until-break).
    test('for(;;) with break exits', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      // for (;;) { x = x + 1; if (x == 3) break; }
      final node = ImperativeForNode(
        body: BlockNode(statements: [
          AssignNode(
            name: 'x',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['x']),
              right: const LiteralNode(1),
            ),
          ),
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.eq,
              left: const RefNode(['x']),
              right: const LiteralNode(3),
            ),
            then: const BreakNode(),
          ),
        ]),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 3);
    });

    // Test 9: loop variable is block-scoped (not visible after loop).
    test('loop variable is not visible outside ImperativeForNode', () {
      final outer = <String, Cell>{};
      final node = ImperativeForNode(
        init: const LetStatementNode(
            name: 'i', value: LiteralNode(0), isFinal: false),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(3),
        ),
        update: AssignNode(
          name: 'i',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['i']),
            right: const LiteralNode(1),
          ),
        ),
        body: const BlockNode(statements: []),
      );
      executeStatement(node, outer, rt);
      // 'i' must not leak into the outer env.
      expect(outer.containsKey('i'), isFalse);
    });

    // Test 10: nested loops — inner break doesn't exit outer loop.
    test('nested loops: inner break does not exit outer loop', () {
      final outer = Cell(0);
      final env = <String, Cell>{'outer': outer};
      // for (var i = 0; i < 3; i = i + 1) {
      //   outer = outer + 1;
      //   for (var j = 0; j < 10; j = j + 1) {
      //     if (j == 1) break;
      //   }
      // }
      // outer should be incremented 3 times (inner loop always breaks at j==1)
      final inner = ImperativeForNode(
        init: const LetStatementNode(
            name: 'j', value: LiteralNode(0), isFinal: false),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['j']),
          right: const LiteralNode(10),
        ),
        update: AssignNode(
          name: 'j',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['j']),
            right: const LiteralNode(1),
          ),
        ),
        body: IfStatementNode(
          cond: CompareOpNode(
            op: CompareOp.eq,
            left: const RefNode(['j']),
            right: const LiteralNode(1),
          ),
          then: const BreakNode(),
        ),
      );
      final outerLoop = ImperativeForNode(
        init: const LetStatementNode(
            name: 'i', value: LiteralNode(0), isFinal: false),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(3),
        ),
        update: AssignNode(
          name: 'i',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['i']),
            right: const LiteralNode(1),
          ),
        ),
        body: BlockNode(statements: [
          AssignNode(
            name: 'outer',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['outer']),
              right: const LiteralNode(1),
            ),
          ),
          inner,
        ]),
      );
      final result = executeStatement(outerLoop, env, rt);
      expect(result, isA<FlowNormal>());
      expect(outer.value, 3); // outer loop ran 3 full iterations
    });

    // Regression: multiple updaters via BlockNode advance all loop variables
    // each iteration. Mirrors `for (var i=0, j=0; i<3; i = i+1, j = j+2)`
    // lowering which wraps updaters in a BlockNode.
    test('ImperativeForNode update as BlockNode advances multiple vars', () {
      final outerI = Cell(-1);
      final outerJ = Cell(-1);
      final env = <String, Cell>{'outerI': outerI, 'outerJ': outerJ};
      // for (var i=0, j=0; i<3; i = i+1, j = j+2) { outerI = i; outerJ = j; }
      final node = ImperativeForNode(
        init: const BlockNode(statements: [
          LetStatementNode(name: 'i', value: LiteralNode(0), isFinal: false),
          LetStatementNode(name: 'j', value: LiteralNode(0), isFinal: false),
        ]),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(3),
        ),
        update: BlockNode(statements: [
          AssignNode(
            name: 'i',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['i']),
              right: const LiteralNode(1),
            ),
          ),
          AssignNode(
            name: 'j',
            value: ArithOpNode(
              op: ArithOp.add,
              left: const RefNode(['j']),
              right: const LiteralNode(2),
            ),
          ),
        ]),
        body: BlockNode(statements: [
          const AssignNode(name: 'outerI', value: RefNode(['i'])),
          const AssignNode(name: 'outerJ', value: RefNode(['j'])),
        ]),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      // After 3 iterations: i went 0,1,2 then update to 3 exits cond; j went
      // 0,2,4 then update to 6 (but body captures last seen values).
      // Body runs for i in [0,1,2] → last body sees i=2, j=4.
      expect(outerI.value, 2);
      expect(outerJ.value, 4);
    });

    // Inter-iteration scope isolation: a LetStatementNode in the body
    // rebinds fresh each iteration (does not bleed across passes).
    // Each iteration: let x = i; outer = x. Asserts outer == final i after loop.
    test('LetStatementNode in loop body rebinds fresh each iteration', () {
      final outer = Cell(-1);
      final env = <String, Cell>{'outer': outer};
      final node = ImperativeForNode(
        init: const LetStatementNode(
            name: 'i', value: LiteralNode(0), isFinal: false),
        condition: CompareOpNode(
          op: CompareOp.lt,
          left: const RefNode(['i']),
          right: const LiteralNode(3),
        ),
        update: AssignNode(
          name: 'i',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['i']),
            right: const LiteralNode(1),
          ),
        ),
        body: BlockNode(statements: [
          // x is final, declared fresh per iteration. If it leaked, the
          // second iteration's `final x = i` would throw (re-binding a final).
          const LetStatementNode(
              name: 'x', value: RefNode(['i']), isFinal: true),
          const AssignNode(name: 'outer', value: RefNode(['x'])),
        ]),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      // outer should reflect the last iteration's i (which is 2).
      expect(outer.value, 2);
    });
  });
}
