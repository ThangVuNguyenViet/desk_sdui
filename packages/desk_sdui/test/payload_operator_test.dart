import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:desk_sdui/src/payload_class.dart';
import 'package:desk_sdui/src/runtime.dart';

void main() {
  group('PayloadOperatorOverloading', () {
    setUp(() {
      clearPayloadClassesForTest();
    });

    test('+ operator on payload instance', () {
      final vector = PayloadClass(
        name: 'Vector2',
        methods: {
          '+': PayloadFunctionNode(
            name: '+',
            params: ['other'],
            body: ArithOpNode(
              op: ArithOp.add,
              left: ThisFieldRefNode(fieldName: 'x'),
              right: RefNode(['other']),
            ),
          ),
        },
        fieldInitializers: {'x': LiteralNode(10)},
        ctors: {},
      );
      registerPayloadClass(vector);

      final instance = PayloadInstance(
        type: vector,
        fields: {'x': Cell(10)},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: '+',
        args: {'other': LiteralNode(5)},
      );

      expect(evalExpression(node, {}, Runtime()), 15);
    });

    test('== operator on payload instance', () {
      final order = PayloadClass(
        name: 'Order',
        methods: {
          '==': PayloadFunctionNode(
            name: '==',
            params: ['other'],
            body: LiteralNode(true),
          ),
        },
        fieldInitializers: {},
        ctors: {},
      );
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: '==',
        args: {'other': LiteralNode('a')},
      );

      expect(evalExpression(node, {}, Runtime()), true);
    });

    test('[] operator on payload instance', () {
      final mapLike = PayloadClass(
        name: 'MapLike',
        methods: {
          '[]': PayloadFunctionNode(
            name: '[]',
            params: ['key'],
            body: ThisFieldRefNode(fieldName: 'data'),
          ),
        },
        fieldInitializers: {'data': LiteralNode('value')},
        ctors: {},
      );
      registerPayloadClass(mapLike);

      final instance = PayloadInstance(
        type: mapLike,
        fields: {'data': Cell('value')},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: '[]',
        args: {'key': LiteralNode('any')},
      );

      expect(evalExpression(node, {}, Runtime()), 'value');
    });
  });
}
