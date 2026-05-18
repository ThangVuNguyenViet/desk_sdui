import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui/src/cell.dart';
import 'package:desk_sdui/src/expression_eval.dart';
import 'package:desk_sdui/src/payload_class.dart';
import 'package:desk_sdui/src/runtime.dart';

void main() {
  group('PayloadInstance method dispatch', () {
    setUp(() {
      clearPayloadClassesForTest();
    });

    test('PayloadMethodCallNode dispatches to method on same class', () {
      final order = PayloadClass(
        name: 'Order',
        fieldInitializers: {},
        ctors: {},
        methods: {
          'doubleCents': PayloadFunctionNode(
            name: 'doubleCents',
            params: [],
            body: ArithOpNode(
              op: ArithOp.mul,
              left: ThisFieldRefNode(fieldName: 'cents'),
              right: LiteralNode(2),
            ),
          ),
        },
      );
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {'cents': Cell(100)},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: 'doubleCents',
        args: {},
      );

      expect(evalExpression(node, {}, Runtime()), 200);
    });

    test('PayloadMethodCallNode with args binds params', () {
      final calc = PayloadClass(
        name: 'Calc',
        fieldInitializers: {},
        ctors: {},
        methods: {
          'add': PayloadFunctionNode(
            name: 'add',
            params: ['x', 'y'],
            body: ArithOpNode(
              op: ArithOp.add,
              left: RefNode(['x']),
              right: RefNode(['y']),
            ),
          ),
        },
      );
      registerPayloadClass(calc);

      final instance = PayloadInstance(
        type: calc,
        fields: {},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: 'add',
        args: {
          'x': LiteralNode(3),
          'y': LiteralNode(4),
        },
      );

      expect(evalExpression(node, {}, Runtime()), 7);
    });

    test('ThisFieldRefNode reads field from this', () {
      final order = PayloadClass(
        name: 'Order',
        fieldInitializers: {},
        ctors: {},
        methods: {},
      );
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {'id': Cell('abc')},
      );

      // Simulate being inside a method body by setting up env with 'this'
      final env = <String, Cell>{'this': Cell(instance)};
      final node = ThisFieldRefNode(fieldName: 'id');

      expect(evalExpressionWithEnv(node, env, Runtime()), 'abc');
    });

    test('ThisRefNode returns the instance', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {},
      );

      final env = <String, Cell>{'this': Cell(instance)};
      final node = ThisRefNode();

      expect(evalExpressionWithEnv(node, env, Runtime()), same(instance));
    });

    test('PayloadFieldRefNode reads field on instance', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {'total': Cell(9.99)},
      );

      final node = PayloadFieldRefNode(
        receiver: LiteralNode(instance),
        fieldName: 'total',
      );

      expect(evalExpression(node, {}, Runtime()), 9.99);
    });

    test('PayloadFieldAssignNode writes field on instance', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {'total': Cell(0.0)},
      );

      final node = PayloadFieldAssignNode(
        receiver: LiteralNode(instance),
        fieldName: 'total',
        value: LiteralNode(12.50),
      );

      expect(evalExpression(node, {}, Runtime()), 12.50);
      expect(instance.fields['total']?.value, 12.50);
    });

    test('Method dispatch walks MRO for inherited method', () {
      final parent = PayloadClass(
        name: 'Parent',
        fieldInitializers: {},
        ctors: {},
        methods: {
          'greet': PayloadFunctionNode(
            name: 'greet',
            params: [],
            body: LiteralNode('hello'),
          ),
        },
      );
      registerPayloadClass(parent);

      final child = PayloadClass(
        name: 'Child',
        supertype: parent,
        fieldInitializers: {},
        ctors: {},
        methods: {},
      );
      registerPayloadClass(child);

      final instance = PayloadInstance(
        type: child,
        fields: {},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: 'greet',
        args: {},
      );

      expect(evalExpression(node, {}, Runtime()), 'hello');
    });

    test('Unknown method throws NoSuchMethodError', () {
      final order = PayloadClass(name: 'Order');
      registerPayloadClass(order);

      final instance = PayloadInstance(
        type: order,
        fields: {},
      );

      final node = PayloadMethodCallNode(
        receiver: LiteralNode(instance),
        methodName: 'unknown',
        args: {},
      );

      expect(
        () => evalExpression(node, {}, Runtime()),
        throwsA(isA<NoSuchMethodError>()),
      );
    });
  });
}
