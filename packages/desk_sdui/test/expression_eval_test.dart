import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/expression_eval.dart';

void main() {
  group('ExpressionEval', () {
    final rt = Runtime();
    final input = <String, Object?>{
      'a': 5,
      'b': 3,
      'name': 'World',
      'flag': true,
      'xs': [1, 2, 3],
      'maybe': null,
    };

    test('CompareOp >', () {
      const node = CompareOpNode(
        op: CompareOp.gt,
        left: RefNode(['a']),
        right: RefNode(['b']),
      );
      expect(evalExpression(node, input, rt), true);
    });

    test('CompareOp >= equal', () {
      const node = CompareOpNode(
        op: CompareOp.gte,
        left: RefNode(['a']),
        right: LiteralNode(5),
      );
      expect(evalExpression(node, input, rt), true);
    });

    test('ArithOp +', () {
      const node = ArithOpNode(
        op: ArithOp.add,
        left: RefNode(['a']),
        right: RefNode(['b']),
      );
      expect(evalExpression(node, input, rt), 8);
    });

    test('LogicOp && short-circuits on false', () {
      const node = LogicOpNode(
        op: LogicOp.and,
        left: LiteralNode(false),
        right: RefNode(['nonexistent']),
      );
      expect(evalExpression(node, input, rt), false);
    });

    test('LogicOp || short-circuits on true', () {
      const node = LogicOpNode(
        op: LogicOp.or,
        left: LiteralNode(true),
        right: RefNode(['nonexistent']),
      );
      expect(evalExpression(node, input, rt), true);
    });

    test('NotOp', () {
      const node = NotOpNode(RefNode(['flag']));
      expect(evalExpression(node, input, rt), false);
    });

    test('CoalesceOp picks right when left is null', () {
      const node = CoalesceOpNode(
        left: RefNode(['maybe']),
        right: LiteralNode('fallback'),
      );
      expect(evalExpression(node, input, rt), 'fallback');
    });

    test('MemberAccess', () {
      final inputWithRecord = {
        'pair': {'first': 1, 'second': 2},
      };
      const node = MemberAccessNode(
        target: RefNode(['pair']),
        name: 'first',
      );
      expect(evalExpression(node, inputWithRecord, rt), 1);
    });

    test('IndexAccess', () {
      const node = IndexAccessNode(
        target: RefNode(['xs']),
        key: LiteralNode(1),
      );
      expect(evalExpression(node, input, rt), 2);
    });

    test('LengthOf list', () {
      const node = LengthOfNode(RefNode(['xs']));
      expect(evalExpression(node, input, rt), 3);
    });

    test('LengthOf string', () {
      const node = LengthOfNode(RefNode(['name']));
      expect(evalExpression(node, input, rt), 5);
    });

    test('IsNullCheck true for null', () {
      const node = IsNullCheckNode(RefNode(['maybe']));
      expect(evalExpression(node, input, rt), true);
    });

    test('IsNullCheck false for non-null', () {
      const node = IsNullCheckNode(RefNode(['a']));
      expect(evalExpression(node, input, rt), false);
    });

    test('StringInterp concatenates', () {
      const node = StringInterpNode([
        'Hi ',
        RefNode(['name']),
        '!',
      ]);
      expect(evalExpression(node, input, rt), 'Hi World!');
    });

    test('LiteralNode passes through', () {
      expect(evalExpression(const LiteralNode(42), input, rt), 42);
    });
  });
}
