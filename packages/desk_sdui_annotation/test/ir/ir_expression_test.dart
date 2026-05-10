import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('CompareOpNode', () {
    test('equality by op and operands', () {
      const a = CompareOpNode(
        op: CompareOp.gte,
        left: LiteralNode(50),
        right: LiteralNode(100),
      );
      const b = CompareOpNode(
        op: CompareOp.gte,
        left: LiteralNode(50),
        right: LiteralNode(100),
      );
      expect(a, b);
    });

    test('different ops are not equal', () {
      const a = CompareOpNode(
        op: CompareOp.gte,
        left: LiteralNode(1),
        right: LiteralNode(2),
      );
      const b = CompareOpNode(
        op: CompareOp.gt,
        left: LiteralNode(1),
        right: LiteralNode(2),
      );
      expect(a == b, isFalse);
    });
  });

  group('ArithOpNode', () {
    test('stores op and operands', () {
      const node = ArithOpNode(
        op: ArithOp.add,
        left: LiteralNode(1),
        right: LiteralNode(2),
      );
      expect(node.op, ArithOp.add);
    });
  });

  group('LogicOpNode', () {
    test('and/or distinguished', () {
      const a = LogicOpNode(
        op: LogicOp.and,
        left: LiteralNode(true),
        right: LiteralNode(false),
      );
      const b = LogicOpNode(
        op: LogicOp.or,
        left: LiteralNode(true),
        right: LiteralNode(false),
      );
      expect(a == b, isFalse);
    });
  });

  group('NotOpNode', () {
    test('wraps an operand', () {
      const node = NotOpNode(LiteralNode(true));
      expect(node.operand, const LiteralNode(true));
    });
  });

  group('CoalesceOpNode', () {
    test('a ?? b structure', () {
      const node = CoalesceOpNode(
        left: RefNode(['x']),
        right: LiteralNode('default'),
      );
      expect(node.left, isA<RefNode>());
    });
  });

  group('MemberAccessNode', () {
    test('a.b structure', () {
      const node = MemberAccessNode(
        target: RefNode(['data']),
        name: 'title',
      );
      expect(node.name, 'title');
    });
  });

  group('IndexAccessNode', () {
    test('a[k] structure', () {
      const node = IndexAccessNode(
        target: RefNode(['xs']),
        key: LiteralNode(0),
      );
      expect(node.key, isA<LiteralNode>());
    });
  });

  group('LengthOfNode', () {
    test('xs.length structure', () {
      const node = LengthOfNode(RefNode(['xs']));
      expect(node.target, isA<RefNode>());
    });
  });

  group('IsNullCheckNode', () {
    test('a == null structure', () {
      const node = IsNullCheckNode(RefNode(['a']));
      expect(node.operand, isA<RefNode>());
    });
  });

  group('StringInterpNode', () {
    test('parts list of mixed string/IrNode', () {
      const node = StringInterpNode([
        LiteralNode('hello '),
        RefNode(['name'])
      ]);
      expect(node.parts.length, 2);
    });
  });
}
