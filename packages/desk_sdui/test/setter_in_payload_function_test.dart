// Integration test: SetterCallNode inside a PayloadFunctionNode body.
//
// Builds a Runtime with a registered setter for Counter.count, wraps a
// SetterCallNode in a PayloadFunctionNode, invokes it via
// PayloadFunctionCallNode, and asserts the field was mutated.
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:desk_sdui/src/runtime.dart';

class Counter {
  int count = 0;
}

void main() {
  group('SetterCallNode inside PayloadFunctionNode body', () {
    late Runtime rt;
    late Counter counter;

    setUp(() {
      rt = Runtime();
      counter = Counter();

      rt.registerSetter('Counter.count', (target, value) {
        if (target is Counter && value is int) {
          target.count = value;
        }
      });
      rt.registerGetter('Counter.count', (target) {
        if (target is Counter) return target.count;
        return null;
      });
    });

    // Test: PayloadFunctionNode whose body is a SetterCallNode that
    // increments Counter.count by 1.
    //
    //   void increment(Counter c) { c.count = c.count + 1; }
    //   increment(counter);
    //   assert counter.count == 1
    test('SetterCallNode in payload function body mutates the target field', () {
      const fn = PayloadFunctionNode(
        name: 'increment',
        params: ['c'],
        body: SetterCallNode(
          target: RefNode(['c']),
          setterKey: 'Counter.count',
          value: ArithOpNode(
            op: ArithOp.add,
            left: GetterNode(
              receiver: RefNode(['c']),
              name: 'Counter.count',
            ),
            right: LiteralNode(1),
          ),
        ),
      );

      const call = PayloadFunctionCallNode(
        name: 'increment',
        args: [RefNode(['counter'])],
      );

      final ctx = RuntimeContext(payloadFunctions: {'increment': fn});
      evalExpression(call, {'counter': counter}, rt, ctx: ctx);

      // Key assertion: counter.count must have been incremented to 1.
      expect(counter.count, equals(1));
    });

    // Second invocation: counter.count should be 2.
    test('SetterCallNode in payload function body can be invoked multiple times', () {
      const fn = PayloadFunctionNode(
        name: 'increment',
        params: ['c'],
        body: SetterCallNode(
          target: RefNode(['c']),
          setterKey: 'Counter.count',
          value: ArithOpNode(
            op: ArithOp.add,
            left: GetterNode(
              receiver: RefNode(['c']),
              name: 'Counter.count',
            ),
            right: LiteralNode(1),
          ),
        ),
      );

      const call = PayloadFunctionCallNode(
        name: 'increment',
        args: [RefNode(['counter'])],
      );

      final ctx = RuntimeContext(payloadFunctions: {'increment': fn});

      evalExpression(call, {'counter': counter}, rt, ctx: ctx);
      evalExpression(call, {'counter': counter}, rt, ctx: ctx);

      // Key assertion: called twice → count == 2.
      expect(counter.count, equals(2));
    });
  });
}
