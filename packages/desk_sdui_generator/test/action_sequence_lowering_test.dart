import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/closure_lowerer.dart';
import 'package:desk_sdui_generator/src/diagnostics.dart';
import 'package:test/test.dart';

void main() {
  /// Lower a closure expression (as a standalone statement) using [lowerClosure].
  IrNode lower(String src) {
    final result = parseString(content: 'void _() { $src; }');
    final func = result.unit.declarations.single as FunctionDeclaration;
    final body = func.functionExpression.body as BlockFunctionBody;
    final stmt = body.block.statements.single as ExpressionStatement;
    return lowerClosure(stmt.expression);
  }

  // ---------------------------------------------------------------------------
  // 1. `() async { await vm.login(); }` → ActionSequenceNode with one step.
  // ---------------------------------------------------------------------------
  test('single await → ActionSequenceNode with one awaited step', () {
    final ir = lower('() async { await vm.login(); }') as ActionSequenceNode;
    expect(ir.steps, hasLength(1));
    final step = ir.steps[0];
    expect(step.awaitResult, isTrue);
    expect(step.bindResult, isNull);
    final call = step.call as MethodCallNode;
    expect(call.name, 'login');
    final receiver = call.receiver as RefNode;
    expect(receiver.path, ['vm']);
  });

  // ---------------------------------------------------------------------------
  // 2. Two steps — first awaited, second fire-and-forget.
  // ---------------------------------------------------------------------------
  test('two steps — first awaited, second not', () {
    final ir = lower(
      '() async { await vm.login(); context.push(); }',
    ) as ActionSequenceNode;
    expect(ir.steps, hasLength(2));

    final s1 = ir.steps[0];
    expect(s1.awaitResult, isTrue);
    expect(s1.bindResult, isNull);

    final s2 = ir.steps[1];
    expect(s2.awaitResult, isFalse);
    expect(s2.bindResult, isNull);
  });

  // ---------------------------------------------------------------------------
  // 3. `() async { final user = await vm.login(); vm.greet(user); }`
  //    → step 1 has bindResult:'user', step 2's arg references RefNode(['user']).
  // ---------------------------------------------------------------------------
  test('bindResult: final user = await vm.login() + vm.greet(user)', () {
    final ir = lower(
      '() async { final user = await vm.login(); vm.greet(user); }',
    ) as ActionSequenceNode;
    expect(ir.steps, hasLength(2));

    final s1 = ir.steps[0];
    expect(s1.awaitResult, isTrue);
    expect(s1.bindResult, 'user');
    final s1Call = s1.call as MethodCallNode;
    expect(s1Call.name, 'login');

    final s2 = ir.steps[1];
    expect(s2.awaitResult, isFalse);
    expect(s2.bindResult, isNull);
    final s2Call = s2.call as MethodCallNode;
    expect(s2Call.name, 'greet');
    final arg = s2Call.args[0] as RefNode;
    expect(arg.path, ['user']);
  });

  // ---------------------------------------------------------------------------
  // 4. Sync block body (`() { vm.bump(); }`) is NOT lowered to ActionSequenceNode
  //    — the existing ExpressionFunctionBody path should throw (sync blocks
  //    are unsupported by the current closure lowerer unless expression-bodied).
  // ---------------------------------------------------------------------------
  test('sync block body → LoweringError (not ActionSequenceNode)', () {
    expect(
      () => lower('() { vm.bump(); }'),
      throwsA(isA<LoweringError>()),
    );
  });

  // ---------------------------------------------------------------------------
  // 5. Unsupported statement (if/for/try) inside async block → LoweringError.
  // ---------------------------------------------------------------------------
  test('if-statement inside async block → LoweringError', () {
    expect(
      () => lower('() async { if (true) { await vm.a(); } }'),
      throwsA(isA<LoweringError>()),
    );
  });

  test('for-loop inside async block → LoweringError', () {
    expect(
      () => lower('() async { for (var i = 0; i < 3; i++) { await vm.a(); } }'),
      throwsA(isA<LoweringError>()),
    );
  });
}
