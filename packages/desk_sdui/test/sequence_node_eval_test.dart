import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/expression_eval.dart';

void main() {
  group('SequenceNode eval', () {
    late Runtime rt;

    setUp(() {
      rt = Runtime();
    });

    test('steps run in order and return value is returnExpr (not last step)',
        () {
      final log = <int>[];

      // Register two methods that side-effect into [log].
      rt.registerMethod('Test.pushA', (recv, args) {
        (recv as List<int>).add(1);
        return null;
      });
      rt.registerMethod('Test.pushB', (recv, args) {
        (recv as List<int>).add(2);
        return null;
      });

      // SequenceNode: receiver = log list, steps = [pushA(receiver), pushB(receiver)]
      // returnExpr = receiver (the list itself)
      const receiverRef = RefNode(['receiver']);
      const node = LetNode(
        name: 'receiver',
        value: RefNode(['log']),
        body: SequenceNode(
          steps: [
            MethodCallNode(
              receiver: receiverRef,
              name: 'Test.pushA',
              args: [],
            ),
            MethodCallNode(
              receiver: receiverRef,
              name: 'Test.pushB',
              args: [],
            ),
          ],
          returnExpr: receiverRef,
        ),
      );

      final result = evalExpression(node, {'log': log}, rt);

      // Steps ran in order
      expect(log, [1, 2]);

      // Return value is the receiver (the list), not the last step's result (null)
      expect(result, same(log));
    });

    test('steps side effects happen before returnExpr is evaluated', () {
      final log = <String>[];

      rt.registerMethod('Tracker.record', (recv, args) {
        (recv as List<String>).add(args['arg0'] as String);
        return null;
      });

      const receiverRef = RefNode(['tracker']);
      const node = LetNode(
        name: 'tracker',
        value: RefNode(['log']),
        body: SequenceNode(
          steps: [
            MethodCallNode(
              receiver: receiverRef,
              name: 'Tracker.record',
              args: [LiteralNode('step1')],
            ),
            MethodCallNode(
              receiver: receiverRef,
              name: 'Tracker.record',
              args: [LiteralNode('step2')],
            ),
          ],
          returnExpr: receiverRef,
        ),
      );

      final result = evalExpression(node, {'log': log}, rt) as List<String>;
      expect(result, ['step1', 'step2']);
    });

    test('empty steps: returnExpr is evaluated immediately', () {
      const node = SequenceNode(
        steps: [],
        returnExpr: LiteralNode(42),
      );
      expect(evalExpression(node, {}, Runtime()), 42);
    });

    test('codec round-trips SequenceNode', () {
      const codec = JsonIrCodec();
      const original = SequenceNode(
        steps: [
          MethodCallNode(
            receiver: RefNode(['x']),
            name: 'Test.foo',
            args: [],
          ),
        ],
        returnExpr: RefNode(['x']),
      );
      final encoded = codec.encode(original);
      final decoded = codec.decode(encoded);
      expect(decoded, original);
    });
  });
}
