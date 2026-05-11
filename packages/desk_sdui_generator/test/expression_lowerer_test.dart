import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/expression_lowerer.dart';
import 'package:test/test.dart';

void main() {
  IrNode lower(String src) {
    final result = parseString(content: 'void _() { $src; }');
    final func = result.unit.declarations.single as FunctionDeclaration;
    final body = func.functionExpression.body as BlockFunctionBody;
    final stmt = body.block.statements.single as ExpressionStatement;
    return lowerExpression(stmt.expression);
  }

  test('integer literal', () {
    final ir = lower('42');
    expect(ir, isA<LiteralNode>());
    expect((ir as LiteralNode).value, 42);
  });

  test('string literal', () {
    final ir = lower("'hello'");
    expect((ir as LiteralNode).value, 'hello');
  });

  test('binary +', () {
    final ir = lower('a + b') as ArithOpNode;
    expect(ir.op, ArithOp.add);
    expect((ir.left as RefNode).path, ['a']);
    expect((ir.right as RefNode).path, ['b']);
  });

  test('binary >=', () {
    final ir = lower('count >= 5') as CompareOpNode;
    expect(ir.op, CompareOp.gte);
    expect((ir.right as LiteralNode).value, 5);
  });

  test('logical &&', () {
    final ir = lower('a && b') as LogicOpNode;
    expect(ir.op, LogicOp.and);
  });

  test('prefix !', () {
    final ir = lower('!flag') as NotOpNode;
    expect((ir.operand as RefNode).path, ['flag']);
  });

  test('null-coalesce ??', () {
    final ir = lower('a ?? b') as CoalesceOpNode;
    expect((ir.left as RefNode).path, ['a']);
    expect((ir.right as RefNode).path, ['b']);
  });

  test('member access a.b.c', () {
    final ir = lower('a.b.c') as RefNode;
    expect(ir.path, ['a', 'b', 'c']);
  });

  test('list .length', () {
    final ir = lower('xs.length') as LengthOfNode;
    expect((ir.target as RefNode).path, ['xs']);
  });

  test('index access xs[0]', () {
    final ir = lower('xs[0]') as IndexAccessNode;
    expect((ir.target as RefNode).path, ['xs']);
    expect((ir.key as LiteralNode).value, 0);
  });

  test('null check ==null', () {
    final ir = lower('x == null') as IsNullCheckNode;
    expect((ir.operand as RefNode).path, ['x']);
  });

  test('string interpolation', () {
    final ir = lower(r"'hi $name!'") as StringInterpNode;
    expect(ir.parts.length, 3);
    expect(ir.parts[0], 'hi ');
    expect(ir.parts[1], isA<RefNode>());
    expect((ir.parts[1] as RefNode).path, ['name']);
    expect(ir.parts[2], '!');
  });

  test('conditional ?:', () {
    final ir = lower('a ? b : c') as ConditionalNode;
    expect((ir.condition as RefNode).path, ['a']);
    expect((ir.thenBranch as RefNode).path, ['b']);
    expect((ir.elseBranch as RefNode).path, ['c']);
  });

  test('boolean literal true', () {
    final ir = lower('true');
    expect((ir as LiteralNode).value, true);
  });

  test('null literal', () {
    final ir = lower('null');
    expect((ir as LiteralNode).value, isNull);
  });

  test('list literal', () {
    final ir = lower('[1, 2, 3]') as ListNode;
    expect(ir.children.length, 3);
    expect((ir.children[0] as LiteralNode).value, 1);
  });

  test('integer division ~/', () {
    final ir = lower('10 ~/ 3') as ArithOpNode;
    expect(ir.op, ArithOp.intDiv);
    expect((ir.left as LiteralNode).value, 10);
    expect((ir.right as LiteralNode).value, 3);
  });

  test('parenthesized expression unwraps transparently', () {
    final ir = lower('(a + b) * c') as ArithOpNode;
    expect(ir.op, ArithOp.mul);
    final left = ir.left as ArithOpNode;
    expect(left.op, ArithOp.add);
    expect((left.left as RefNode).path, ['a']);
    expect((left.right as RefNode).path, ['b']);
    expect((ir.right as RefNode).path, ['c']);
  });
}
