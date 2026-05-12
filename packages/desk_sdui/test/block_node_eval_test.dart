import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rt = Runtime();

  group('ControlFlow / executeStatement', () {
    // Test 1: Empty block returns FlowNormal.
    test('empty block returns FlowNormal', () {
      final env = <String, Cell>{};
      const node = BlockNode(statements: []);
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
    });

    // Test 2: Block with expression-statements evaluates all of them.
    test('block evaluates all expression-statements in order', () {
      // Use AssignNode side-effects to verify ordering.
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      // x = 1; x = x + 10; → x should be 11
      final node = BlockNode(statements: [
        const AssignNode(name: 'x', value: LiteralNode(1)),
        AssignNode(
          name: 'x',
          value: ArithOpNode(
            op: ArithOp.add,
            left: const RefNode(['x']),
            right: const LiteralNode(10),
          ),
        ),
      ]);
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 11);
    });

    // Test 3: Break mid-block aborts the rest and returns FlowBreak.
    test('break mid-block aborts remaining statements', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = BlockNode(statements: [
        const AssignNode(name: 'x', value: LiteralNode(1)),
        const BreakNode(),
        const AssignNode(name: 'x', value: LiteralNode(99)), // should NOT run
      ]);
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowBreak>());
      expect(x.value, 1); // only first assignment ran
    });

    // Test 4: Continue mid-block aborts the rest and returns FlowContinue.
    test('continue mid-block aborts remaining statements', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = BlockNode(statements: [
        const AssignNode(name: 'x', value: LiteralNode(5)),
        const ContinueNode(),
        const AssignNode(name: 'x', value: LiteralNode(99)), // should NOT run
      ]);
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowContinue>());
      expect(x.value, 5);
    });

    // Test 5: Return(42) mid-block aborts rest, returns FlowReturn(42).
    test('return mid-block aborts rest and returns FlowReturn with value', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = BlockNode(statements: [
        const AssignNode(name: 'x', value: LiteralNode(7)),
        const ReturnNode(value: LiteralNode(42)),
        const AssignNode(name: 'x', value: LiteralNode(99)), // should NOT run
      ]);
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowReturn>());
      expect((result as FlowReturn).value, 42);
      expect(x.value, 7);
    });

    // Test 6: IfStatementNode with true cond executes then-branch.
    test('IfStatementNode true cond executes then-branch', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = IfStatementNode(
        cond: const LiteralNode(true),
        then: const AssignNode(name: 'x', value: LiteralNode(100)),
        else_: const AssignNode(name: 'x', value: LiteralNode(200)),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 100);
    });

    // Test 7: IfStatementNode false cond + null else returns FlowNormal.
    test('IfStatementNode false cond with no else returns FlowNormal', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = IfStatementNode(
        cond: const LiteralNode(false),
        then: const AssignNode(name: 'x', value: LiteralNode(100)),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 0); // unchanged
    });

    // Test 8: IfStatementNode false cond + non-null else executes else-branch.
    test('IfStatementNode false cond with else executes else-branch', () {
      final x = Cell(0);
      final env = <String, Cell>{'x': x};
      final node = IfStatementNode(
        cond: const LiteralNode(false),
        then: const AssignNode(name: 'x', value: LiteralNode(100)),
        else_: const AssignNode(name: 'x', value: LiteralNode(200)),
      );
      final result = executeStatement(node, env, rt);
      expect(result, isA<FlowNormal>());
      expect(x.value, 200);
    });

    // Test 9: Block scoping — LetStatementNode inside an inner block does not
    // leak into the outer env.
    test('LetStatementNode inside inner block does not leak to outer scope', () {
      final outerEnv = <String, Cell>{};
      final innerBlock = BlockNode(statements: [
        const LetStatementNode(name: 'inner', value: LiteralNode(42), isFinal: false),
      ]);
      executeStatement(innerBlock, outerEnv, rt);
      // 'inner' was only in the scoped copy inside BlockNode.
      expect(outerEnv.containsKey('inner'), isFalse);
    });

    // Test 10: Cell mutations inside a block ARE visible to the outer scope
    // because _Cell objects are shared by reference.
    test('outer Cell mutations from inside block ARE visible outside', () {
      final x = Cell(0);
      final outerEnv = <String, Cell>{'x': x};
      final innerBlock = BlockNode(statements: [
        const AssignNode(name: 'x', value: LiteralNode(999)),
      ]);
      executeStatement(innerBlock, outerEnv, rt);
      // Mutation is visible because the Cell object is shared.
      expect(x.value, 999);
    });
  });
}
