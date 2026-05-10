import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/src/expression_eval.dart';

void main() {
  group('ExpressionEval', () {
    final input = <String, Object?>{
      'a': 5,
      'b': 3,
      'name': 'World',
      'flag': true,
      'xs': [1, 2, 3],
      'maybe': null,
    };

    test('CompareOp >', () {
      final node = CompareOpNode(
        op: CompareOp.gt,
        left: const RefNode(['a']),
        right: const RefNode(['b']),
      );
      expect(evalExpression(node, input), true);
    });

    test('CompareOp >= equal', () {
      final node = CompareOpNode(
        op: CompareOp.gte,
        left: const RefNode(['a']),
        right: const LiteralNode(5),
      );
      expect(evalExpression(node, input), true);
    });

    test('ArithOp +', () {
      final node = ArithOpNode(
        op: ArithOp.add,
        left: const RefNode(['a']),
        right: const RefNode(['b']),
      );
      expect(evalExpression(node, input), 8);
    });

    test('LogicOp && short-circuits on false', () {
      final node = LogicOpNode(
        op: LogicOp.and,
        left: const LiteralNode(false),
        right: const RefNode(['nonexistent']),
      );
      expect(evalExpression(node, input), false);
    });

    test('LogicOp || short-circuits on true', () {
      final node = LogicOpNode(
        op: LogicOp.or,
        left: const LiteralNode(true),
        right: const RefNode(['nonexistent']),
      );
      expect(evalExpression(node, input), true);
    });

    test('NotOp', () {
      final node = NotOpNode(const RefNode(['flag']));
      expect(evalExpression(node, input), false);
    });

    test('CoalesceOp picks right when left is null', () {
      final node = CoalesceOpNode(
        left: const RefNode(['maybe']),
        right: const LiteralNode('fallback'),
      );
      expect(evalExpression(node, input), 'fallback');
    });

    test('MemberAccess', () {
      final inputWithRecord = {
        'pair': {'first': 1, 'second': 2},
      };
      final node = MemberAccessNode(
        target: const RefNode(['pair']),
        name: 'first',
      );
      expect(evalExpression(node, inputWithRecord), 1);
    });

    test('IndexAccess', () {
      final node = IndexAccessNode(
        target: const RefNode(['xs']),
        key: const LiteralNode(1),
      );
      expect(evalExpression(node, input), 2);
    });

    test('LengthOf list', () {
      final node = LengthOfNode(const RefNode(['xs']));
      expect(evalExpression(node, input), 3);
    });

    test('LengthOf string', () {
      final node = LengthOfNode(const RefNode(['name']));
      expect(evalExpression(node, input), 5);
    });

    test('IsNullCheck true for null', () {
      final node = IsNullCheckNode(const RefNode(['maybe']));
      expect(evalExpression(node, input), true);
    });

    test('IsNullCheck false for non-null', () {
      final node = IsNullCheckNode(const RefNode(['a']));
      expect(evalExpression(node, input), false);
    });

    test('StringInterp concatenates', () {
      final node = StringInterpNode([
        'Hi ',
        const RefNode(['name']),
        '!',
      ]);
      expect(evalExpression(node, input), 'Hi World!');
    });

    test('LiteralNode passes through', () {
      expect(evalExpression(const LiteralNode(42), input), 42);
    });
  });
}
