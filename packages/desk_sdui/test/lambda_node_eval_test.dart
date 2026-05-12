import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/expression_eval.dart';

void main() {
  group('LambdaNode eval', () {
    late Runtime rt;

    setUp(() {
      rt = Runtime();
      registerCoreAccessors(rt);
    });

    // Test 1: Sync 1-param lambda evaluated produces expected value.
    test('sync 1-param lambda returns expected value', () {
      const node = LambdaNode(
        params: ['x'],
        body: ArithOpNode(
          op: ArithOp.mul,
          left: RefNode(['x']),
          right: LiteralNode(2),
        ),
      );
      final fn = evalExpression(node, {}, rt) as Object? Function(Object?);
      expect(fn(3), 6);
      expect(fn(10), 20);
    });

    // Test 2: Captured env — lambda referencing an outer let-bound name.
    test('lambda captures outer env binding', () {
      const node = LetNode(
        name: 'factor',
        value: LiteralNode(5),
        body: LambdaNode(
          params: ['x'],
          body: ArithOpNode(
            op: ArithOp.mul,
            left: RefNode(['x']),
            right: RefNode(['factor']),
          ),
        ),
      );
      final fn = evalExpression(node, {}, rt) as Object? Function(Object?);
      expect(fn(3), 15);
      expect(fn(2), 10);
    });

    // Test 3: Shadowing — lambda param shadows outer name.
    test('lambda param shadows outer name inside body', () {
      const node = LambdaNode(
        params: ['x'],
        body: ArithOpNode(
          op: ArithOp.add,
          left: RefNode(['x']),
          right: LiteralNode(1),
        ),
      );
      // outer x=100 should be ignored inside the lambda body
      final fn = evalExpression(node, {'x': 100}, rt) as Object? Function(Object?);
      expect(fn(5), 6); // uses lambda's x=5, not outer x=100
    });

    // Test 4: Async 1-param lambda returns a Future.
    test('async 1-param lambda returns Future', () async {
      const node = LambdaNode(
        params: ['x'],
        body: ArithOpNode(
          op: ArithOp.mul,
          left: RefNode(['x']),
          right: LiteralNode(3),
        ),
        isAsync: true,
      );
      final fn = evalExpression(node, {}, rt) as Future<Object?> Function(Object?);
      final result = await fn(4);
      expect(result, 12);
    });

    // Test 5: Iterable.where with LambdaNode.
    test('Iterable.where with lambda filters correctly', () {
      // Simulates items.where((x) => x > 2).toList()
      const lambdaNode = LambdaNode(
        params: ['x'],
        body: CompareOpNode(
          op: CompareOp.gt,
          left: RefNode(['x']),
          right: LiteralNode(2),
        ),
      );
      final fn = evalExpression(lambdaNode, {}, rt) as Object? Function(Object?);
      final items = [1, 2, 3, 4, 5];
      final filtered = items.where((x) => fn(x) as bool).toList();
      expect(filtered, [3, 4, 5]);
    });

    // Test 6: 2-param lambda evaluated.
    test('sync 2-param lambda returns expected value', () {
      const node = LambdaNode(
        params: ['a', 'b'],
        body: ArithOpNode(
          op: ArithOp.add,
          left: RefNode(['a']),
          right: RefNode(['b']),
        ),
      );
      final fn = evalExpression(node, {}, rt) as Object? Function(Object?, Object?);
      expect(fn(3, 4), 7);
    });

    // Test 7: 0-param lambda.
    test('sync 0-param lambda evaluated produces expected value', () {
      const node = LambdaNode(
        params: [],
        body: LiteralNode(42),
      );
      final fn = evalExpression(node, {}, rt) as Object? Function();
      expect(fn(), 42);
    });

    // Test 8: Method call via registered handler with lambda arg.
    test('MethodCallNode.where with lambda arg in expression_eval', () {
      const items = LiteralNode(['apple', 'banana', 'avocado']);
      final lambdaNode = const LambdaNode(
        params: ['x'],
        body: MethodCallNode(
          receiver: RefNode(['x']),
          name: 'String.startsWith',
          args: [LiteralNode('a')],
        ),
      );
      final methodCall = MethodCallNode(
        receiver: items,
        name: 'List.where',
        args: [lambdaNode],
      );
      final result = evalExpression(methodCall, {}, rt) as List;
      expect(result, ['apple', 'avocado']);
    });
  });
}
