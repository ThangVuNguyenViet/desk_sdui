import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:desk_sdui/src/runtime.dart';

void main() {
  final rt = Runtime();

  // Helper: resolve a PayloadFunctionCallNode with the given function table.
  Object? evalWithFns(
    IrNode node,
    Map<String, PayloadFunctionNode> fns, [
    Map<String, Object?> input = const {},
  ]) {
    final ctx = RuntimeContext(payloadFunctions: fns);
    return evalExpression(node, input, rt, ctx: ctx);
  }

  group('PayloadFunctionCallNode evaluation', () {
    // Test 1: simple two-param function returning sum.
    test('two int params returning sum', () {
      // int add(int a, int b) => a + b;
      const fn = PayloadFunctionNode(
        name: 'add',
        params: ['a', 'b'],
        body: ArithOpNode(
          op: ArithOp.add,
          left: RefNode(['a']),
          right: RefNode(['b']),
        ),
      );
      const call = PayloadFunctionCallNode(
        name: 'add',
        args: [LiteralNode(3), LiteralNode(4)],
      );
      expect(evalWithFns(call, {'add': fn}), 7);
    });

    // Test 2: block body with mutable loop accumulator.
    test('block body with while loop accumulator', () {
      // int sumTo(int n) { var s = 0; var i = 1; while (i <= n) { s = s + i; i = i + 1; } return s; }
      // sumTo(5) == 15
      const fn = PayloadFunctionNode(
        name: 'sumTo',
        params: ['n'],
        body: BlockNode(statements: [
          LetStatementNode(name: 's', value: LiteralNode(0), isFinal: false),
          LetStatementNode(name: 'i', value: LiteralNode(1), isFinal: false),
          WhileNode(
            condition: CompareOpNode(
              op: CompareOp.lte,
              left: RefNode(['i']),
              right: RefNode(['n']),
            ),
            body: BlockNode(statements: [
              AssignNode(
                name: 's',
                value: ArithOpNode(
                  op: ArithOp.add,
                  left: RefNode(['s']),
                  right: RefNode(['i']),
                ),
              ),
              AssignNode(
                name: 'i',
                value: ArithOpNode(
                  op: ArithOp.add,
                  left: RefNode(['i']),
                  right: LiteralNode(1),
                ),
              ),
            ]),
          ),
          ReturnNode(value: RefNode(['s'])),
        ]),
      );
      const call = PayloadFunctionCallNode(
        name: 'sumTo',
        args: [LiteralNode(5)],
      );
      expect(evalWithFns(call, {'sumTo': fn}), 15);
    });

    // Test 3: recursive function (factorial).
    test('recursive factorial', () {
      // int fact(int n) { if (n <= 1) return 1; return n * fact(n - 1); }
      const fn = PayloadFunctionNode(
        name: 'fact',
        params: ['n'],
        body: BlockNode(statements: [
          IfStatementNode(
            cond: CompareOpNode(
              op: CompareOp.lte,
              left: RefNode(['n']),
              right: LiteralNode(1),
            ),
            then: ReturnNode(value: LiteralNode(1)),
          ),
          ReturnNode(
            value: ArithOpNode(
              op: ArithOp.mul,
              left: RefNode(['n']),
              right: PayloadFunctionCallNode(
                name: 'fact',
                args: [
                  ArithOpNode(
                    op: ArithOp.sub,
                    left: RefNode(['n']),
                    right: LiteralNode(1),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
      const call =
          PayloadFunctionCallNode(name: 'fact', args: [LiteralNode(6)]);
      expect(evalWithFns(call, {'fact': fn}), 720);
    });

    // Test 4: payload function calls another payload function.
    test('payload function calling another payload function', () {
      // int double(int x) => x * 2;
      // int quadruple(int x) => double(double(x));
      const doubleFn = PayloadFunctionNode(
        name: 'double',
        params: ['x'],
        body: ArithOpNode(
          op: ArithOp.mul,
          left: RefNode(['x']),
          right: LiteralNode(2),
        ),
      );
      const quadrupleFn = PayloadFunctionNode(
        name: 'quadruple',
        params: ['x'],
        body: PayloadFunctionCallNode(
          name: 'double',
          args: [
            PayloadFunctionCallNode(
              name: 'double',
              args: [RefNode(['x'])],
            ),
          ],
        ),
      );
      const call = PayloadFunctionCallNode(
          name: 'quadruple', args: [LiteralNode(3)]);
      expect(
        evalWithFns(call, {'double': doubleFn, 'quadruple': quadrupleFn}),
        12,
      );
    });

    // Test 5: args evaluate in caller's env; callee env only has params.
    test('args evaluated in caller env; callee has no access to caller locals',
        () {
      // Callee: int add1(int x) => x + 1;
      // Caller env has 'y = 10'. Call add1(y). Should return 11.
      // Callee must NOT see 'y' in its own env.
      const fn = PayloadFunctionNode(
        name: 'add1',
        params: ['x'],
        body: ArithOpNode(
          op: ArithOp.add,
          left: RefNode(['x']),
          right: LiteralNode(1),
        ),
      );
      const call = PayloadFunctionCallNode(
        name: 'add1',
        args: [RefNode(['y'])],
      );
      expect(evalWithFns(call, {'add1': fn}, {'y': 10}), 11);
    });

    // Test 6: resolveScreen unwraps ScreenWithFunctionsNode.
    test('resolveScreen builds function table from ScreenWithFunctionsNode',
        () {
      // ScreenWithFunctionsNode wrapping a PayloadFunctionCallNode body.
      const node = ScreenWithFunctionsNode(
        functions: [
          PayloadFunctionNode(
            name: 'greet',
            params: ['name'],
            body: LiteralNode('hello'),
          ),
        ],
        screenBody: PayloadFunctionCallNode(
          name: 'greet',
          args: [LiteralNode('world')],
        ),
      );
      expect(resolveScreen(node, {}, rt), 'hello');
    });

    // Test 7: missing function in ctx throws a useful error.
    test('unknown function name throws StateError', () {
      const call =
          PayloadFunctionCallNode(name: 'nonexistent', args: []);
      expect(
        () => evalWithFns(call, {}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('nonexistent'),
        )),
      );
    });
  });
}
