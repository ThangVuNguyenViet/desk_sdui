import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/closure_lowerer.dart';
import 'package:desk_sdui_generator/src/diagnostics.dart';
import 'package:test/test.dart';

void main() {
  IrNode lower(String src) {
    final result = parseString(content: 'void _() { $src; }');
    final func = result.unit.declarations.single as FunctionDeclaration;
    final body = func.functionExpression.body as BlockFunctionBody;
    final stmt = body.block.statements.single as ExpressionStatement;
    return lowerClosure(stmt.expression);
  }

  test('tear-off controller.foo → EventNode', () {
    final ir = lower('controller.foo') as EventNode;
    expect(ir.target, ['controller', 'foo']);
  });

  test('() => controller.foo() → EventNode no args', () {
    final ir = lower('() => controller.foo()') as EventNode;
    expect(ir.target, ['controller', 'foo']);
    expect(ir.args, isEmpty);
  });

  test('() => controller.foo(42) → EventNode with literal arg', () {
    final ir = lower('() => controller.foo(42)') as EventNode;
    expect((ir.args['arg0']! as LiteralNode).value, 42);
  });

  test('() => controller.foo(item.id) → EventNode with RefNode arg', () {
    final ir = lower('() => controller.foo(item.id)') as EventNode;
    expect((ir.args['arg0']! as RefNode).path, ['item', 'id']);
  });

  test('(value) => controller.foo(value) → EventNode pass-through', () {
    final ir = lower('(value) => controller.foo(value)') as EventNode;
    expect((ir.args['arg0']! as RefNode).path, ['_callback_arg_0']);
  });

  test('(a) => controller.foo(transform(a)) → LoweringError', () {
    expect(
      () => lower('(a) => controller.foo(transform(a))'),
      throwsA(isA<LoweringError>()),
    );
  });

  test(
      '() { var x = 1; return controller.foo(x); } → BlockNode-bodied LambdaNode (Plan #11)',
      () {
    // Plan #11: sync block-bodied closures lower to a LambdaNode whose body
    // is a BlockNode (executed via executeStatement at run time). Previously
    // they were rejected outright.
    final ir = lower('() { var x = 1; return controller.foo(x); }')
        as LambdaNode;
    expect(ir.isAsync, isFalse);
    expect(ir.body, isA<BlockNode>());
    final block = ir.body as BlockNode;
    expect(block.statements, hasLength(2));
  });

  test('(_) => controller.foo() → EventNode, wildcard ignored', () {
    final ir = lower('(_) => controller.foo()') as EventNode;
    expect(ir.target, ['controller', 'foo']);
    expect(ir.args, isEmpty);
  });

  test('(_, value) => controller.foo(value) → EventNode, wildcard skipped', () {
    final ir = lower('(_, value) => controller.foo(value)') as EventNode;
    expect(ir.target, ['controller', 'foo']);
    expect((ir.args['arg0']! as RefNode).path, ['_callback_arg_1']);
  });

  test('(value, _) => controller.foo(value) → EventNode, trailing wildcard', () {
    final ir = lower('(value, _) => controller.foo(value)') as EventNode;
    expect(ir.target, ['controller', 'foo']);
    expect((ir.args['arg0']! as RefNode).path, ['_callback_arg_0']);
  });
}
