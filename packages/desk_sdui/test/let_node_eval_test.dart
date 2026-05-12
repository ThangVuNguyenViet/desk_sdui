import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/expression_eval.dart';

void main() {
  group('LetNode eval', () {
    final rt = Runtime();

    test('single let binds name and body sees it', () {
      const node = LetNode(
        name: 't',
        value: LiteralNode(42),
        body: RefNode(['t']),
      );
      expect(evalExpression(node, {}, rt), 42);
    });

    test('nested lets accumulate bindings', () {
      const node = LetNode(
        name: 'a',
        value: LiteralNode(1),
        body: LetNode(
          name: 'b',
          value: LiteralNode(2),
          body: ArithOpNode(
            op: ArithOp.add,
            left: RefNode(['a']),
            right: RefNode(['b']),
          ),
        ),
      );
      expect(evalExpression(node, {}, rt), 3);
    });

    test('inner let shadows outer', () {
      const node = LetNode(
        name: 'x',
        value: LiteralNode(1),
        body: LetNode(
          name: 'x',
          value: LiteralNode(2),
          body: RefNode(['x']),
        ),
      );
      expect(evalExpression(node, {}, rt), 2);
    });

    test('outer scope is unaffected after let', () {
      const node = LetNode(
        name: 't',
        value: LiteralNode(42),
        body: RefNode(['t']),
      );
      final outer = <String, Object?>{};
      expect(evalExpression(node, outer, rt), 42);
      // Second eval with same outer map should not see the binding
      expect(evalExpression(const RefNode(['t']), outer, rt), isNull);
    });

    test('let value uses outer-scope binding', () {
      const node = LetNode(
        name: 't',
        value: RefNode(['outer']),
        body: RefNode(['t']),
      );
      final outer = <String, Object?>{'outer': 5};
      expect(evalExpression(node, outer, rt), 5);
    });
  });
}
